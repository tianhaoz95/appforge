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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    Provider(
      create: (_) => MicroAppRepository(),
      child: const MyApp(),
    ),
  );
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
  late final LlmProvider _provider;
  String? _activeForgeCode;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  void _initializeAI() {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
    );
    _provider = FirebaseProvider(model: model);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app forged yet!')),
      );
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
      drawer: AppVaultDrawer(
        onAppSelected: _onAppSelectedFromVault,
      ),
      body: Stack(
        children: [
          LlmChatView(
            provider: _provider,
            responseBuilder: (context, message) => VibeDetector(
              message: message,
              onDeploy: _onDeploy,
            ),
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
