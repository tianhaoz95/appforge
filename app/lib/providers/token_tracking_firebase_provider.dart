// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// A provider class for interacting with Firebase Vertex AI's language model with token tracking.
class TokenTrackingFirebaseProvider extends LlmProvider with ChangeNotifier {
  TokenTrackingFirebaseProvider({
    required GenerativeModel model,
    void Function(Iterable<FunctionCall>)? onFunctionCalls,
    Iterable<ChatMessage>? history,
    List<SafetySetting>? chatSafetySettings,
    GenerationConfig? chatGenerationConfig,
    Future<Map<String, Object?>?> Function(FunctionCall)? onFunctionCall,
    this.onUsageMetadata,
  }) : _model = model,
       _history = history?.toList() ?? [],
       _chatSafetySettings = chatSafetySettings,
       _chatGenerationConfig = chatGenerationConfig,
       _onFunctionCall = onFunctionCall {
    _chat = _startChat(history);
  }

  final GenerativeModel _model;
  final List<SafetySetting>? _chatSafetySettings;
  final GenerationConfig? _chatGenerationConfig;
  final List<ChatMessage> _history;
  final Future<Map<String, Object?>?> Function(FunctionCall)? _onFunctionCall;
  final void Function(UsageMetadata)? onUsageMetadata;
  ChatSession? _chat;

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) => _sendMessageStream(
    prompt: prompt,
    attachments: attachments,
    chat: _startChat(null)!,
  );

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    final response = _sendMessageStream(
      prompt: prompt,
      attachments: attachments,
      chat: _chat!,
    );

    yield* response.map((chunk) {
      llmMessage.append(chunk);
      return chunk;
    });

    notifyListeners();
  }

  Stream<String> _sendMessageStream({
    required String prompt,
    required Iterable<Attachment> attachments,
    required ChatSession chat,
  }) async* {
    final content = Content('user', [
      TextPart(prompt),
      ...attachments.map(_partFrom),
    ]);

    var responseStream = chat.sendMessageStream(content);

    while (true) {
      final functionCalls = <FunctionCall>[];
      UsageMetadata? lastMetadata;

      await for (final chunk in responseStream) {
        if (chunk.usageMetadata != null) {
          lastMetadata = chunk.usageMetadata;
        }
        if (chunk.text != null) {
          yield chunk.text!;
        }
        if (chunk.functionCalls.isNotEmpty) {
          functionCalls.addAll(chunk.functionCalls);
        }
      }

      if (lastMetadata != null) {
        onUsageMetadata?.call(lastMetadata);
      }

      if (functionCalls.isEmpty) {
        break;
      }

      yield '\n';

      final functionResponses = <FunctionResponse>[];
      for (final functionCall in functionCalls) {
        try {
          functionResponses.add(
            FunctionResponse(
              functionCall.name,
              await _onFunctionCall?.call(functionCall) ?? {},
            ),
          );
        } catch (ex) {
          functionResponses.add(
            FunctionResponse(functionCall.name, {'error': ex.toString()}),
          );
        }
      }

      responseStream = chat.sendMessageStream(
        Content.functionResponses(functionResponses),
      );
    }
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    _chat = _startChat(history);
    notifyListeners();
  }

  ChatSession? _startChat(Iterable<ChatMessage>? history) => _model.startChat(
    history: history?.map(_contentFrom).toList(),
    safetySettings: _chatSafetySettings,
    generationConfig: _chatGenerationConfig,
  );

  static Part _partFrom(Attachment attachment) => switch (attachment) {
    (final FileAttachment a) => InlineDataPart(a.mimeType, a.bytes),
    (final LinkAttachment a) => TextPart(a.url.toString()),
  };

  static Content _contentFrom(ChatMessage message) => Content(
    message.origin.isUser ? 'user' : 'model',
    [TextPart(message.text ?? ''), ...message.attachments.map(_partFrom)],
  );
}
