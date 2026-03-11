import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

class FallbackLlmProvider extends LlmProvider with ChangeNotifier {
  LlmProvider _currentProvider;
  final LlmProvider _primaryProvider;
  final LlmProvider _secondaryProvider;
  bool _isUsingFallback = false;

  FallbackLlmProvider({
    required LlmProvider primary,
    required LlmProvider secondary,
  })  : _primaryProvider = primary,
        _secondaryProvider = secondary,
        _currentProvider = primary;

  @override
  List<ChatMessage> get history => _currentProvider.history.toList();

  @override
  set history(Iterable<ChatMessage> history) {
    _primaryProvider.history = history;
    _secondaryProvider.history = history;
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    notifyListeners(); // Notify when starting to capture user's message
    try {
      final stream = _primaryProvider.sendMessageStream(prompt, attachments: attachments);
      await for (final chunk in stream) {
        yield chunk;
      }
      notifyListeners(); // Notify when finished to capture AI's response
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if ((errorStr.contains('high demand') || errorStr.contains('503') || errorStr.contains('overloaded')) && !_isUsingFallback) {
        debugPrint('Primary model busy, falling back to secondary...');
        _isUsingFallback = true;
        _currentProvider = _secondaryProvider;
        _secondaryProvider.history = _primaryProvider.history;
        
        final stream = _secondaryProvider.sendMessageStream(prompt, attachments: attachments);
        await for (final chunk in stream) {
          yield chunk;
        }
        notifyListeners(); // Notify when finished to capture AI's response
      } else {
        rethrow;
      }
    }
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) {
    return _currentProvider.generateStream(prompt, attachments: attachments);
  }
}
