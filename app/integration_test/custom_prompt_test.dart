import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:appforge/firebase_options.dart';
import 'package:appforge/main.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/repositories/local_database.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:appforge/providers/llm_abstraction/openai_handler.dart';
import 'dart:math';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Custom System Prompt Local Model Test', () {
    testWidgets('Build todo app with custom system prompt', (WidgetTester tester) async {
      // 1. Initialize Firebase and App State
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      const String host = String.fromEnvironment('LOCAL_IP', defaultValue: '10.0.2.2');
      const String customPrompt = String.fromEnvironment('CUSTOM_SYSTEM_PROMPT', defaultValue: '');
      const String userPrompt = String.fromEnvironment('USER_PROMPT', defaultValue: 'build a todo app');
      
      debugPrint('Connecting to Firebase Emulator at $host');
      try {
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.settings = const Settings(
          host: '$host:8080',
          sslEnabled: false,
          persistenceEnabled: false,
        );
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      } catch (e) {
        debugPrint('Emulator already connected or failed: $e');
      }

      await ensureSnowglobeInitialized();

      // BYPASS UI AUTH
      final String testEmail = 'test_prompt_${Random().nextInt(10000)}@example.com';
      const String testPassword = 'password123';
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: testEmail, password: testPassword);

      final dbHelper = LocalDatabase();
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider(
              create: (_) => MicroAppRepository(dbHelper: dbHelper),
            ),
            Provider(create: (_) => MicroAppDataRepository(dbHelper: dbHelper)),
            ChangeNotifierProvider(
              create: (_) => ConversationRepository(dbHelper: dbHelper),
            ),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(),
            ),
          ],
          child: const MyApp(),
        ),
      );
      
      await tester.pumpAndSettle(const Duration(seconds: 5));

      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Checking for login screen'});
      if (find.text('MicroForge').evaluate().isEmpty) {
        SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Performing login'});
        final emailField = find.byType(TextField).at(0);
        await tester.enterText(emailField, testEmail);
        await tester.enterText(find.byType(TextField).at(1), testPassword);
        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }

      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: App is open, going to settings'});
      expect(find.text('MicroForge'), findsOneWidget);

      // 4. Go to Settings and configure
      final settingsButton = find.byWidgetPredicate((w) => w is IconButton && w.icon is Icon && (w.icon as Icon).icon == Icons.settings);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Enable Local Model
      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Enabling Local Model in settings'});
      final localModelText = find.text('Use Local LLM (On-device)');
      await tester.scrollUntilVisible(localModelText, 200);
      final localModelSwitchFinder = find.ancestor(of: localModelText, matching: find.byType(ListTile));
      final switchFinder = find.descendant(of: localModelSwitchFinder, matching: find.byType(Switch));
      final switchWidget = tester.widget<Switch>(switchFinder);
      if (!switchWidget.value) {
        await tester.tap(switchFinder);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Check if model is downloaded, if not, trigger download
      if (!settingsProvider.isModelDownloaded) {
        SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Model not found, triggering download...'});
        settingsProvider.setSilent(true);
        await settingsProvider.downloadModel();
        // Wait for download to finish
        int downloadAttempts = 0;
        while (!settingsProvider.isModelDownloaded && downloadAttempts < 300) {
          await tester.pump(const Duration(seconds: 1));
          downloadAttempts++;
          if (downloadAttempts % 30 == 0) SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'Still downloading... $downloadAttempts s'});
        }
        settingsProvider.setSilent(false);
        settingsProvider.notifyListeners();
      }

      // Inject custom prompt if provided
      if (customPrompt.isNotEmpty) {
        SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Injecting custom system prompt: $customPrompt'});
        await settingsProvider.setCustomSystemPrompt(customPrompt);
        await tester.pumpAndSettle();
      }

      // Wait for model ready
      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Waiting for model ready status...'});
      int attempts = 0;
      while (attempts < 120) { 
        if (settingsProvider.isEngineInitialized) {
          SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Model engine is ready!'});
          break;
        }
        await tester.pump(const Duration(seconds: 1));
        attempts++;
      }
      expect(settingsProvider.isEngineInitialized, isTrue, reason: 'Model engine did not reach ready state');

      // 5. Back to Chat
      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Going back to chat'});
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 6. Send message
      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Sending message: $userPrompt'});
      final chatTextField = find.byType(EditableText).last; 
      await tester.tap(chatTextField);
      await tester.pumpAndSettle();
      await tester.enterText(chatTextField, userPrompt);
      await tester.pumpAndSettle();
      
      // Use the keyboard send action for reliability
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 7. Observe response and assert <forge> tag
      SystemChannels.platform.invokeMethod('SystemChrome.setApplicationSwitcherDescription', {'label': 'MILESTONE: Waiting for model response...'});
      bool foundForge = false;
      String fullResponse = '';
      
      for (int i = 0; i < 300; i++) { // Wait up to 150 seconds
        await tester.pump(const Duration(milliseconds: 500));
        
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final tw in textWidgets) {
          final txt = tw.data ?? '';
          if (txt.length > 10 && !txt.contains('build a todo app') && !txt.contains('MicroForge') && !txt.contains('Settings')) {
            fullResponse = txt;
            if (txt.contains('<forge>')) {
              foundForge = true;
              break;
            }
          }
        }
        if (foundForge) break;
      }

      debugPrint('Final response snippet: ${fullResponse.length > 100 ? fullResponse.substring(0, 100) : fullResponse}');
      expect(foundForge, isTrue, reason: 'Model response did not contain <forge> tag. Response was: $fullResponse');
      debugPrint('Test passed! Micro-app forged successfully.');
    });
  });
}
