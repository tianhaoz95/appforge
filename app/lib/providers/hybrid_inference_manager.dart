import 'package:flutter/services.dart';

class HybridInferenceSource {
  static const onDevice = 'ON_DEVICE';
  static const inCloud = 'IN_CLOUD';
}

class HybridInferenceResult {
  final String text;
  final String source;

  HybridInferenceResult({required this.text, required this.source});

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
    
    return HybridInferenceResult(
      text: result['text'] as String,
      source: result['source'] as String,
    );
  }
}
