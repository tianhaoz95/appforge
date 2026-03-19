import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appforge/screens/settings_screen.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:appforge/providers/auth_provider.dart' as app_auth;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:mocktail/mocktail.dart';

class MockAuthProvider extends Mock implements app_auth.AuthProvider {}
class MockUser extends Mock implements firebase_auth.User {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockUser mockUser;
  late SettingsProvider settingsProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuthProvider = MockAuthProvider();
    mockUser = MockUser();
    settingsProvider = SettingsProvider();

    when(() => mockAuthProvider.user).thenReturn(mockUser);
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.email).thenReturn('test@example.com');
  });

  Widget createSettingsScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<app_auth.AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen shows View System Prompt option', (WidgetTester tester) async {
    // Set a large surface size to ensure all items are in view
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createSettingsScreen());
    expect(find.text('AI AGENT PREFERENCES'), findsOneWidget); // Section header
    expect(find.text('View System Prompt'), findsOneWidget); // Item title
    expect(find.text('Inspect the instructions sent to the AI'), findsOneWidget);
  });

  testWidgets('Tapping View System Prompt icon shows dialog with prompt', (WidgetTester tester) async {
    // Set a large surface size to ensure all items are in view
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    settingsProvider.setSystemPrompt('Test System Prompt');
    await tester.pumpWidget(createSettingsScreen());

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.text('System Prompt'), findsOneWidget);
    expect(find.text('Test System Prompt'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('SettingsScreen shows Token Usage section with counts', (WidgetTester tester) async {
    // Set a large surface size to ensure all items are in view
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    
    await settingsProvider.addTokenUsage(1234, 5678, 6912);
    await tester.pumpWidget(createSettingsScreen());

    expect(find.text('TOKEN USAGE'), findsOneWidget);
    expect(find.text('Prompt Tokens'), findsOneWidget);
    expect(find.text('Candidate Tokens'), findsOneWidget);
    expect(find.text('Total Tokens'), findsOneWidget);

    // Verify formatted values (with commas)
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('5,678'), findsOneWidget);
    expect(find.text('6,912'), findsOneWidget);
  });
}
