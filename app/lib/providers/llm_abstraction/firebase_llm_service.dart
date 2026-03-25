import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:firebase_ai/firebase_ai.dart';
import '../token_tracking_firebase_provider.dart';
import 'llm_service.dart';

class FirebaseLlmService implements LlmService {
  final String modelName;
  final void Function(UsageMetadata)? onUsageMetadata;

  FirebaseLlmService({
    required this.modelName,
    this.onUsageMetadata,
  });

  @override
  LlmProvider createProvider({
    String? systemInstruction,
    Iterable<ChatMessage>? history,
  }) {
    final model = FirebaseAI.googleAI().generativeModel(
      model: modelName,
      systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
      tools: [
        Tool.urlContext(),
      ],
    );

    return TokenTrackingFirebaseProvider(
      model: model,
      history: history,
      onUsageMetadata: onUsageMetadata,
    );
  }
}
