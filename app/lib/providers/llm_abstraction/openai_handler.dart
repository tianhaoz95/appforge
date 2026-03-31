import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:snowglobe_openai/snowglobe_openai.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:path_provider/path_provider.dart';

/// Abstract interface for a function that takes an OpenAI API request 
/// and returns a stream of OpenAI API responses (chunks).
/// We do not assume HTTP calls here.
abstract class OpenAiHandler {
  Stream<CreateChatCompletionStreamResponse> executeChatCompletionStream(CreateChatCompletionRequest request);
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
      apiKey: apiKey,
      baseUrl: endpoint,
    );
  }

  @override
  Stream<CreateChatCompletionStreamResponse> executeChatCompletionStream(CreateChatCompletionRequest request) {
    return _client.createChatCompletionStream(request: request);
  }
}

bool _snowglobeRustInitialized = false;

/// Ensures the Snowglobe Rust bridge is initialized exactly once.
Future<void> ensureSnowglobeInitialized() async {
  if (_snowglobeRustInitialized) return;
  try {
    await SnowglobeOpenAI.initRust();
    _snowglobeRustInitialized = true;
    debugPrint("Snowglobe Rust bridge initialized");
  } catch (e) {
    if (e.toString().contains("initialize flutter_rust_bridge twice")) {
      _snowglobeRustInitialized = true;
    } else {
      debugPrint("Failed to initialize Snowglobe Rust bridge: $e");
      rethrow;
    }
  }
}

/// A local implementation of the OpenAI API handler using the snowglobe_openai package.
class SnowglobeOpenAiHandler implements OpenAiHandler {
  final SettingsProvider? settingsProvider;
  SnowglobeOpenAiHandler({this.settingsProvider});

  Future<void> _ensureEngineInitialized() async {
    await ensureSnowglobeInitialized();

    // Force engine init if provider says it's not initialized
    if (settingsProvider != null && !settingsProvider!.isEngineInitialized) {
      debugPrint("Engine not initialized in handler, attempting init...");
      final appDocDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDocDir.path}/model.gguf');
      if (await modelFile.exists()) {
        final result = await SnowglobeOpenAI.initEngine(
          cacheDir: appDocDir.path,
          config: const InitConfig(
            vocabShards: 1,
            maxGenLen: 2048,
            useExecutorch: false,
            backend: BackendType.llamaCpp,
            speculateTokens: 0,
          ),
        );
        debugPrint("Snowglobe engine init result in handler: $result");
        settingsProvider!.setEngineInitialized(true);
      } else {
        debugPrint("Model file missing in handler: ${modelFile.path}");
      }
    }
  }

  @override
  Stream<CreateChatCompletionStreamResponse> executeChatCompletionStream(
    CreateChatCompletionRequest request,
  ) async* {
    await _ensureEngineInitialized();

    debugPrint("DEBUG: Executing snowglobe chat completion with ${request.messages.length} messages");
    for (var i = 0; i < request.messages.length; i++) {
      final msg = request.messages[i];
      debugPrint("  Msg $i: $msg");
    }

    try {
      final stream = SnowglobeOpenAI.createChatCompletionStream(request);
      await for (final chunk in stream) {
        debugPrint("DEBUG: Raw chunk: $chunk");
        if (chunk.choices.isNotEmpty) {
          final content = chunk.choices.first.delta.content;
          if (content != null) {
            debugPrint("DEBUG: Snowglobe content: $content");
          }
        }
        yield chunk;
      }
    } catch (e) {
      final errorStr = e.toString();
      debugPrint("DEBUG: Snowglobe stream error: $errorStr");
      if (errorStr.contains("Global model not initialized")) {
        debugPrint("Detected uninitialized model in stream, forcing re-init and retrying...");
        // Reset local flag to force re-init
        if (settingsProvider != null) {
          settingsProvider!.setEngineInitialized(false);
        }
        await _ensureEngineInitialized();
        // Retry once
        yield* SnowglobeOpenAI.createChatCompletionStream(request);
      } else {
        rethrow;
      }
    }
  }
}
