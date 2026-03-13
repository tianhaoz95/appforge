import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'widgets/app_vault_drawer.dart';
import 'widgets/vibe_detector.dart';
import 'widgets/preview_sheet.dart';
import 'repositories/micro_app_repository.dart';
import 'repositories/conversation_repository.dart';
import 'repositories/micro_app_data_repository.dart';
import 'repositories/local_database.dart';
import 'providers/fallback_llm_provider.dart';
import 'providers/hybrid_inference_manager.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInitializationSettings = DarwinInitializationSettings();
  const initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
    iOS: iosInitializationSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

  // Keep Firebase for AI if needed, but we could also move it later
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final dbHelper = LocalDatabase();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        Provider(create: (_) => MicroAppRepository(dbHelper: dbHelper)),
        Provider(create: (_) => MicroAppDataRepository(dbHelper: dbHelper)),
        Provider(create: (_) => ConversationRepository(dbHelper: dbHelper)),
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
      child: MaterialApp(
        title: 'MicroForge',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
          useMaterial3: true,
        ),
        home: const MicroForgeHomePage(),
      ),
    );
  }
}

class MicroForgeHomePage extends StatefulWidget {
  const MicroForgeHomePage({super.key});

  @override
  State<MicroForgeHomePage> createState() => _MicroForgeHomePageState();
}

