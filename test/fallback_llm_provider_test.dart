import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:appforge/providers/fallback_llm_provider.dart';
import 'package:flutter/material.dart';

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
  late MockBaseLlmProvider primary;
  late MockBaseLlmProvider secondary;
  late FallbackLlmProvider fallback;

  setUp(() {
    primary = MockBaseLlmProvider();
    secondary = MockBaseLlmProvider();
    fallback = FallbackLlmProvider(primary: primary, secondary: secondary);
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
}
