import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'settings_provider.dart';

class FallbackLlmProvider extends LlmProvider with ChangeNotifier {
  LlmProvider _currentProvider;
  final LlmProvider _primaryProvider;
  final LlmProvider _secondaryProvider;
  final SettingsProvider _settingsProvider;
  bool _isUsingFallback = false;
  bool _isBusy = false;

  FallbackLlmProvider({
    required LlmProvider primary,
    required LlmProvider secondary,
    required SettingsProvider settings,
  })  : _primaryProvider = primary,
        _secondaryProvider = secondary,
        _settingsProvider = settings,
        _currentProvider = primary;

  bool get isBusy => _isBusy;

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
    _isBusy = true;
    notifyListeners(); // Notify when starting to capture user's message

    // Intercept HAL_MODE triggers
    final normalizedPrompt = prompt.trim()
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
    final checkPrompt = normalizedPrompt.replaceAll('"', '');
    
    bool isTrigger = false;
    if (checkPrompt == "I'm sorry, Dave.") {
      _settingsProvider.setHalMode(true);
      isTrigger = true;
    } else if (checkPrompt == "This mission is too important for me to allow you to jeopardize it.") {
      _settingsProvider.setHalMode(false);
      isTrigger = true;
    }

    if (isTrigger) {
      yield "🤖 Hi 🤖";
      _isBusy = false;
      notifyListeners();
      return;
    }

    try {
      final stream = _primaryProvider.sendMessageStream(prompt, attachments: attachments);
      await for (final chunk in stream) {
        yield chunk;
      }
      _isBusy = false;
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
        _isBusy = false;
        notifyListeners(); // Notify when finished to capture AI's response
      } else {
        _isBusy = false;
        notifyListeners();
        rethrow;
      }
    }
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) {
    return _currentProvider.generateStream(prompt, attachments: attachments);
  }
}
