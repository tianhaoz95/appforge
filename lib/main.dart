import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep Firebase for AI if needed, but we could also move it later
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final dbHelper = LocalDatabase();
  
  runApp(
    MultiProvider(
      providers: [
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
    return MaterialApp(
      title: 'MicroForge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const MicroForgeHomePage(),
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

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() async {
    const systemPrompt = 'You are MicroForge AI. You help users "forge" micro-apps. '
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
        '\n\nNEW CAPABILITY: Local Storage API. '
        'You can use the `window.MicroForge` bridge to persist data locally. '
        'Methods: '
        '- `window.MicroForge.saveData(key, value)`: Returns a Promise. '
        '- `window.MicroForge.getData(key)`: Returns a Promise that resolves to the value. '
        '- `window.MicroForge.deleteData(key)`: Returns a Promise. '
        '- `window.MicroForge.listAll()`: Returns a Promise that resolves to an object of all keys/values. '
        '- `window.MicroForge.closeApp()`: Closes the micro-app preview. '
        '\nExample of Alpine.js integration: '
        'x-data="{ items: [], newItem: \'\' }" '
        'x-init="items = await window.MicroForge.getData(\'items\') || []" '
        '@submit.prevent="items.push(newItem); await window.MicroForge.saveData(\'items\', items); newItem = \'\'"';

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

    final primaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      systemInstruction: Content.system(systemPrompt),
    );

    final secondaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.0-flash',
      systemInstruction: Content.system(systemPrompt),
    );

    final provider = FallbackLlmProvider(
      primary: FirebaseProvider(model: primaryModel),
      secondary: FirebaseProvider(model: secondaryModel),
    );

    provider.addListener(_onHistoryChanged);

    setState(() {
      _provider = provider;
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
    repository.saveConversation(_currentConversationId, _conversationTitle, history.toList());
  }

  void _createNewForge() {
    setState(() {
      _activeForgeCode = null;
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'New Conversation';
      if (_provider != null) {
        _provider!.history = [];
      }
    });
  }

  void _togglePreview() {
    if (_activeForgeCode != null) {
      setState(() {
        _showPreview = !_showPreview;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No app forged yet!')));
    }
  }

  void _onEnhance() {
    if (_activeForgeCode == null) return;

    final name = _conversationTitle != 'New Conversation' ? _conversationTitle : 'Forged App';
    final contextPrompt = "Context: I am working on a micro-app named '$name'.\n\n"
        "Current Implementation:\n<forge>${_activeForgeCode}</forge>\n\n"
        "Design Document:\n<design>${_activeDesignDoc ?? 'No design document provided.'}</design>\n\n"
        "I want to enhance this app. Please help me based on my next instructions.";

    setState(() {
      _showPreview = false;
      _currentConversationId = const Uuid().v4();
      _conversationTitle = 'Enhance $name';
      if (_provider != null) {
        _provider!.history = [
          ChatMessage(
            origin: MessageOrigin.user,
            text: contextPrompt,
            attachments: const [],
          ),
          ChatMessage(
            origin: MessageOrigin.llm,
            text: "I've loaded your app '$name'. How would you like to enhance it?",
            attachments: const [],
          ),
        ];
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Starting new conversation to enhance $name...')),
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

  void _onAppSelectedFromVault(Map<String, dynamic> app) async {
    final conversationId = app['conversationId'];
    final appId = app['appId'];
    if (conversationId != null) {
      final repository = context.read<ConversationRepository>();
      final history = await repository.getConversation(conversationId);
      
      setState(() {
        _activeForgeCode = app['html_blob'];
        _activeDesignDoc = app['design_doc'];
        _activeAppId = appId;
        _showPreview = true;
        _currentConversationId = conversationId;
        _conversationTitle = app['name'] ?? 'Forged App';
        if (_provider != null) {
          _provider!.history = history;
        }
      });
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
    final history = await repository.getConversation(conversationId);

    setState(() {
      _currentConversationId = conversationId;
      _conversationTitle = title;
      _activeForgeCode = null; // Don't show preview until deployed again or we could find the latest forge in history
      _showPreview = false;
      if (_provider != null) {
        _provider!.history = history;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MicroForge'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createNewForge),
          IconButton(
            icon: const Icon(Icons.rocket_launch),
            onPressed: _togglePreview,
            color: _activeForgeCode != null ? Colors.orange : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: AppVaultDrawer(
        onAppSelected: _onAppSelectedFromVault,
        onConversationSelected: _onConversationSelected,
      ),
      body: _provider == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                LlmChatView(
                  provider: _provider!,
                  responseBuilder: (context, message) =>
                      VibeDetector(message: message, onDeploy: _onDeploy),
                ),
                if (_showPreview && _activeForgeCode != null)
                  PreviewSheet(
                    code: _activeForgeCode!,
                    designDoc: _activeDesignDoc,
                    appId: _activeAppId ?? 'unknown',
                    onClose: () => setState(() => _showPreview = false),
                    onEnhance: _onEnhance,
                    onSaveData: (key, value) {
                      // Handled by the internal bridge now
                    },
                  ),
              ],
            ),
    );
  }
}
