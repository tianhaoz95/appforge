import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'dart:io';
import 'dart:async';
import 'settings_provider.dart';

class FallbackLlmProvider extends LlmProvider with ChangeNotifier {
  LlmProvider _currentProvider;
  final LlmProvider _primaryProvider;
  final LlmProvider _secondaryProvider;
  final SettingsProvider _settingsProvider;
  bool _isUsingFallback = false;
  bool _isBusy = false;
  
  // Static key to allow global navigation to error screens (kept for legacy if needed)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    notifyListeners();

    // 1. Instant Offline Check
    if (await _isOffline()) {
      _isBusy = false;
      notifyListeners();
      yield '<error_offline/>';
      return;
    }

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
      const responseText = "🤖 Hi 🤖";
      final userMessage = ChatMessage(
        origin: MessageOrigin.user,
        text: prompt,
        attachments: attachments.toList(),
      );
      final llmMessage = ChatMessage(
        origin: MessageOrigin.llm,
        text: responseText,
        attachments: const [],
      );
      
      final currentHistory = history;
      history = [...currentHistory, userMessage, llmMessage];

      yield responseText;
      _isBusy = false;
      notifyListeners();
      return;
    }

    try {
      // 2. Wrap the stream listener with a timeout to prevent "stuck" UI
      final stream = _primaryProvider.sendMessageStream(prompt, attachments: attachments)
          .timeout(const Duration(seconds: 15), onTimeout: (sink) {
            sink.add('Error: Connection timed out');
          });

      bool receivedChunk = false;
      await for (final chunk in stream) {
        receivedChunk = true;
        if (chunk.startsWith('Error:')) {
          final errorStr = chunk.toLowerCase();
          if (errorStr.contains('high demand') || errorStr.contains('503') || errorStr.contains('overloaded')) {
            yield '<error_resting/>';
          } else if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('socketexception') || errorStr.contains('timeout')) {
            yield '<error_offline/>';
          } else {
            if (await _isOffline()) {
              yield '<error_offline/>';
            } else {
              yield chunk;
            }
          }
          _isBusy = false;
          notifyListeners();
          return;
        }
        yield chunk;
      }
      
      if (!receivedChunk && !await _isOffline()) {
         // Some generic empty response or subtle error
      } else if (!receivedChunk) {
         yield '<error_offline/>';
      }

      _isBusy = false;
      notifyListeners();
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // Handle 503 / High Demand with Fallback
      if ((errorStr.contains('high demand') || errorStr.contains('503') || errorStr.contains('overloaded')) && !_isUsingFallback) {
        debugPrint('Primary model busy, falling back to secondary...');
        _isUsingFallback = true;
        _currentProvider = _secondaryProvider;
        _secondaryProvider.history = _primaryProvider.history;
        
        try {
          final stream = _secondaryProvider.sendMessageStream(prompt, attachments: attachments)
              .timeout(const Duration(seconds: 15));
          await for (final chunk in stream) {
            if (chunk.startsWith('Error:')) {
               final err2 = chunk.toLowerCase();
               if (err2.contains('503') || err2.contains('overloaded') || err2.contains('high demand')) {
                  yield '<error_resting/>';
               } else {
                  if (await _isOffline()) {
                    yield '<error_offline/>';
                  } else {
                    yield chunk;
                  }
               }
               _isBusy = false;
               notifyListeners();
               return;
            }
            yield chunk;
          }
        } catch (e2) {
          _isBusy = false;
          notifyListeners();
          
          final err2 = e2.toString().toLowerCase();
          if (err2.contains('503') || err2.contains('overloaded') || err2.contains('high demand')) {
             yield '<error_resting/>';
          } else {
             if (await _isOffline()) {
               yield '<error_offline/>';
             } else {
               yield 'Error: ${e2.toString()}';
             }
          }
        }
        _isBusy = false;
        notifyListeners();
      } 
      // All other errors
      else {
        _isBusy = false;
        notifyListeners();
        if (await _isOffline() || errorStr.contains('socketexception') || errorStr.contains('connection')) {
          yield '<error_offline/>';
        } else {
          yield 'Error: ${e.toString()}';
        }
      }
    }
  }

  Future<bool> _isOffline() async {
    try {
      // Use a very short timeout for connectivity check to keep UI snappy
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(milliseconds: 1500));
      return result.isEmpty || result[0].rawAddress.isEmpty;
    } catch (_) {
      return true;
    }
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) {
    return _currentProvider.generateStream(prompt, attachments: attachments);
  }
}
