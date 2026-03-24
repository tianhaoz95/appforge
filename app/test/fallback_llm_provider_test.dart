import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:appforge/providers/fallback_llm_provider.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBaseLlmProvider extends LlmProvider with ChangeNotifier {
  String? lastPrompt;
  final List<ChatMessage> _history = [];
  bool shouldFailWithOverloaded = false;

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
    lastPrompt = prompt;
    if (shouldFailWithOverloaded) {
      throw Exception('503: Service overloaded');
    }
    yield "Response to: $prompt";
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    yield* sendMessageStream(prompt, attachments: attachments);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late MockBaseLlmProvider primary;
  late MockBaseLlmProvider secondary;
  late FallbackLlmProvider fallback;
  late SettingsProvider settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    primary = MockBaseLlmProvider();
    secondary = MockBaseLlmProvider();
    settings = SettingsProvider();
    fallback = FallbackLlmProvider(primary: primary, secondary: secondary, settings: settings);
  });

  test('FallbackLlmProvider uses primary provider by default', () async {
    final stream = fallback.sendMessageStream('Hello');
    await stream.drain();

    expect(primary.lastPrompt, equals('Hello'));
    expect(secondary.lastPrompt, isNull);
  });

  test('FallbackLlmProvider falls back to secondary when primary is overloaded', () async {
    // Primary provider throws an overloaded error
    primary.shouldFailWithOverloaded = true;

    final stream = fallback.sendMessageStream('Failover Test');
    final results = await stream.toList();

    expect(results.first, contains('Response to: Failover Test'));
    expect(primary.lastPrompt, equals('Failover Test'));
    expect(secondary.lastPrompt, equals('Failover Test'));
  });

  test('FallbackLlmProvider toggles halMode on trigger strings and returns fixed response and updates history', () async {
    expect(settings.halMode, isFalse);
    expect(fallback.history, isEmpty);

    // Trigger ON
    final onStream = fallback.sendMessageStream("I’m sorry, Dave.");
    final resultsOn = await onStream.toList();
    expect(settings.halMode, isTrue);
    expect(resultsOn.first, equals("🤖 Hi 🤖"));
    expect(primary.lastPrompt, isNull); // Verify AI was NOT called
    
    expect(fallback.history.length, 2);
    expect(fallback.history[0].text, equals("I’m sorry, Dave."));
    expect(fallback.history[1].text, equals("🤖 Hi 🤖"));

    // Trigger OFF
    final offStream = fallback.sendMessageStream("This mission is too important for me to allow you to jeopardize it.");
    final resultsOff = await offStream.toList();
    expect(settings.halMode, isFalse);
    expect(resultsOff.first, equals("🤖 Hi 🤖"));
    expect(primary.lastPrompt, isNull); // Verify AI was NOT called
    
    expect(fallback.history.length, 4);
    expect(fallback.history[2].text, equals("This mission is too important for me to allow you to jeopardize it."));
    expect(fallback.history[3].text, equals("🤖 Hi 🤖"));
  });
}
