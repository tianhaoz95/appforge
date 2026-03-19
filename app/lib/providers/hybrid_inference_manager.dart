import 'package:flutter/services.dart';

class HybridInferenceSource {
  static const onDevice = 'ON_DEVICE';
  static const inCloud = 'IN_CLOUD';
}

class HybridInferenceResult {
  final String text;
  final String source;
  final int promptTokenCount;
  final int candidateTokenCount;
  final int totalTokenCount;

  HybridInferenceResult({
    required this.text, 
    required this.source,
    this.promptTokenCount = 0,
    this.candidateTokenCount = 0,
    this.totalTokenCount = 0,
  });

  bool get isOnDevice => source == HybridInferenceSource.onDevice;
}

class HybridInferenceManager {
  static const _channel = MethodChannel('com.hejitech.appforge/hybrid_inference');

  static Future<String> checkModelStatus() async {
    return await _channel.invokeMethod('checkModelStatus');
  }

  static Future<String> downloadModel() async {
    return await _channel.invokeMethod('downloadModel');
  }

  static Future<HybridInferenceResult> generateContent({
    required String prompt,
    String modelName = 'gemini-1.5-flash',
  }) async {
    final result = await _channel.invokeMethod('generateHybridContent', {
      'prompt': prompt,
      'modelName': modelName,
    });
    
    final usage = result['usage'] as Map?;
    
    return HybridInferenceResult(
      text: result['text'] as String,
      source: result['source'] as String,
      promptTokenCount: usage?['promptTokenCount'] as int? ?? 0,
      candidateTokenCount: usage?['candidatesTokenCount'] as int? ?? 0,
      totalTokenCount: usage?['totalTokenCount'] as int? ?? 0,
    );
  }
}
