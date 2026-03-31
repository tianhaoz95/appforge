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

  group('Local AI Performance Test', () {
    testWidgets('Local model builds a todo micro-app end-to-end', (WidgetTester tester) async {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      const String host = String.fromEnvironment('LOCAL_IP', defaultValue: '10.0.2.2');
      try {
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.settings = const Settings(
          host: '$host:8080',
          sslEnabled: false,
          persistenceEnabled: false,
        );
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      } catch (e) {
        debugPrint('Emulator connect: $e');
      }

      await ensureSnowglobeInitialized();

      final testEmail = 'test_${Random().nextInt(99999)}@example.com';
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: testEmail,
        password: 'password123',
      );

      final dbHelper = LocalDatabase();
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsProvider),
            ChangeNotifierProvider(create: (_) => MicroAppRepository(dbHelper: dbHelper)),
            Provider(create: (_) => MicroAppDataRepository(dbHelper: dbHelper)),
            ChangeNotifierProvider(create: (_) => ConversationRepository(dbHelper: dbHelper)),
            ChangeNotifierProvider(create: (_) => AuthProvider()),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // ── Sign in if needed ──────────────────────────────────────────────────
      if (find.text('MicroForge').evaluate().isEmpty) {
        await tester.enterText(find.byType(TextField).at(0), testEmail);
        await tester.enterText(find.byType(TextField).at(1), 'password123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
        await tester.pumpAndSettle(const Duration(seconds: 10));
      }
      expect(find.text('MicroForge'), findsOneWidget, reason: 'Home screen not reached');

      // ── Open Settings ──────────────────────────────────────────────────────
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Settings'), findsOneWidget);

      // ── Enable Local LLM ───────────────────────────────────────────────────
      final localLlmTile = find.text('Use Local LLM (On-device)');
      await tester.scrollUntilVisible(localLlmTile, 300);
      final switchFinder = find.descendant(
        of: find.ancestor(of: localLlmTile, matching: find.byType(ListTile)),
        matching: find.byType(Switch),
      );
      if (!(tester.widget<Switch>(switchFinder).value)) {
        await tester.tap(switchFinder);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // ── Download model (or confirm already ready via ADB push) ─────────────
      final downloadBtn = find.text('Download Model (0.8B)');
      if (downloadBtn.evaluate().isNotEmpty) {
        debugPrint('Tapping download...');
        await tester.tap(downloadBtn);
        await tester.pump();
        for (int i = 0; i < 600; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find.text('Model ready').evaluate().isNotEmpty) break;
          if (i % 30 == 0) debugPrint('Waiting for model... ${i}s');
        }
      }
      expect(find.text('Model ready'), findsOneWidget, reason: 'Model not ready');

      // ── Switch system prompt to Compact ───────────────────────────────────
      await tester.scrollUntilVisible(find.byIcon(Icons.edit_document), 300);
      await tester.tap(find.byIcon(Icons.edit_document));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the preset menu (PopupMenuButton) and select Compact Default
      final presetMenuBtn = find.byIcon(Icons.expand_more);
      if (presetMenuBtn.evaluate().isNotEmpty) {
        await tester.tap(presetMenuBtn.first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compact Default'));
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }

      // Save
      final saveBtn = find.text('Save');
      if (saveBtn.evaluate().isNotEmpty) {
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
      }

      // ── Back to home ───────────────────────────────────────────────────────
      await tester.pageBack(); // SystemPromptScreen → Settings
      await tester.pumpAndSettle();
      await tester.pageBack(); // Settings → Home
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('MicroForge'), findsOneWidget, reason: 'Did not return to home');

      // ── Send "build a todo app" ────────────────────────────────────────────
      final chatField = find.byType(TextField);
      expect(chatField, findsOneWidget);
      await tester.enterText(chatField, 'build a todo app');
      await tester.pumpAndSettle();

      final sendIcon = find.byIcon(Icons.send);
      if (sendIcon.evaluate().isNotEmpty) {
        await tester.tap(sendIcon);
      } else {
        await tester.tap(find.byWidgetPredicate((w) => w is IconButton && w.onPressed != null).last);
      }
      await tester.pump();

      // ── Wait for <forge> tag in response (up to 5 min for local model) ─────
      debugPrint('Waiting for model to build micro-app...');
      bool forgeDetected = false;
      for (int i = 0; i < 600; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        // VibeDetector renders a Deploy button when <forge> is present
        if (find.text('Deploy').evaluate().isNotEmpty) {
          forgeDetected = true;
          debugPrint('Forge detected at ${i * 0.5}s');
          break;
        }
        if (i % 60 == 0) debugPrint('Still waiting... ${i * 0.5}s');
      }

      expect(forgeDetected, isTrue,
          reason: 'Local model did not produce a <forge> micro-app within timeout. '
              'Consider tightening the compact system prompt.');

      debugPrint('✅ Local AI performance test passed — micro-app successfully built.');
    });
  });
}
