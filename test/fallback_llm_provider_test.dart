import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:appforge/providers/fallback_llm_provider.dart';
import 'package:flutter/material.dart';

class MockBaseLlmProvider extends LlmProvider with ChangeNotifier {
  String? lastPrompt;
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
    lastPrompt = prompt;
    yield "Response to: $prompt";
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    yield* sendMessageStream(prompt, attachments: attachments);
  }
}

void main() {
  late MockBaseLlmProvider primary;
  late MockBaseLlmProvider secondary;
  late FallbackLlmProvider fallback;

  setUp(() {
    primary = MockBaseLlmProvider();
    secondary = MockBaseLlmProvider();
    fallback = FallbackLlmProvider(primary: primary, secondary: secondary);
  });

  test('FallbackLlmProvider injects plan instruction on first message in Plan Mode', () async {
    fallback.setMode(ForgeMode.plan);
    
    final stream = fallback.sendMessageStream('Hello');
    await stream.drain();

    expect(primary.lastPrompt, contains('Hello'));
    expect(primary.lastPrompt, contains('[MODE: PLAN]'));
  });

  test('FallbackLlmProvider does not inject instruction on subsequent messages in same mode', () async {
    fallback.setMode(ForgeMode.plan);
    
    // First message
    await fallback.sendMessageStream('First').drain();
    expect(primary.lastPrompt, contains('[MODE: PLAN]'));

    // Second message
    await fallback.sendMessageStream('Second').drain();
    expect(primary.lastPrompt, isNot(contains('[MODE: PLAN]')));
    expect(primary.lastPrompt, equals('Second'));
  });

  test('FallbackLlmProvider injects build instruction when switching from Plan to Build', () async {
    fallback.setMode(ForgeMode.plan);
    await fallback.sendMessageStream('Plan request').drain();

    fallback.setMode(ForgeMode.build);
    await fallback.sendMessageStream('Build request').drain();

    expect(primary.lastPrompt, contains('Build request'));
    expect(primary.lastPrompt, contains('[MODE: BUILD]'));
  });

  test('FallbackLlmProvider defaults to Build Mode and injects instruction on first message', () async {
    // Default is build mode
    expect(fallback.currentMode, ForgeMode.build);

    await fallback.sendMessageStream('Initial').drain();
    expect(primary.lastPrompt, contains('[MODE: BUILD]'));

    await fallback.sendMessageStream('Next').drain();
    expect(primary.lastPrompt, equals('Next'));
  });

  test('FallbackLlmProvider resets lastModeSent when history is cleared', () async {
    fallback.setMode(ForgeMode.plan);
    await fallback.sendMessageStream('First').drain();
    expect(primary.lastPrompt, contains('[MODE: PLAN]'));

    // Clear history (new conversation)
    fallback.history = [];
    
    await fallback.sendMessageStream('New conversation first message').drain();
    expect(primary.lastPrompt, contains('[MODE: PLAN]'));
  });
}
