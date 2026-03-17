import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    await tester.pumpWidget(createSettingsScreen());
    expect(find.text('AI AGENT PREFERENCES'), findsOneWidget); // Section header
    expect(find.text('View System Prompt'), findsOneWidget); // Item title
    expect(find.text('Inspect the instructions sent to the AI'), findsOneWidget);
  });

  testWidgets('Tapping View System Prompt icon shows dialog with prompt', (WidgetTester tester) async {
    settingsProvider.setSystemPrompt('Test System Prompt');
    await tester.pumpWidget(createSettingsScreen());

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.text('System Prompt'), findsOneWidget);
    expect(find.text('Test System Prompt'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
