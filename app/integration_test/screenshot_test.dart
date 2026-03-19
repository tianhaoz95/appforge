import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appforge/firebase_options.dart';
import 'package:appforge/main.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/local_database.dart';
import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class MockLlmProvider extends LlmProvider with ChangeNotifier {
  final List<ChatMessage> _history = [];

  @override
  List<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> newHistory) {
    _history.clear();
    _history.addAll(newHistory);
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    yield "Thinking...";
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    yield* sendMessageStream(prompt, attachments: attachments);
  }
}

class MockAuthProvider extends AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  User? get user => null; 
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    PreviewSheet.skipWebViewForTesting = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Capture Play Store Screenshots', (WidgetTester tester) async {
    final mockLlm = MockLlmProvider();
    MicroForgeHomePage.mockProvider = mockLlm;

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
          ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Home Empty State
    await binding.takeScreenshot('1_home_empty');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 2. Home with Prompt
    // Find the chat input and enter text
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField, 'Create a beautiful Weather App with a glassmorphism design.');
      await tester.pumpAndSettle();
      await binding.takeScreenshot('2_home_prompt');
    }

    // 3. Home Generating / Generated
    final mockResponse = '''
Sure! I'll forge a beautiful Weather App for you.
<name>Glass Weather</name>
<icon>🌤️</icon>
<design>A glassmorphism weather app using Tailwind CSS.</design>
<version>1.0.0</version>
<release_notes>Initial release</release_notes>
<forge>
<div class="p-8 h-full bg-gradient-to-br from-blue-400 to-indigo-600 flex items-center justify-center">
  <div class="bg-white/20 backdrop-blur-lg rounded-3xl p-8 border border-white/30 shadow-2xl text-white w-full max-w-sm">
    <div class="text-center">
      <h1 class="text-2xl font-light">San Francisco</h1>
      <div class="text-7xl font-bold my-4">72°</div>
      <div class="text-xl">Sunny</div>
    </div>
  </div>
</div>
</forge>
''';

    mockLlm.history = [
      ChatMessage(origin: MessageOrigin.user, text: 'Create a beautiful Weather App with a glassmorphism design.', attachments: const []),
      ChatMessage(origin: MessageOrigin.llm, text: mockResponse, attachments: const []),
    ];
    await tester.pumpAndSettle();
    await binding.takeScreenshot('3_home_generated');

    // 4. Forge Preview
    final deployButton = find.text('Deploy', skipOffstage: false);
    if (deployButton.evaluate().isNotEmpty) {
      await tester.ensureVisible(deployButton);
      await tester.tap(deployButton);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await binding.takeScreenshot('4_forge_preview');
      
      // Close preview for next screenshot
      final closeButton = find.byIcon(Icons.close);
      if (closeButton.evaluate().isNotEmpty) {
        await tester.tap(closeButton);
        await tester.pumpAndSettle();
      }
    }

    // 5. App Vault (Drawer)
    final scaffold = find.byType(Scaffold).first;
    final state = tester.state(scaffold) as ScaffoldState;
    state.openDrawer();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('5_app_vault');
  });
}
