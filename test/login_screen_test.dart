import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    // Use when() if needed to stub methods
  });

  Widget createLoginScreen() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: mockAuthProvider,
      child: const MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  testWidgets('LoginScreen shows welcome text and form fields', (WidgetTester tester) async {
    await tester.pumpWidget(createLoginScreen());

    expect(find.text('Welcome to AppForge'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // Email and Password
    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.text('No account? Sign up'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('LoginScreen validates empty email and password', (WidgetTester tester) async {
    await tester.pumpWidget(createLoginScreen());

    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pump();

    expect(find.text('Invalid email'), findsOneWidget);
    expect(find.text('Password too short'), findsOneWidget);
  });
}
