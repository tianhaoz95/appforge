import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

/// Abstract interface for configuring and creating LLM services
abstract class LlmService {
  /// Returns an LlmProvider that can be used directly with flutter_ai_toolkit's LlmChatView
  LlmProvider createProvider({
    String? systemInstruction,
    Iterable<ChatMessage>? history,
  });
}
