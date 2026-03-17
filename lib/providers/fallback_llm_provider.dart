import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

enum ForgeMode { plan, build }

class FallbackLlmProvider extends LlmProvider with ChangeNotifier {
  LlmProvider _currentProvider;
  final LlmProvider _primaryProvider;
  final LlmProvider _secondaryProvider;
  bool _isUsingFallback = false;
  bool _isBusy = false;
  ForgeMode _currentMode = ForgeMode.build;
  ForgeMode? _lastModeSent;

  FallbackLlmProvider({
    required LlmProvider primary,
    required LlmProvider secondary,
  })  : _primaryProvider = primary,
        _secondaryProvider = secondary,
        _currentProvider = primary;

  bool get isBusy => _isBusy;
  ForgeMode get currentMode => _currentMode;

  void setMode(ForgeMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      notifyListeners();
    }
  }

  @override
  List<ChatMessage> get history => _currentProvider.history.toList();

  @override
  set history(Iterable<ChatMessage> history) {
    _primaryProvider.history = history;
    _secondaryProvider.history = history;
    if (history.isEmpty) {
      _lastModeSent = null;
    }
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    _isBusy = true;
    notifyListeners(); // Notify when starting to capture user's message

    String modifiedPrompt = prompt;
    if (_currentMode != _lastModeSent) {
      final instruction = _currentMode == ForgeMode.plan
          ? '\n\n[MODE: PLAN] Iteratively work with me to refine the design. Ask for my permission to build when the design is mature enough. Do not provide <forge> tags yet.'
          : '\n\n[MODE: BUILD] Immediately start building the micro-app with <forge> tags.';
      modifiedPrompt = '$prompt$instruction';
      _lastModeSent = _currentMode;
    }

    try {
      final stream = _primaryProvider.sendMessageStream(modifiedPrompt, attachments: attachments);
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
        
        final stream = _secondaryProvider.sendMessageStream(modifiedPrompt, attachments: attachments);
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
