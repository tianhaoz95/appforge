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

  group('Local Model Integration Test', () {
    testWidgets('Full flow: Auth -> Settings -> Download -> Chat', (WidgetTester tester) async {
      // 1. Initialize Firebase and App State
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      const String host = String.fromEnvironment('LOCAL_IP', defaultValue: '10.0.2.2');
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

      // BYPASS UI AUTH: Create user programmatically in emulator
      final String testEmail = 'test_${Random().nextInt(10000)}@example.com';
      const String testPassword = 'password123';
      debugPrint('Creating test user: $testEmail');
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

      // 3. Verify we are on Home Screen (should be auto-logged in)
      if (find.text('MicroForge').evaluate().isEmpty) {
        debugPrint('Bypassing login screen...');
        // Try to find the email field by its label or type
        final emailField = find.byType(TextField).at(0);
        await tester.enterText(emailField, testEmail);
        await tester.enterText(find.byType(TextField).at(1), testPassword);
        final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
        await tester.tap(signInButton);
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }

      expect(find.text('MicroForge'), findsOneWidget, reason: 'Failed to reach home screen');

      // 4. Go to Settings
      final settingsButton = find.byWidgetPredicate((w) => w is IconButton && w.icon is Icon && (w.icon as Icon).icon == Icons.settings);
      expect(settingsButton, findsOneWidget, reason: 'Settings button not found');
      await tester.tap(settingsButton);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Settings'), findsOneWidget);

      // 5. Toggle Local Model
      final localModelText = find.text('Use Local LLM (On-device)');
      await tester.scrollUntilVisible(localModelText, 200);
      
      final localModelSwitchFinder = find.ancestor(
        of: localModelText,
        matching: find.byType(ListTile),
      );
      
      final switchFinder = find.descendant(of: localModelSwitchFinder, matching: find.byType(Switch));
      final switchWidget = tester.widget<Switch>(switchFinder);
      
      if (!switchWidget.value) {
        await tester.tap(switchFinder);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // 6. Download Model (if not already pushed/downloaded)
      // Since we push it via ADB in the script, it should ideally be ready
      final downloadButtonFinder = find.text('Download Qwen 3.5 (0.8B)');
      if (downloadButtonFinder.evaluate().isNotEmpty) {
        debugPrint('Model not ready, tapping download...');
        await tester.tap(downloadButtonFinder);
        await tester.pump(); 
        
        int attempts = 0;
        while (find.text('Model ready').evaluate().isEmpty && attempts < 600) { 
          await tester.pump(const Duration(seconds: 1));
          attempts++;
          if (attempts % 30 == 0) debugPrint('Still waiting for model ready... ($attempts seconds)');
        }
        expect(find.text('Model ready'), findsOneWidget, reason: 'Model download/ready timed out');
      } else {
        expect(find.text('Model ready'), findsOneWidget, reason: 'Model should be ready (it was likely pushed via ADB)');
      }

      // 7. Go back to Chat
      debugPrint('Returning to chat...');
      await tester.pageBack();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 8. Send message "build a todo app"
      debugPrint('Sending message: build a todo app');
      // On some tablets, the text field might be at index 0 or similar
      final chatTextField = find.byType(TextField);
      expect(chatTextField, findsOneWidget);
      await tester.enterText(chatTextField, 'build a todo app');
      await tester.pumpAndSettle();
      
      // Look for the send button - try both icon and generic IconButton
      final sendButton = find.byWidgetPredicate((w) => w is IconButton && w.onPressed != null);
      // Usually it's the last icon button or the one with send icon
      final sendIcon = find.byIcon(Icons.send);
      
      if (sendIcon.evaluate().isNotEmpty) {
        await tester.tap(sendIcon);
      } else {
        await tester.tap(sendButton.last);
      }
      await tester.pump();

      // 9. Observe response
      debugPrint('Waiting for model response...');
      bool foundResponse = false;
      for (int i = 0; i < 240; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        
        // We look for any text that is NOT our prompt and is fairly long
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        for (final tw in textWidgets) {
          final txt = tw.data ?? '';
          if (txt.length > 10 && !txt.contains('build a todo app') && !txt.contains('MicroForge') && !txt.contains('Settings')) {
            debugPrint('Found response chunk: ${txt.substring(0, min(30, txt.length))}...');
            foundResponse = true;
            break;
          }
        }
        if (foundResponse) break;
      }

      expect(foundResponse, isTrue, reason: 'Model did not provide a response in time (chat stuck at loading)');
      debugPrint('Integration test passed successfully!');
    });
  });
}
