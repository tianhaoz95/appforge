import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/screens/auth/login_screen.dart';
import 'package:appforge/screens/auth/register_screen.dart';
import 'package:appforge/screens/auth/forgot_password_screen.dart';
import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthProvider mockAuthProvider;
  late SettingsProvider settingsProvider;

  setUp(() {
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '.';
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    mockAuthProvider = MockAuthProvider();
    settingsProvider = SettingsProvider();
    // Default mock behavior
    when(() => mockAuthProvider.isAuthenticated).thenReturn(false);
  });

  Widget createAuthScreen(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: MaterialApp(
        home: screen,
      ),
    );
  }

  testWidgets('LoginScreen shows all required fields, buttons, and checkbox', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen(const LoginScreen()));

    expect(find.text('MicroForge'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Remember Me'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
  });

  testWidgets('LoginScreen pre-fills email when rememberMe is true', (WidgetTester tester) async {
    const email = 'remembered@example.com';
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'remembered_email': email,
    });
    await settingsProvider.loadSettings();

    await tester.pumpWidget(createAuthScreen(const LoginScreen()));

    expect(find.text(email), findsOneWidget);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('RegisterScreen shows all required fields and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen(const RegisterScreen()));

    expect(find.text('Join MicroForge'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4)); // Name, Email, Password, Confirm
    expect(find.text('Register'), findsNWidgets(2)); // Title and Button
  });

  testWidgets('ForgotPasswordScreen shows email field and reset button', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen(const ForgotPasswordScreen()));

    expect(find.text('Password Recovery'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // Email
    expect(find.widgetWithText(ElevatedButton, 'Reset Password'), findsOneWidget);
  });

  testWidgets('LoginScreen calls signIn on button tap', (WidgetTester tester) async {
    when(() => mockAuthProvider.signIn(any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createAuthScreen(const LoginScreen()));

    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.enterText(find.byType(TextField).last, 'password123');
    await tester.ensureVisible(find.text('Sign In'));
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    verify(() => mockAuthProvider.signIn('test@example.com', 'password123')).called(1);
  });

  testWidgets('RegisterScreen calls signUp on button tap', (WidgetTester tester) async {
    when(() => mockAuthProvider.signUp(any(), any(), any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createAuthScreen(const RegisterScreen()));

    await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'Test User');
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'password123');
    
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
    await tester.pump();

    verify(() => mockAuthProvider.signUp('test@example.com', 'password123', 'Test User')).called(1);
  });

  testWidgets('LoginScreen password visibility toggle works', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen(const LoginScreen()));

    final passwordFieldFinder = find.widgetWithText(TextField, 'Password');
    TextField passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isFalse);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    passwordField = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('RegisterScreen password visibility toggles work', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthScreen(const RegisterScreen()));

    final passwordFieldFinder = find.widgetWithText(TextField, 'Password');
    final confirmPasswordFieldFinder = find.widgetWithText(TextField, 'Confirm Password');

    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isTrue);
    expect(tester.widget<TextField>(confirmPasswordFieldFinder).obscureText, isTrue);

    // Toggle password visibility
    await tester.tap(find.descendant(
      of: passwordFieldFinder,
      matching: find.byType(IconButton),
    ));
    await tester.pump();

    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isFalse);
    expect(tester.widget<TextField>(confirmPasswordFieldFinder).obscureText, isTrue);

    // Toggle confirm password visibility
    await tester.tap(find.descendant(
      of: confirmPasswordFieldFinder,
      matching: find.byType(IconButton),
    ));
    await tester.pump();

    expect(tester.widget<TextField>(passwordFieldFinder).obscureText, isFalse);
    expect(tester.widget<TextField>(confirmPasswordFieldFinder).obscureText, isFalse);
  });
}
