import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:appforge/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI Logic Integration Test - Connect to Gemini', (WidgetTester tester) async {
    // 1. Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 2. Configure Firebase AI Logic with gemini-3.1-flash-lite-preview
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
    );

    final provider = FirebaseProvider(model: model);

    // 3. Verify connectivity by sending a simple prompt
    // We expect a stream of text responses.
    final stream = provider.sendMessageStream('Say "Forge!"');
    
    String fullResponse = '';
    await for (final chunk in stream) {
      fullResponse += chunk;
    }

    expect(fullResponse.toLowerCase(), contains('forge'));
  });
}
