import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'widgets/app_vault_drawer.dart';
import 'widgets/vibe_detector.dart';
import 'widgets/preview_sheet.dart';
import 'repositories/micro_app_repository.dart';
import 'providers/fallback_llm_provider.dart';
import 'providers/hybrid_inference_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(Provider(create: (_) => MicroAppRepository(), child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppForge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const AppForgeHomePage(),
    );
  }
}

class AppForgeHomePage extends StatefulWidget {
  const AppForgeHomePage({super.key});

  @override
  State<AppForgeHomePage> createState() => _AppForgeHomePageState();
}

class _AppForgeHomePageState extends State<AppForgeHomePage> {
  LlmProvider? _provider;
  String? _activeForgeCode;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() async {
    const systemPrompt = 'You are AppForge AI. You help users "forge" micro-apps. '
        'Whenever you provide code for a micro-app (HTML/Alpine.js/Tailwind), '
        'you MUST wrap it inside <forge>...</forge> tags. '
        'Example: <forge><div class="p-4">Hello</div></forge>. '
        'Do not use other markdown blocks for the micro-app code itself. '
        'Use Tailwind CSS for styling and Alpine.js for reactivity. '
        'The micro-apps should be self-contained and visually appealing.';

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

    setState(() {
      _provider = FallbackLlmProvider(
        primary: FirebaseProvider(model: primaryModel),
        secondary: FirebaseProvider(model: secondaryModel),
      );
    });
  }

  void _createNewForge() {
    setState(() {
      _activeForgeCode = null;
      _showPreview = false;
    });
    // TODO: Clear chat history if needed
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

  void _onDeploy(String code) {
    setState(() {
      _activeForgeCode = code;
      _showPreview = true;
    });
    // TODO: Automatically save app metadata to Firestore
  }

  void _onAppSelectedFromVault(Map<String, dynamic> app) {
    setState(() {
      _activeForgeCode = app['html_blob'];
      _showPreview = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AppForge'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createNewForge),
          IconButton(
            icon: const Icon(Icons.rocket_launch),
            onPressed: _togglePreview,
            color: _activeForgeCode != null ? Colors.orange : null,
          ),
        ],
      ),
      drawer: AppVaultDrawer(onAppSelected: _onAppSelectedFromVault),
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
                    onClose: () => setState(() => _showPreview = false),
                    onSaveData: (key, value) {
                      // TODO: Store app data back to Firestore
                    },
                  ),
              ],
            ),
    );
  }
}
