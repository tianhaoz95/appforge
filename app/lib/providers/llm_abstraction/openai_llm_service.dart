import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'llm_service.dart';
import 'openai_handler.dart';
import 'openai_provider.dart';

class OpenAiLlmService implements LlmService {
  final OpenAiHandler handler;
  final String modelName;

  OpenAiLlmService({
    required this.handler,
    required this.modelName,
  });

  @override
  LlmProvider createProvider({
    String? systemInstruction,
    Iterable<ChatMessage>? history,
  }) {
    return OpenAiProvider(
      handler: handler,
      modelName: modelName,
      systemInstruction: systemInstruction,
      history: history,
    );
  }
}
