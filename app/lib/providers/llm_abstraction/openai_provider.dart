import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart' as toolkit;
import 'package:openai_dart/openai_dart.dart' as openai;
import 'openai_handler.dart';

/// An LlmProvider implementation that uses the generic OpenAiHandler.
class OpenAiProvider extends toolkit.LlmProvider with ChangeNotifier {
  final OpenAiHandler _handler;
  final String _modelName;
  final String? _systemInstruction;
  final List<toolkit.ChatMessage> _history;

  OpenAiProvider({
    required OpenAiHandler handler,
    required String modelName,
    String? systemInstruction,
    Iterable<toolkit.ChatMessage>? history,
  })  : _handler = handler,
        _modelName = modelName,
        _systemInstruction = systemInstruction,
        _history = history?.toList() ?? [];

  @override
  Iterable<toolkit.ChatMessage> get history => _history;

  @override
  set history(Iterable<toolkit.ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const [],
  }) {
    return _sendMessageStream(prompt, attachments: attachments, updateHistory: false);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<toolkit.Attachment> attachments = const [],
  }) {
    return _sendMessageStream(prompt, attachments: attachments, updateHistory: true);
  }

  Stream<String> _sendMessageStream(
    String prompt, {
    required Iterable<toolkit.Attachment> attachments,
    required bool updateHistory,
  }) async* {
    final userMessage = toolkit.ChatMessage.user(prompt, attachments);
    final llmMessage = toolkit.ChatMessage.llm();

    if (updateHistory) {
      _history.addAll([userMessage, llmMessage]);
      notifyListeners();
    }

    final messages = <openai.ChatMessage>[];

    if (_systemInstruction != null && _systemInstruction.isNotEmpty) {
      messages.add(
        openai.ChatMessage.system(_systemInstruction),
      );
    }

    // Convert history
    for (final msg in (updateHistory ? _history.take(_history.length - 1) : _history)) {
      if (msg.origin.isUser) {
        messages.add(openai.ChatMessage.user(
          openai.UserMessageContent.text(msg.text ?? ''),
        ));
      } else {
        messages.add(openai.ChatMessage.assistant(
          content: msg.text ?? '',
        ));
      }
    }

    // If updateHistory is false, we manually add the current prompt
    if (!updateHistory) {
      messages.add(openai.ChatMessage.user(
        openai.UserMessageContent.text(prompt),
      ));
    }

    final request = openai.ChatCompletionCreateRequest(
      model: _modelName,
      messages: messages,
    );

    try {
      final responseStream = _handler.executeChatCompletionStream(request);

      await for (final chunk in responseStream) {
        final content = chunk.textDelta;
        if (content != null && content.isNotEmpty) {
          if (updateHistory) {
            llmMessage.append(content);
          }
          yield content;
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