class _MicroForgeHomePageState extends State<MicroForgeHomePage> {
  LlmProvider? _provider;
  String? _activeForgeCode;
  String? _activeDesignDoc;
  String? _activeAppId;
  bool _showPreview = false;
  String _currentConversationId = const Uuid().v4();
  String _conversationTitle = 'New Conversation';
  String? _enhancementCode;
  String? _enhancementDesign;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI({
    String? enhancementCode,
    String? enhancementDesign,
    List<ChatMessage>? history,
  }) async {
    final settings = context.read<SettingsProvider>();
    final repository = context.read<MicroAppRepository>();

    String systemPrompt = 'You are MicroForge AI. You help users "forge" micro-apps. '
        'Whenever you provide code for a micro-app (HTML/Alpine.js/Tailwind), '
        'you MUST wrap it inside <forge>...</forge> tags. '
        'Example: <forge><div class="p-4">Hello</div></forge>. '
        'Additionally, for every micro-app you forge, you MUST also provide: '
        '1. A concise name wrapped in <name>...</name> tags. '
        '2. A brief design document in Markdown wrapped in <design>...</design> tags. '
        '\nExample: '
        '<name>Task Master</name> '
        '<design># Task Master\nA simple todo app with local persistence.</design> '
        '<forge><div class="p-4">...</div></forge> '
        '\n\nDo not use other markdown blocks for the micro-app code itself. '
        'Use Tailwind CSS for styling and Alpine.js for reactivity. '
        'The micro-apps should be self-contained and visually appealing. '
        '\n\nNEW CAPABILITY: URL Context. '
        'You can now access and analyze content from URLs provided in the prompt. '
        'If the user provides a link to a website, documentation, or an image, you can use that information to better fulfill their request. '
        '\n\nNEW CAPABILITY: MicroForge Bridge API. '
        'You can use the `window.MicroForge` bridge to persist data locally and call AI. '
        'Methods: '
        '- `window.MicroForge.saveData(key, value)`: Returns a Promise. '
        '- `window.MicroForge.getData(key)`: Returns a Promise that resolves to the value. '
        '- `window.MicroForge.deleteData(key)`: Returns a Promise. '
        '- `window.MicroForge.listAll()`: Returns a Promise that resolves to an object of all keys/values. '
        '- `window.MicroForge.promptAi(prompt, systemInstruction)`: Returns a Promise that resolves to the AI response text. '
        'Use `promptAi` to build AI-powered features within your micro-apps. '
        '- `window.MicroForge.pickFiles(options)`: Returns a Promise that resolves to a list of file objects. '
        'Options: `{ multiple: true/false, type: "any"/"image"/"video"/"audio"/"media"/"custom", extensions: ["pdf", "doc"] }`. '
        'File object: `{ name, size, extension, bytes (base64) }`. ';

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

    if (enhancementCode != null) {
      systemPrompt += '\n\nCONTEXT FOR ENHANCEMENT:\n'
          'You are currently enhancing an existing micro-app.\n'
          'Current Implementation:\n<forge>$enhancementCode</forge>\n\n'
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
      final apps = await repository.getAppsForOwner('local-user');
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
      primary: FirebaseProvider(model: primaryModel),
      secondary: FirebaseProvider(model: secondaryModel),
    );

    provider.addListener(_onHistoryChanged);

    if (history != null) {
      provider.history = history;
    }

    setState(() {
      _provider = provider;
      _enhancementCode = enhancementCode;
      _enhancementDesign = enhancementDesign;
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
      enhancementDesign: _enhancementDesign,
    );
  }

  void _createNewForge() {
    setState(() {
      _activeForgeCode = null;
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'New Conversation';
      _enhancementCode = null;
      _enhancementDesign = null;
      if (_provider != null) {
        _provider!.history = [];
      }
    });
    _initializeAI();
  }

  void _onEnhance() {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final codeToEnhance = _activeForgeCode!;
    final designToEnhance = _activeDesignDoc;

    setState(() {
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'Enhance $name';
      _enhancementCode = codeToEnhance;
      _enhancementDesign = designToEnhance;
    });

    _initializeAI(enhancementCode: codeToEnhance, enhancementDesign: designToEnhance);

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
          ];
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting new conversation to enhance $name...')),
    );
  }

  void _onFeedback(String text, Uint8List screenshot) {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final codeToEnhance = _activeForgeCode!;
    final designToEnhance = _activeDesignDoc;

    setState(() {
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'Feedback on $name';
      _enhancementCode = codeToEnhance;
      _enhancementDesign = designToEnhance;
    });

    _initializeAI(enhancementCode: codeToEnhance, enhancementDesign: designToEnhance);

    // Give it a moment for AI to be ready with new provider
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_provider != null) {
        setState(() {
          _provider!.history = [
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
      SnackBar(content: Text('Starting new conversation with feedback for $name...')),
    );
  }

  void _onDeploy(String code, String? name, String? designDoc) async {
    setState(() {
      _activeForgeCode = code;
      _activeDesignDoc = designDoc;
      _showPreview = true;
    });

    // Automatically save app locally
    try {
      final repository = context.read<MicroAppRepository>();
      const userId = 'local-user';

      final appId = await repository.saveApp({
        'ownerId': userId,
        'conversationId': _currentConversationId,
        'name': name ?? 'Forged App',
        'html_blob': code,
        'design_doc': designDoc,
        'version': '1.0.0',
        'icon': 'rocket',
      });

      setState(() {
        _activeAppId = appId;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${name ?? 'App'} forged and saved locally!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to save app: $e');
    }
  }

  void _onOpenApp(String appId) async {
    final repository = context.read<MicroAppRepository>();
    final app = await repository.getApp(appId);
    if (app != null) {
      _loadApp(app);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App not found!')),
        );
      }
    }
  }

  void _loadApp(Map<String, dynamic> app, {bool switchConversation = false}) async {
    final conversationId = app['conversationId'];
    final appId = app['appId'];
    if (conversationId != null && switchConversation) {
      final repository = context.read<ConversationRepository>();
      final data = await repository.getConversation(conversationId);

      setState(() {
        _activeForgeCode = app['html_blob'];
        _activeDesignDoc = app['design_doc'];
        _activeAppId = appId;
        _showPreview = true;
        _currentConversationId = conversationId;
        _conversationTitle = app['name'] ?? 'Forged App';
        _enhancementCode = data.enhancementCode;
        _enhancementDesign = data.enhancementDesign;
      });

      _initializeAI(
        enhancementCode: data.enhancementCode,
        enhancementDesign: data.enhancementDesign,
        history: data.history.toList(),
      );
    } else {
      setState(() {
        _activeForgeCode = app['html_blob'];
        _activeDesignDoc = app['design_doc'];
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
      _activeForgeCode = null; // Don't show preview until deployed again or we could find the latest forge in history
      _showPreview = false;
      _enhancementCode = data.enhancementCode;
      _enhancementDesign = data.enhancementDesign;
    });

    _initializeAI(
      enhancementCode: data.enhancementCode,
      enhancementDesign: data.enhancementDesign,
      history: data.history.toList(),
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
              Text('Original Code', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              MarkdownBody(
                data: '```html\n${_enhancementCode ?? ''}\n```',
                selectable: true,
              ),
              const SizedBox(height: 24),
              Text('Design Document', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              MarkdownBody(
                data: _enhancementDesign ?? 'No design document provided.',
                selectable: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancementIndicator() {
    if (_enhancementCode == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: Colors.indigo),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Micro app code and design are included. You can start customizing.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _showContextDialog,
            child: const Text('VIEW'),
          ),
        ],
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
                    enhancementDesign: _enhancementDesign,
                    history: currentHistory,
                  );
                },
              ),
            ],
          ),
          drawer: AppVaultDrawer(
            onAppSelected: _loadApp,
            onConversationSelected: _onConversationSelected,
          ),
          body: _provider == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _buildEnhancementIndicator(),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _provider!,
                        builder: (context, _) {
                          return Stack(
                            children: [
                              LlmChatView(
                                provider: _provider!,
                                responseBuilder: (context, message) => VibeDetector(
                                  message: message,
                                  onDeploy: _onDeploy,
                                  onOpenApp: _onOpenApp,
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
                                            Text(
                                              "let's build an app!",
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
                  ],
                ),
        ),
        if (_showPreview && _activeForgeCode != null)
          PreviewSheet(
            code: _activeForgeCode!,
            designDoc: _activeDesignDoc,
            appId: _activeAppId ?? 'unknown',
            onClose: () => setState(() => _showPreview = false),
            onEnhance: _onEnhance,
            onFeedback: _onFeedback,
            onSaveData: (key, value) {
              // Handled by the internal bridge now
            },
          ),
      ],
    );
  }
}
