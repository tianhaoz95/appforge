import 'dart:async';
import 'package:openai_dart/openai_dart.dart';

/// Abstract interface for a function that takes an OpenAI API request 
/// and returns a stream of OpenAI API responses (chunks).
/// We do not assume HTTP calls here.
abstract class OpenAiHandler {
  Stream<ChatStreamEvent> executeChatCompletionStream(ChatCompletionCreateRequest request);
}

/// A network implementation of the OpenAI API handler using the openai_dart client.
class NetworkOpenAiHandler implements OpenAiHandler {
  final String endpoint;
  final String? apiKey;
  late final OpenAIClient _client;

  NetworkOpenAiHandler({
    required this.endpoint,
    this.apiKey,
  }) {
    _client = OpenAIClient(
      config: OpenAIConfig(
        authProvider: apiKey != null && apiKey!.isNotEmpty 
            ? ApiKeyProvider(apiKey!) 
            : null,
        baseUrl: endpoint,
      ),
    );
  }

  @override
  Stream<ChatStreamEvent> executeChatCompletionStream(ChatCompletionCreateRequest request) {
    return _client.chat.completions.createStream(request);
  }
}
