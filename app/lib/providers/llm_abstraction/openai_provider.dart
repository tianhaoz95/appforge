import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'openai_handler.dart';

/// An LlmProvider implementation that uses the generic OpenAiHandler.
class OpenAiProvider extends LlmProvider with ChangeNotifier {
  final OpenAiHandler _handler;
  final String _modelName;
  final String? _systemInstruction;
  final List<ChatMessage> _history;

  OpenAiProvider({
    required OpenAiHandler handler,
    required String modelName,
    String? systemInstruction,
    Iterable<ChatMessage>? history,
  })  : _handler = handler,
        _modelName = modelName,
        _systemInstruction = systemInstruction,
        _history = history?.toList() ?? [];

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    return _sendMessageStream(prompt, attachments: attachments, updateHistory: false);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    return _sendMessageStream(prompt, attachments: attachments, updateHistory: true);
  }

  Stream<String> _sendMessageStream(
    String prompt, {
    required Iterable<Attachment> attachments,
    required bool updateHistory,
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();

    if (updateHistory) {
      _history.addAll([userMessage, llmMessage]);
      notifyListeners();
    }

    final messages = <Map<String, dynamic>>[];

    if (_systemInstruction != null && _systemInstruction.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': _systemInstruction,
      });
    }

    // Convert history
    for (final msg in (updateHistory ? _history.take(_history.length - 1) : _history)) {
      messages.add({
        'role': msg.origin.isUser ? 'user' : 'assistant',
        // Simplification: only sending text. We would need a more complex conversion for images/attachments.
        'content': msg.text ?? '',
      });
    }

    // If updateHistory is false, we manually add the current prompt
    if (!updateHistory) {
      messages.add({
        'role': 'user',
        'content': prompt,
      });
    }

    final request = OpenAiRequest(
      model: _modelName,
      messages: messages,
      stream: true,
    );

    try {
      final responseStream = _handler.executeChatCompletionStream(request);

      await for (final chunk in responseStream) {
        final choices = chunk['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta != null && delta.containsKey('content')) {
            final content = delta['content'] as String;
            if (content.isNotEmpty) {
              if (updateHistory) {
                llmMessage.append(content);
              }
              yield content;
            }
          }
        }
      }
    } catch (e) {
      final errorMessage = "Error: ${e.toString()}";
      if (updateHistory) {
        llmMessage.append(errorMessage);
      }
      yield errorMessage;
    }

    if (updateHistory) {
      notifyListeners();
    }
  }
}
