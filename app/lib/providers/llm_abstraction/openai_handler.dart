import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Represents an OpenAI Chat Completion Request
class OpenAiRequest {
  final String model;
  final List<Map<String, dynamic>> messages;
  final bool stream;
  final Map<String, dynamic>? additionalParams;

  OpenAiRequest({
    required this.model,
    required this.messages,
    this.stream = true,
    this.additionalParams,
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': stream,
    };
    if (additionalParams != null) {
      data.addAll(additionalParams!);
    }
    return data;
  }
}

/// Abstract interface for a function that takes an OpenAI API request 
/// and returns a stream of OpenAI API responses (chunks).
/// We do not assume HTTP calls here.
abstract class OpenAiHandler {
  Stream<Map<String, dynamic>> executeChatCompletionStream(OpenAiRequest request);
}

/// A network implementation of the OpenAI API handler using HTTP.
class NetworkOpenAiHandler implements OpenAiHandler {
  final String endpoint;
  final String? apiKey;
  final http.Client _client;

  NetworkOpenAiHandler({
    required this.endpoint,
    this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Stream<Map<String, dynamic>> executeChatCompletionStream(OpenAiRequest request) async* {
    if (endpoint.trim().isEmpty) {
      throw Exception('OpenAI API URL is empty. Please configure it in Settings.');
    }
    final uri = Uri.parse(endpoint);
    final headers = {
      'Content-Type': 'application/json',
    };
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final httpRequest = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(request.toJson());

    final response = await _client.send(httpRequest);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('OpenAI API Error (${response.statusCode}): $errorBody');
    }

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('data: ')) {
        final data = trimmed.substring(6);
        if (data == '[DONE]') {
          break;
        }
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          yield json;
        } catch (e) {
          // Ignore parse errors on partial streams
        }
      }
    }
  }
}
