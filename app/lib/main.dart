import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';
import 'widgets/app_vault_drawer.dart';
import 'widgets/vibe_detector.dart';
import 'widgets/preview_sheet.dart';
import 'widgets/rolling_greeting.dart';
import 'widgets/markdown_utils.dart';
import 'repositories/micro_app_repository.dart';
import 'repositories/conversation_repository.dart';
import 'repositories/micro_app_data_repository.dart';
import 'repositories/local_database.dart';
import 'providers/fallback_llm_provider.dart';
import 'providers/hybrid_inference_manager.dart';
import 'providers/token_tracking_firebase_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/forge_mode.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/login_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Background task starting: $task");
    
    final prefs = await SharedPreferences.getInstance();
    final allowBackground = prefs.getBool('allow_background_execution') ?? false;
    if (!allowBackground) {
      debugPrint("Background execution disabled in settings.");
      return Future.value(true);
    }

    final allowNotifications = prefs.getBool('allow_background_notifications') ?? false;
    final allowDatabase = prefs.getBool('allow_background_database') ?? false;

    final dbHelper = LocalDatabase();
    final db = await dbHelper.database;
    
    // Get all apps with periodic backend
    final List<Map<String, dynamic>> apps = await db.query(
      'micro_apps',
      where: 'periodic_backend_blob IS NOT NULL AND periodic_backend_blob != ""',
    );

    if (apps.isEmpty) {
      debugPrint("No background tasks found.");
      return Future.value(true);
    }

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    final dataRepository = MicroAppDataRepository(dbHelper: dbHelper);

    for (final app in apps) {
      final appId = app['appId'];
      final code = app['periodic_backend_blob'];
      final appName = app['name'] ?? 'Unknown App';

      debugPrint("Executing background task for app: $appName ($appId)");

      final jsRuntime = getJavascriptRuntime();
      
      jsRuntime.onMessage('MicroForgeBridge', (dynamic args) async {
        final data = jsonDecode(args.toString()) as Map<String, dynamic>;
        final action = data['action'];

        if (action == 'log') {
          debugPrint('[Background $appName] ${data['message']}');
          return jsonEncode({'success': true});
        } else if (action == 'saveData') {
          if (!allowDatabase) return jsonEncode({'error': 'Database access disabled'});
          await dataRepository.saveData(appId, data['key'], data['value']);
          return jsonEncode({'success': true});
        } else if (action == 'getData') {
          if (!allowDatabase) return jsonEncode({'error': 'Database access disabled'});
          final val = await dataRepository.getData(appId, data['key']);
          return jsonEncode({'value': val});
        } else if (action == 'deleteData') {
          if (!allowDatabase) return jsonEncode({'error': 'Database access disabled'});
          await dataRepository.deleteData(appId, data['key']);
          return jsonEncode({'success': true});
        } else if (action == 'listAll') {
          if (!allowDatabase) return jsonEncode({'error': 'Database access disabled'});
          final allData = await dataRepository.listAll(appId);
          return jsonEncode({'data': allData});
        } else if (action == 'showNotification') {
          if (!allowNotifications) return jsonEncode({'error': 'Notification access disabled'});
          
          const androidDetails = AndroidNotificationDetails(
            'background_channel',
            'Background Tasks',
            importance: Importance.max,
            priority: Priority.high,
          );
          const notificationDetails = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
          
          await notificationsPlugin.show(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: data['title'] ?? appName,
            body: data['body'] ?? '',
            notificationDetails: notificationDetails,
            payload: data['payload'],
          );
          return jsonEncode({'success': true});
        }
        return jsonEncode({'error': 'Unknown action'});
      });

      final wrapper = '''
        var window = this;
        var MicroForge = {
          saveData: (key, value) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'saveData', key, value})).then(r => JSON.parse(r)),
          getData: (key) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'getData', key})).then(r => JSON.parse(r).value),
          deleteData: (key) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'deleteData', key})).then(r => JSON.parse(r)),
          listAll: () => sendMessage('MicroForgeBridge', JSON.stringify({action: 'listAll'})).then(r => JSON.parse(r).data),
          showNotification: (title, body, payload) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'showNotification', title, body, payload})).then(r => JSON.parse(r))
        };
        var console = {
          log: (...args) => sendMessage('MicroForgeBridge', JSON.stringify({
            action: 'log', 
            message: args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ')
          }))
        };
        
        async function runWrapper() {
          try {
            $code
          } catch (e) {
            console.log("Error in background task: " + e.message);
          }
        }
        runWrapper();
      ''';

      try {
        await jsRuntime.evaluateAsync(wrapper);
      } catch (e) {
        debugPrint("JS Evaluation Error in background: $e");
      } finally {
        jsRuntime.dispose();
      }
    }

    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInitializationSettings = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: iosInitializationSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  await Workmanager().initialize(
    callbackDispatcher,
  );
  
  // Schedule a periodic task to run every 30 minutes
  await Workmanager().registerPeriodicTask(
    "microforge-periodic-background",
    "periodicTask",
    frequency: const Duration(minutes: 30),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  // Keep Firebase for AI if needed, but we could also move it later
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final dbHelper = LocalDatabase();
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => MicroAppRepository(dbHelper: dbHelper)),
        Provider(create: (_) => MicroAppDataRepository(dbHelper: dbHelper)),
        ChangeNotifierProvider(create: (_) => ConversationRepository(dbHelper: dbHelper)),
        ChangeNotifierProvider(create: (_) => AuthProvider()), // Kept for potential UI needs, but not for auth
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BetterFeedback(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'MicroForge',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.light),
            scaffoldBackgroundColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
            scaffoldBackgroundColor: Colors.black,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            useMaterial3: true,
          ),
          themeMode: settings.themeMode,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isAuthenticated) {
          return const MicroForgeHomePage();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MicroForgeHomePage extends StatefulWidget {
  static LlmProvider? mockProvider;
  
  const MicroForgeHomePage({super.key});

  @override
  State<MicroForgeHomePage> createState() => MicroForgeHomePageState();
}

class MicroForgeHomePageState extends State<MicroForgeHomePage> {
  LlmProvider? _provider;
  String? _activeForgeCode;
  String? _activeBackendCode;
  String? _activePeriodicBackendCode;
  String? _activeDesignDoc;
  String? _activeReleaseNotes;
  String? _activeAppId;
  bool _showPreview = false;
  String _currentConversationId = const Uuid().v4();
  String _conversationTitle = 'New Conversation';
  String? _enhancementCode;
  String? _enhancementBackend;
  String? _enhancementPeriodicBackend;
  String? _enhancementDesign;
  String? _enhancementAppId;
  bool _enhancementContextInPrompt = false;
  ForgeMode _currentMode = ForgeMode.build;
  final GlobalKey<PreviewSheetState> _previewSheetKey = GlobalKey();
  late MicroAppRepository _repository;

  // Add getters for testing
  String? get activeBackendCode => _activeBackendCode;
  String? get activePeriodicBackendCode => _activePeriodicBackendCode;
  String? get enhancementBackend => _enhancementBackend;
  String? get activeForgeCode => _activeForgeCode;
  String? get activeAppId => _activeAppId;
  bool get showPreview => _showPreview;

  @override
  void initState() {
    super.initState();
    _repository = context.read<MicroAppRepository>();
    _repository.addListener(_onAppsChanged);
    _initializeAI();
  }

  @override
  void dispose() {
    _repository.removeListener(_onAppsChanged);
    super.dispose();
  }

  void _onAppsChanged() {
    if (!mounted) return;
    
    // Check if we are busy to avoid interrupting a generation
    if (_provider is FallbackLlmProvider && (_provider as FallbackLlmProvider).isBusy) {
      debugPrint('Apps changed but AI is busy. Delaying re-initialization...');
      return;
    }

    final settings = context.read<SettingsProvider>();
    if (settings.suggestExistingApps) {
      debugPrint('Apps changed, re-initializing AI to update system prompt...');
      _initializeAI(
        enhancementCode: _enhancementContextInPrompt ? _enhancementCode : null,
        enhancementBackend: _enhancementContextInPrompt ? _enhancementBackend : null,
        enhancementPeriodicBackend: _enhancementContextInPrompt ? _enhancementPeriodicBackend : null,
        enhancementDesign: _enhancementContextInPrompt ? _enhancementDesign : null,
        enhancementAppId: _enhancementContextInPrompt ? _enhancementAppId : null,
        history: _provider?.history.toList(),
        mode: _currentMode,
      );
    }
  }

  void _initializeAI({
    String? enhancementCode,
    String? enhancementBackend,
    String? enhancementPeriodicBackend,
    String? enhancementDesign,
    String? enhancementAppId,
    List<ChatMessage>? history,
    ForgeMode? mode,
  }) async {
    final settings = context.read<SettingsProvider>();
    final repository = context.read<MicroAppRepository>();

    if (mode != null) {
      _currentMode = mode;
    } else if (history == null || history.isEmpty) {
      _currentMode = settings.defaultForgeMode;
    }

    String systemPrompt = 'You are MicroForge AI. You help users "forge" micro-apps. ';

    if (_currentMode == ForgeMode.plan) {
      systemPrompt += '\n\n[MODE: PLAN] Iteratively work with the user to refine the design. '
          'Ask for permission to build when the design is mature enough. '
          'Do NOT provide any micro-app code or <forge> tags yet in this mode unless explicitly asked to build. '
          'Focus on discussing requirements, architecture, and user experience first. '
          'In this mode, you should help the user think through their app before implementation.';
    } else {
      systemPrompt += '\n\n[MODE: BUILD] Immediately start building the micro-app with <forge> tags. '
          'Whenever you provide code for a micro-app (HTML/Alpine.js/Tailwind), '
          'you MUST wrap it inside <forge>...</forge> tags. '
          'Example: <forge><div class="p-4">Hello</div></forge>. ';
    }

    systemPrompt += '\n\nAdditionally, for every micro-app you forge, you MUST also provide: '
        '1. A concise name wrapped in <name>...</name> tags. '
        '2. A suitable emoji to represent the app wrapped in <icon>...</icon> tags. '
        '3. A brief design document in Markdown wrapped in <design>...</design> tags. '
        '4. A version number (e.g., 1.0.0, 1.1.0) wrapped in <version>...</version> tags. '
        '   When enhancing an app, increment the version based on the complexity of changes. '
        '5. A concise release note summarizing the improvements wrapped in <release_notes>...</release_notes> tags. '
        '\nExample: '
        '<name>Task Master</name> '
        '<icon>✅</icon> '
        '<design># Task Master\nA simple todo app with local persistence.</design> '
        '<version>1.0.0</version> '
        '<release_notes>Initial release with task creation and local storage.</release_notes> '
        '<forge><div class="p-4">...</div></forge> '
        '\n\nDo not use other markdown blocks for the micro-app code itself. '
        'Use Tailwind CSS for styling and Alpine.js for reactivity. '
        'The UI MUST be reactive and responsive, fitting different screen sizes and aspect ratios seamlessly. '
        'Use Tailwind\'s responsive utility classes (e.g., `sm:`, `md:`, `lg:`) and flexible layouts (Flexbox, Grid) '
        'to ensure the app looks great on both portrait mobile screens and landscape tablets or desktops. '
        'The micro-apps should be self-contained and visually appealing. '
        'IMPORTANT: All micro-apps MUST support light and dark themes and stay consistent with the host app. '
        'Use `window.MicroForge.getTheme()` to read the current theme and `window.MicroForge.onThemeChange(callback)` to react to changes. '
        'The host injects CSS variables you should use for colors: '
        '`--mf-bg`, `--mf-surface`, `--mf-text`, `--mf-muted`, `--mf-primary`, `--mf-on-primary`, `--mf-secondary`, `--mf-on-secondary`, `--mf-outline`. '
        'Prefer Tailwind dark classes and/or these CSS variables (e.g., `class="bg-[var(--mf-bg)] text-[var(--mf-text)]"`). '
        '\n\nNEW CAPABILITY: Vanilla JavaScript Backend. '
        'You can now write a separate backend using vanilla JavaScript, which will be executed in a dedicated engine (flutter_js). '
        'If the app requires heavy processing, data manipulation, or complex logic, you SHOULD delegate it to the backend. '
        'The backend code MUST be wrapped in <backend>...</backend> tags. '
        'The backend should define a single entry point function named `handleRequest(jsonInput)`. '
        'The `jsonInput` will always contain an `api` string and a `payload` object. '
        'The function MUST return a JSON object with `status` (e.g., "success", "error") and `payload`. '
        'Example backend: '
        '<backend>'
        'function handleRequest(input) { '
        '  const { api, payload } = input; '
        '  switch(api) { '
        '    case "calculate": return { status: "success", payload: { result: payload.a + payload.b } }; '
        '    default: return { status: "error", payload: "Unknown API" }; '
        '  } '
        '}'
        '</backend>'
        '\n\nFrontend (Alpine.js) can call the backend using `window.MicroForge.callBackend(api, payload)`. '
        'Example: `const response = await window.MicroForge.callBackend("calculate", { a: 1, b: 2 });` '
        '\n\nBACKEND CAPABILITIES (available via `MicroForge` or `window.MicroForge`): '
        '- `saveData(key, value)`: Returns a Promise. '
        '- `getData(key)`: Returns a Promise that resolves to the value. '
        '- `deleteData(key)`: Returns a Promise. '
        '- `listAll()`: Returns a Promise that resolves to an object of all keys/values. '
        '- `showNotification(title, body, payload)`: Shows a local notification. '
        '- `console.log(...)`: Outputs to the App Console for debugging. '
        '\nNote: Backend database and notification access are controlled by user toggles. '
        '\n\nNEW CAPABILITY: URL Context. '
        'You can now access and analyze content from URLs provided in the prompt. '
        'If the user provides a link to a website, documentation, or an image, you can use that information to better fulfill their request. '
        '\n\nNEW CAPABILITY: MicroForge Bridge API. '
        'You can use the `window.MicroForge` bridge to persist data locally and call AI. '
        'Methods: '
        '- `window.MicroForge.getTheme()`: Returns `{ mode: "light"|"dark", source: "system"|"light"|"dark", colors: { ... } }`. '
        '- `window.MicroForge.onThemeChange(callback)`: Calls `callback(theme)` whenever the theme changes. Returns an unsubscribe function. '
        '- `window.MicroForge.saveData(key, value)`: Returns a Promise. '
        '- `window.MicroForge.getData(key)`: Returns a Promise that resolves to the value. '
        '- `window.MicroForge.deleteData(key)`: Returns a Promise. '
        '- `window.MicroForge.listAll()`: Returns a Promise that resolves to an object of all keys/values. '
        '- `window.MicroForge.promptAi(prompt, systemInstruction)`: Returns a Promise that resolves to the AI response text. '
        'Use `promptAi` to build AI-powered features within your micro-apps. '
        '- `window.MicroForge.pickFiles(options)`: Returns a Promise that resolves to a list of file objects. '
        'Options: `{ multiple: true/false, type: "any"/"image"/"video"/"audio"/"media"/"custom", extensions: ["pdf", "doc"] }`. '
        'File object: `{ name, size, extension, bytes (base64) }`. '
        '- `window.MicroForge.callBackend(api, payload)`: Calls the backend JS engine. Returns a Promise that resolves to the backend response object `{ status, payload }`. '
        '\n\nNEW CAPABILITY: Background Periodic Functions. '
        'You can now write a separate, pure JavaScript function that runs in the background periodically (every 15-30 mins). '
        'This is ideal for tasks like checking external APIs, updating local data, or sending notifications when the app is NOT active. '
        'The background code MUST be wrapped in <periodic_backend>...</periodic_backend> tags. '
        'Rules for Periodic Backend: '
        '1. It must NOT have input arguments or a return value. '
        '2. It must be self-contained (no reliance on external UI variables). '
        '3. It has access to the same MicroForge Bridge API as the standard backend (saveData, getData, showNotification, etc.). '
        '4. It will be executed by the system even if the app is closed. '
        '5. Access to Notifications and Database is controlled by "Background" toggles in the settings. '
        'Example: '
        '<periodic_backend>'
        'async function runTask() { '
        '  const lastCheck = await MicroForge.getData("last_check"); '
        '  const now = Date.now(); '
        '  if (!lastCheck || now - lastCheck > 3600000) { '
        '    await MicroForge.showNotification("Time to check in!", "You haven\'t used the app in a while."); '
        '    await MicroForge.saveData("last_check", now); '
        '  } '
        '} '
        'runTask();'
        '</periodic_backend>';

    if (settings.allowGeolocation) {
      systemPrompt += '- `window.MicroForge.getLocation()`: Returns a Promise that resolves to a location object. '
          'Location object: `{ latitude, longitude, altitude, accuracy, speed, heading, timestamp }`. ';
    }

    if (settings.allowAccelerometer) {
      systemPrompt += '- `window.MicroForge.getAccelerometer()`: Returns a Promise that resolves to an object `{ x, y, z }`. '
          '- `window.MicroForge.watchAccelerometer(callback)`: Subscribes to accelerometer updates. The callback receives `{ x, y, z }`. '
          '- `window.MicroForge.stopAccelerometer()`: Stops the accelerometer subscription. ';
    }

    if (settings.allowNotifications) {
      systemPrompt += '- `window.MicroForge.showNotification(title, body, payload)`: Shows a local notification. Returns a Promise. '
          'Payload is an optional string. ';
    }

    systemPrompt += '- `window.MicroForge.closeApp()`: Closes the micro-app preview. '
        '\n\nAUTO REFINE CAPABILITY: '
        'When you receive a message starting with "AUTO REFINE:", it means the user wants you to analyze the current app for flaws and potential improvements based on logs and a screenshot. '
        'You MUST analyze the console logs for errors or warnings, and the screenshot for layout/styling issues. '
        'Then, provide the improved code (and design document) following the same <forge>, <backend>, <name>, <design>, <version>, and <release_notes> tagging rules. '
        '\nExample of Alpine.js AI integration: '
        'x-data="{ input: \'\', response: \'\', loading: false }" '
        '@submit.prevent="loading = true; response = await window.MicroForge.promptAi(input, \'You are a helpful assistant.\'); loading = false"'
        '\nExample of Alpine.js File Picking: '
        'x-data="{ files: [] }" '
        '@click="files = await window.MicroForge.pickFiles({ multiple: true, type: \'image\' })"';

    if (settings.allowGeolocation) {
      systemPrompt += '\nExample of Alpine.js Geolocation: '
          'x-data="{ loc: null, loading: false }" '
          '@click="loading = true; loc = await window.MicroForge.getLocation(); loading = false"';
    }

    if (settings.allowAccelerometer) {
      systemPrompt += '\nExample of Alpine.js Accelerometer: '
          'x-data="{ x: 0, y: 0, z: 0 }" '
          'x-init="window.MicroForge.watchAccelerometer(data => { x = data.x; y = data.y; z = data.z })"';
    }

    if (settings.allowNotifications) {
      systemPrompt += '\nExample of Alpine.js Notifications: '
          'x-data="{ title: \'\', body: \'\' }" '
          '@submit.prevent="await window.MicroForge.showNotification(title, body, \'my-payload\')"';
    }

    final includesEnhancementContext = enhancementCode != null;

    if (includesEnhancementContext) {
      systemPrompt += '\n\nCONTEXT FOR ENHANCEMENT:\n'
          'You are currently enhancing an existing micro-app.\n'
          'Current Implementation:\n<forge>$enhancementCode</forge>\n'
          'Current Backend:\n<backend>${enhancementBackend ?? 'No backend provided.'}</backend>\n'
          'Current Background Periodic:\n<periodic_backend>${enhancementPeriodicBackend ?? 'No background periodic code provided.'}</periodic_backend>\n'
          'Design Document:\n<design>${enhancementDesign ?? 'No design document provided.'}</design>';
    }

    // Check on-device model status
    try {
      final status = await HybridInferenceManager.checkModelStatus();
      final statusString = status.toString();
      debugPrint('On-device AI status: $statusString');
      // If downloadable, we start it, but in a real app, you might want to show a progress bar
      if (statusString == 'DOWNLOADABLE') {
        debugPrint('Starting on-device model download...');
        HybridInferenceManager.downloadModel();
      }
    } catch (e) {
      debugPrint('Failed to check hybrid status: $e');
    }

    if (settings.suggestExistingApps) {
      final auth = context.read<AuthProvider>();
      final apps = await repository.getAppsForOwner(auth.user?.uid ?? 'local-user');
      if (apps.isNotEmpty) {
        systemPrompt += '\n\nPREVIOUSLY DEPLOYED MICRO-APPS:\n';
        for (final app in apps) {
          final id = app['appId'];
          final name = app['name'] ?? 'Unnamed App';
          final design = app['design_doc'] ?? 'No description available.';
          systemPrompt += '- **$name** (ID: $id): $design\n';
        }
        systemPrompt += '\nWhen the user asks to build something, you SHOULD FIRST check if any of the existing apps above can fulfill their request. '
            'If so, suggest the existing app(s) and explain how they might help. '
            'When suggesting an existing app, you MUST wrap its ID and name in <suggest_app id="APP_ID">APP_NAME</suggest_app> tags. '
            'Example: "You already have a Task Master app that might work for this: <suggest_app id="123">Task Master</suggest_app>" '
            '\nONLY proceed to forging a NEW micro-app if the user explicitly requests a new one or if none of the existing apps are suitable.';
      }
    }

    if (MicroForgeHomePage.mockProvider != null) {
      if (history != null) {
        MicroForgeHomePage.mockProvider!.history = history;
      }
      setState(() {
        _provider = MicroForgeHomePage.mockProvider;
        _enhancementCode = enhancementCode;
        _enhancementBackend = enhancementBackend;
        _enhancementDesign = enhancementDesign;
        _enhancementAppId = enhancementAppId;
        _enhancementContextInPrompt = includesEnhancementContext;
      });
      return;
    }

    final primaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      systemInstruction: Content.system(systemPrompt),
      tools: [
        Tool.urlContext(),
      ],
    );

    final secondaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.0-flash',
      systemInstruction: Content.system(systemPrompt),
      tools: [
        Tool.urlContext(),
      ],
    );

    final provider = FallbackLlmProvider(
      primary: TokenTrackingFirebaseProvider(
        model: primaryModel,
        onUsageMetadata: (meta) {
          settings.addTokenUsage(
            meta.promptTokenCount ?? 0,
            meta.candidatesTokenCount ?? 0,
            meta.totalTokenCount ?? 0,
            thoughts: meta.thoughtsTokenCount ?? 0,
            cached: meta.cachedContentTokenCount ?? 0,
            toolUse: meta.toolUsePromptTokenCount ?? 0,
          );
        },
      ),
      secondary: TokenTrackingFirebaseProvider(
        model: secondaryModel,
        onUsageMetadata: (meta) {
          settings.addTokenUsage(
            meta.promptTokenCount ?? 0,
            meta.candidatesTokenCount ?? 0,
            meta.totalTokenCount ?? 0,
            thoughts: meta.thoughtsTokenCount ?? 0,
            cached: meta.cachedContentTokenCount ?? 0,
            toolUse: meta.toolUsePromptTokenCount ?? 0,
          );
        },
      ),
    );

    provider.addListener(_onHistoryChanged);

    if (history != null) {
      provider.history = history;
    }

    settings.setSystemPrompt(systemPrompt);

    setState(() {
      _provider = provider;
      _enhancementCode = enhancementCode;
      _enhancementBackend = enhancementBackend;
      _enhancementDesign = enhancementDesign;
      _enhancementAppId = enhancementAppId;
      _enhancementContextInPrompt = includesEnhancementContext;
    });
  }

  void _onHistoryChanged() {
    if (_provider == null) return;
    final history = _provider!.history;
    if (history.isEmpty) return;

    // Update title from first user message if still "New Conversation"
    if (_conversationTitle == 'New Conversation' && history.isNotEmpty) {
      final firstUserMessage = history.firstWhere(
        (m) => m.origin == MessageOrigin.user,
        orElse: () => history.first,
      );
      final text = firstUserMessage.text ?? 'Untitled';
      _conversationTitle = text.length > 30
          ? '${text.substring(0, 27)}...'
          : text;
    }

    final repository = context.read<ConversationRepository>();
    repository.saveConversation(
      _currentConversationId,
      _conversationTitle,
      history.toList(),
      enhancementCode: _enhancementCode,
      enhancementBackend: _enhancementBackend,
      enhancementPeriodicBackend: _enhancementPeriodicBackend,
      enhancementDesign: _enhancementDesign,
      enhancementAppId: _enhancementAppId,
      forgeMode: _currentMode,
    );
  }

  void _createNewForge() {
    setState(() {
      _activeForgeCode = null;
      _activeBackendCode = null;
      _activePeriodicBackendCode = null;
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'New Conversation';
      _enhancementCode = null;
      _enhancementBackend = null;
      _enhancementPeriodicBackend = null;
      _enhancementDesign = null;
      _enhancementAppId = null;
      _enhancementContextInPrompt = false;
      _currentMode = context.read<SettingsProvider>().defaultForgeMode;
      if (_provider != null) {
        _provider!.history = [];
      }
    });
    _initializeAI(mode: _currentMode);
  }

  void onEnhance() {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final codeToEnhance = _activeForgeCode!;
    final backendToEnhance = _activeBackendCode;
    final periodicBackendToEnhance = _activePeriodicBackendCode;
    final designToEnhance = _activeDesignDoc;
    final appIdToEnhance = _activeAppId;
    final newConversationId = const Uuid().v4();

    setState(() {
      _showPreview = false;
      _currentConversationId = newConversationId;
      _conversationTitle = 'Enhance $name';
      _enhancementCode = codeToEnhance;
      _enhancementBackend = backendToEnhance;
      _enhancementPeriodicBackend = periodicBackendToEnhance;
      _enhancementDesign = designToEnhance;
      _enhancementAppId = appIdToEnhance;
      if (_provider != null) {
        _provider!.history = [];
      }
    });

    _initializeAI(
      enhancementCode: codeToEnhance, 
      enhancementBackend: backendToEnhance,
      enhancementPeriodicBackend: periodicBackendToEnhance,
      enhancementDesign: designToEnhance,
      enhancementAppId: appIdToEnhance,
    );

    // Give it a moment for AI to be ready with new provider
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_provider != null) {
        setState(() {
          _provider!.history = [
            ChatMessage(
              origin: MessageOrigin.llm,
              text: "I've loaded your app '$name'. How would you like to enhance it?",
              attachments: const [],
            ),
            ChatMessage(
              origin: MessageOrigin.llm,
              text: '<enhancement_context/>',
              attachments: const [],
            ),
          ];
        });
      }
    });

  }

  void _onFeedback(String text, Uint8List screenshot) {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final codeToEnhance = _activeForgeCode!;
    final backendToEnhance = _activeBackendCode;
    final periodicBackendToEnhance = _activePeriodicBackendCode;
    final designToEnhance = _activeDesignDoc;
    final existingHistory = _provider?.history.toList() ?? [];

    setState(() {
      _showPreview = false;
      // Keep current conversation ID
      _conversationTitle = 'Feedback on $name';
      _enhancementCode = codeToEnhance;
      _enhancementBackend = backendToEnhance;
      _enhancementPeriodicBackend = periodicBackendToEnhance;
      _enhancementDesign = designToEnhance;
    });

    _initializeAI(
      enhancementCode: codeToEnhance, 
      enhancementBackend: backendToEnhance,
      enhancementPeriodicBackend: periodicBackendToEnhance,
      enhancementDesign: designToEnhance,
      history: existingHistory,
    );

    // Give it a moment for AI to be ready with new provider
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_provider != null) {
        setState(() {
          _provider!.history = [
            ...existingHistory,
            ChatMessage(
              origin: MessageOrigin.user,
              text: "I have some feedback for this app:\n\n$text",
              attachments: [
                ImageFileAttachment(
                  name: 'feedback_screenshot.png',
                  mimeType: 'image/png',
                  bytes: screenshot,
                ),
              ],
            ),
          ];
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analyzing feedback for $name in current conversation...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: double.infinity, left: 16, right: 16, top: 16),
      ),
    );
  }

  void _onAutoRefine(List<String> logs, Uint8List screenshot) {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final codeToEnhance = _activeForgeCode!;
    final backendToEnhance = _activeBackendCode;
    final periodicBackendToEnhance = _activePeriodicBackendCode;
    final designToEnhance = _activeDesignDoc;
    final existingHistory = _provider?.history.toList() ?? [];

    setState(() {
      _showPreview = false;
      // Keep current conversation ID to stay in the same conversation
      _conversationTitle = 'Refining $name';
    });

    // Prepare logs text
    final logsText = logs.isNotEmpty ? logs.join('\n') : 'No logs captured.';

    // Give it a moment for AI to be ready with new provider
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_provider != null) {
        final autoRefineMessage = ChatMessage(
          origin: MessageOrigin.user,
          text: "AUTO REFINE: Please analyze this app for flaws and potential improvements based on the following context:\n\n"
              "1. App Console Logs:\n$logsText\n\n"
              "2. App Screenshot (attached below).\n\n"
              "Please look for visual inconsistencies, bugs indicated by logs, or UX improvements and implement the necessary changes in the code and design doc.",
          attachments: [
            ImageFileAttachment(
              name: 'app_screenshot.png',
              mimeType: 'image/png',
              bytes: screenshot,
            ),
          ],
        );

        setState(() {
          _provider!.history = [...existingHistory, autoRefineMessage];
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analyzing app for refinements in current conversation...'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: double.infinity, left: 16, right: 16, top: 16),
      ),
    );
  }

  String _bumpVersion(String? currentVersion) {
    if (currentVersion == null || currentVersion.isEmpty) return '1.0.0';
    final parts = currentVersion.split('.');
    if (parts.length != 3) return '1.0.0';
    try {
      final major = int.parse(parts[0]);
      final minor = int.parse(parts[1]);
      final patch = int.parse(parts[2]);
      return '$major.${minor + 1}.$patch';
    } catch (e) {
      return '1.0.0';
    }
  }

  void onDeploy(String code, String? backendCode, String? periodicBackendCode, String? name, String? designDoc, String? version, String? releaseNotes, String? icon, {bool isTemporary = false}) async {
    // Fallback to enhancement values if current ones are null
    final finalBackend = backendCode ?? _enhancementBackend;
    final finalPeriodicBackend = periodicBackendCode ?? _enhancementPeriodicBackend;
    final finalDesign = designDoc ?? _enhancementDesign;
    final finalName = name ?? (_conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App');

    setState(() {
      _activeForgeCode = code;
      _activeBackendCode = finalBackend;
      _activePeriodicBackendCode = finalPeriodicBackend;
      _activeDesignDoc = finalDesign;
      _activeReleaseNotes = releaseNotes;
      _showPreview = true;
      
      // Update enhancement context so subsequent deploys in the same conversation 
      // can also benefit from these fallbacks
      _enhancementCode = code;
      _enhancementBackend = finalBackend;
      _enhancementPeriodicBackend = finalPeriodicBackend;
      _enhancementDesign = finalDesign;
    });

    if (isTemporary) {
      setState(() {
        _activeAppId = 'temp-preview';
      });
      return;
    }

    // Automatically save app locally
    try {
      final repository = context.read<MicroAppRepository>();
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.uid ?? 'local-user';

      String finalAppId = const Uuid().v4();
      String resolvedName = finalName;
      String finalVersion = version ?? '1.0.0';
      String finalIcon = icon ?? 'rocket';

      if (_enhancementAppId != null) {
        final existingApp = await repository.getApp(_enhancementAppId!);
        if (existingApp != null) {
          finalAppId = _enhancementAppId!;
          resolvedName = name ?? existingApp['name'] ?? resolvedName;
          finalIcon = icon ?? existingApp['icon'] ?? finalIcon;
          if (version == null) {
            finalVersion = _bumpVersion(existingApp['version']);
          }
        }
      }

      final appId = await repository.saveApp({
        'appId': finalAppId,
        'ownerId': userId,
        'conversationId': _currentConversationId,
        'name': resolvedName,
        'html_blob': code,
        'backend_blob': finalBackend,
        'periodic_backend_blob': finalPeriodicBackend,
        'design_doc': finalDesign,
        'release_notes': releaseNotes,
        'version': finalVersion,
        'icon': finalIcon,
      });

      setState(() {
        _activeAppId = appId;
      });

    } catch (e) {
      debugPrint('Failed to save app: $e');
    }
  }

  void _onOpenApp(String appId) async {
    final repository = context.read<MicroAppRepository>();
    final app = await repository.getApp(appId);
    if (app != null) {
      loadApp(app);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App not found!')),
        );
      }
    }
  }

  void loadApp(Map<String, dynamic> app, {bool switchConversation = false}) async {
    final conversationId = app['conversationId'];
    final appId = app['appId'];
    if (conversationId != null && switchConversation) {
      final repository = context.read<ConversationRepository>();
      final data = await repository.getConversation(conversationId);

      setState(() {
        _activeForgeCode = app['html_blob'];
        _activeBackendCode = app['backend_blob'];
        _activePeriodicBackendCode = app['periodic_backend_blob'];
        _activeDesignDoc = app['design_doc'];
        _activeReleaseNotes = app['release_notes'];
        _activeAppId = appId;
        _showPreview = true;
        _currentConversationId = conversationId;
        _conversationTitle = app['name'] ?? 'Forged App';
        _enhancementCode = data.enhancementCode;
        _enhancementBackend = data.enhancementBackend;
        _enhancementPeriodicBackend = data.enhancementPeriodicBackend;
        _enhancementDesign = data.enhancementDesign;
        _enhancementAppId = data.enhancementAppId;
      });

      _initializeAI(
        enhancementCode: data.enhancementCode,
        enhancementBackend: data.enhancementBackend,
        enhancementPeriodicBackend: data.enhancementPeriodicBackend,
        enhancementDesign: data.enhancementDesign,
        enhancementAppId: data.enhancementAppId,
        history: data.history.toList(),
      );
    } else {
      setState(() {
        _activeForgeCode = app['html_blob'];
        _activeBackendCode = app['backend_blob'];
        _activePeriodicBackendCode = app['periodic_backend_blob'];
        _activeDesignDoc = app['design_doc'];
        _activeReleaseNotes = app['release_notes'];
        _activeAppId = appId;
        _showPreview = true;
      });
    }
  }

  void _onConversationSelected(String conversationId, String title) async {
    final repository = context.read<ConversationRepository>();
    final data = await repository.getConversation(conversationId);

    setState(() {
      _currentConversationId = conversationId;
      _conversationTitle = title;
      _activeForgeCode = null; 
      _activeBackendCode = null;
      _activePeriodicBackendCode = null;
      _showPreview = false;
      _enhancementCode = data.enhancementCode;
      _enhancementBackend = data.enhancementBackend;
      _enhancementPeriodicBackend = data.enhancementPeriodicBackend;
      _enhancementDesign = data.enhancementDesign;
      _enhancementAppId = data.enhancementAppId;
      _currentMode = data.forgeMode;
    });

    _initializeAI(
      enhancementCode: data.enhancementCode,
      enhancementBackend: data.enhancementBackend,
      enhancementPeriodicBackend: data.enhancementPeriodicBackend,
      enhancementDesign: data.enhancementDesign,
      enhancementAppId: data.enhancementAppId,
      history: data.history.toList(),
      mode: data.forgeMode,
    );
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $label to copy.')),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  void _showContextDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Original Code', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(_enhancementCode ?? '', 'Original code'),
                    tooltip: 'Copy Original Code',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: '```html\n${_enhancementCode ?? ''}\n```',
                selectable: true,
                builders: {
                  'code': CodeElementBuilder(context),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  code: const TextStyle(backgroundColor: Colors.transparent),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Original Backend', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(_enhancementBackend ?? '', 'Original backend'),
                    tooltip: 'Copy Original Backend',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: '```javascript\n${_enhancementBackend ?? ''}\n```',
                selectable: true,
                builders: {
                  'code': CodeElementBuilder(context),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  code: const TextStyle(backgroundColor: Colors.transparent),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Background Periodic', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(_enhancementPeriodicBackend ?? '', 'Background periodic code'),
                    tooltip: 'Copy Background Periodic Code',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: '```javascript\n${_enhancementPeriodicBackend ?? ''}\n```',
                selectable: true,
                builders: {
                  'code': CodeElementBuilder(context),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  code: const TextStyle(backgroundColor: Colors.transparent),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Design Document', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copyToClipboard(_enhancementDesign ?? '', 'Design document'),
                    tooltip: 'Copy Design Document',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MarkdownBody(
                data: _enhancementDesign ?? 'No design document provided.',
                selectable: true,
                builders: {
                  'code': CodeElementBuilder(context),
                },
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  code: const TextStyle(backgroundColor: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('MicroForge'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: _createNewForge),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final currentHistory = _provider?.history.toList();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  _initializeAI(
                    enhancementCode: _enhancementCode,
                    enhancementBackend: _enhancementBackend,
                    enhancementDesign: _enhancementDesign,
                    history: currentHistory,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.feedback_outlined),
                onPressed: () {
                  BetterFeedback.of(context).show((feedback) async {
                    final directory = await getTemporaryDirectory();
                    final imagePath = '${directory.path}/feedback_screenshot.png';
                    final imageFile = File(imagePath);
                    await imageFile.writeAsBytes(feedback.screenshot);

                    await Share.shareXFiles(
                      [XFile(imagePath)],
                      text: feedback.text,
                    );
                  });
                },
              ),
            ],
          ),
          drawer: AppVaultDrawer(
            onAppSelected: loadApp,
            onConversationSelected: _onConversationSelected,
          ),
          body: _provider == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: _provider!,
                  builder: (context, _) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final colorScheme = Theme.of(context).colorScheme;

                    return Stack(
                      children: [
                        MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: Column(
                            children: [
                              Expanded(child: LlmChatView(
                                  provider: _provider!,
                                  style: LlmChatViewStyle(
                                    backgroundColor: Colors.transparent,
                                    progressIndicatorColor: colorScheme.primary,
                                  userMessageStyle: UserMessageStyle(
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: TextStyle(color: colorScheme.onPrimary),
                                  ),
                                  llmMessageStyle: LlmMessageStyle(
                                    icon: Icons.circle,
                                    iconColor: Colors.transparent,
                                    iconDecoration: const BoxDecoration(color: Colors.transparent),
                                    decoration: null,
                                    padding: EdgeInsets.zero,
                                    margin: const EdgeInsets.only(left: -28, top: 4, bottom: 4),
                                    maxWidth: double.infinity,
                                    minWidth: 0,
                                    flex: 100,
                                  ),
                                  chatInputStyle: ChatInputStyle(
                                    backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                                    textStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                                    hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey[900] : Colors.white,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                                      ),
                                    ),
                                  ),
                                  submitButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  addButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  attachFileButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  cameraButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  galleryButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  recordButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  stopButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : colorScheme.error,
                                  ),
                                  cancelButtonStyle: ActionButtonStyle(
                                    iconColor: isDark ? Colors.white : Colors.black,
                                    iconDecoration: BoxDecoration(
                                      color: isDark ? Colors.black : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  menuColor: isDark ? Colors.grey[850] : Colors.white,
                                  actionButtonBarDecoration: BoxDecoration(
                                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                responseBuilder: (context, message) => VibeDetector(
                                  message: message,
                                  onViewContext: _showContextDialog,
                                onDeploy: (code, backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon, {isTemporary = false}) => 
                                    onDeploy(code, backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon, isTemporary: isTemporary),
                                  onOpenApp: _onOpenApp,
                                  onAutoRefine: (code, backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon) async {
                                    if (!_showPreview) {
                                      onDeploy(code, backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon, isTemporary: true);
                                      // Give WebView some time to load before attempting to capture logs/screenshot
                                      await Future.delayed(const Duration(milliseconds: 1500));
                                    }
                                    
                                    if (_previewSheetKey.currentState != null) {
                                      _previewSheetKey.currentState!.handleAutoRefine();
                                    } else if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to start refinement. Please try again.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            ],
                          ),
                        ),

                        if (_provider!.history.isEmpty)
                          IgnorePointer(
                            child: Center(
                              child: Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  final name = auth.user?.displayName ?? 'there';
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Hello! $name,',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                              color: Colors.blueGrey[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      RollingGreeting(
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Colors.blueGrey[400],
                                            ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (_showPreview && _activeForgeCode != null)
          PreviewSheet(
            key: _previewSheetKey,
            code: _activeForgeCode!,
            backendCode: _activeBackendCode,
            periodicBackendCode: _activePeriodicBackendCode,
            designDoc: _activeDesignDoc,
            releaseNotes: _activeReleaseNotes,
            appId: _activeAppId ?? 'unknown',
            onClose: () => setState(() => _showPreview = false),
            onEnhance: onEnhance,
            onFeedback: _onFeedback,
            onAutoRefine: _onAutoRefine,
            onSaveData: (key, value) {
              // Handled by the internal bridge now
            },
          ),
      ],
    );
  }
}
