import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../repositories/micro_app_data_repository.dart';
import '../providers/settings_provider.dart';

class PreviewSheet extends StatefulWidget {
  final String code;
  final String? designDoc;
  final String appId;
  final VoidCallback? onClose;
  final VoidCallback? onEnhance;
  final Function(String text, Uint8List screenshot)? onFeedback;
  final Function(String key, dynamic value)? onSaveData;
  
  static bool skipWebViewForTesting = false;

  const PreviewSheet({
    super.key, 
    required this.code, 
    this.designDoc,
    required this.appId,
    this.onClose,
    this.onEnhance,
    this.onFeedback,
    this.onSaveData,
  });

  @override
  State<PreviewSheet> createState() => PreviewSheetState();
}

class PreviewSheetState extends State<PreviewSheet> {
  WebViewController? _controller;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _currentExtent = 0.9;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _initController();
    _sheetController.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  void _onSheetChanged() {
    if (_sheetController.isAttached) {
      setState(() {
        _currentExtent = _sheetController.size;
      });
    }
  }

  void _toggleFullScreen() {
    if (_sheetController.isAttached) {
      // Toggle between full screen (1.0) and normal height (0.9)
      final targetSize = _currentExtent > 0.95 ? 0.9 : 1.0;
      _sheetController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _initController() {
    if (!PreviewSheet.skipWebViewForTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent) // Optimization for rendering
        ..addJavaScriptChannel(
          'MicroForgeChannel',
          onMessageReceived: (JavaScriptMessage message) => handleMessage(message.message),
        )
        ..loadHtmlString(_buildHtmlShell(widget.code));
    }
  }

  void _showDesignDoc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Design Document',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: widget.designDoc ?? 'No design documentation provided.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _promptAi(String prompt, {String? systemInstruction}) async {
    final primaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
    );

    try {
      final response = await primaryModel.generateContent([Content.text(prompt)]);
      return response.text ?? 'No response';
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if ((errorStr.contains('high demand') || errorStr.contains('503') || errorStr.contains('overloaded'))) {
        debugPrint('Micro-app AI fallback triggered...');
        final secondaryModel = FirebaseAI.googleAI().generativeModel(
          model: 'gemini-2.0-flash',
          systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
        );
        final response = await secondaryModel.generateContent([Content.text(prompt)]);
        return response.text ?? 'No response';
      }
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> handleMessage(String message) async {
    try {
      final data = jsonDecode(message);
      final action = data['action'];
      final requestId = data['requestId'];
      final repository = context.read<MicroAppDataRepository>();

      if (action == 'saveData') {
        final key = data['key'];
        final value = data['value'];
        await repository.saveData(widget.appId, key, value);
        _sendResponse(requestId, {'success': true});
        widget.onSaveData?.call(key, value);
      } else if (action == 'getData') {
        final key = data['key'];
        final value = await repository.getData(widget.appId, key);
        _sendResponse(requestId, {'value': value});
      } else if (action == 'deleteData') {
        final key = data['key'];
        await repository.deleteData(widget.appId, key);
        _sendResponse(requestId, {'success': true});
      } else if (action == 'listAll') {
        final allData = await repository.listAll(widget.appId);
        _sendResponse(requestId, {'data': allData});
      } else if (action == 'promptAi') {
        final prompt = data['prompt'];
        final systemInstruction = data['systemInstruction'];
        final response = await _promptAi(prompt, systemInstruction: systemInstruction);
        _sendResponse(requestId, {'text': response});
      } else if (action == 'pickFiles') {
        final multiple = data['multiple'] ?? false;
        final typeStr = data['type'] ?? 'any';
        final extensions = (data['extensions'] as List?)?.map((e) => e.toString()).toList();
        
        FileType type = FileType.any;
        if (typeStr == 'image') type = FileType.image;
        if (typeStr == 'video') type = FileType.video;
        if (typeStr == 'audio') type = FileType.audio;
        if (typeStr == 'media') type = FileType.media;
        if (typeStr == 'custom') type = FileType.custom;

        final result = await FilePicker.platform.pickFiles(
          allowMultiple: multiple,
          type: type,
          allowedExtensions: type == FileType.custom ? extensions : null,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final files = result.files.map((file) => {
            'name': file.name,
            'size': file.size,
            'extension': file.extension,
            'bytes': file.bytes != null ? base64Encode(file.bytes!) : null,
          }).toList();
          _sendResponse(requestId, {'files': files});
        } else {
          _sendResponse(requestId, {'files': []});
        }
      } else if (action == 'getLocation') {
        final settings = context.read<SettingsProvider>();
        if (!settings.allowGeolocation) {
          _sendResponse(requestId, {'error': 'Geolocation is disabled in settings.'});
          return;
        }

        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _sendResponse(requestId, {'error': 'Location services are disabled.'});
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _sendResponse(requestId, {'error': 'Location permissions are denied.'});
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _sendResponse(requestId, {'error': 'Location permissions are permanently denied, we cannot request permissions.'});
          return;
        }

        Position position = await Geolocator.getCurrentPosition();
        _sendResponse(requestId, {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'altitude': position.altitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'timestamp': position.timestamp.toIso8601String(),
        });
      } else if (action == 'getAccelerometer') {
        final settings = context.read<SettingsProvider>();
        if (!settings.allowAccelerometer) {
          _sendResponse(requestId, {'error': 'Accelerometer is disabled in settings.'});
          return;
        }
        late StreamSubscription<AccelerometerEvent> sub;
        sub = accelerometerEventStream().listen((event) {
          _sendResponse(requestId, {
            'x': event.x,
            'y': event.y,
            'z': event.z,
          });
          sub.cancel();
        });
      } else if (action == 'watchAccelerometer') {
        final settings = context.read<SettingsProvider>();
        if (!settings.allowAccelerometer) {
          _sendResponse(requestId, {'error': 'Accelerometer is disabled in settings.'});
          return;
        }
        _accelerometerSubscription?.cancel();
        _accelerometerSubscription = accelerometerEventStream().listen((event) {
          final data = jsonEncode({'x': event.x, 'y': event.y, 'z': event.z});
          _controller?.runJavaScript('if(window.onAccelerometerUpdate) window.onAccelerometerUpdate($data)');
        });
        _sendResponse(requestId, {'success': true});
      } else if (action == 'stopAccelerometer') {
        _accelerometerSubscription?.cancel();
        _accelerometerSubscription = null;
        _sendResponse(requestId, {'success': true});
      } else if (action == 'closeApp') {
        if (widget.onClose != null) {
          widget.onClose?.call();
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error decoding MicroForgeChannel message: $e');
      if (e is! FormatException) {
        // If it's not a JSON error, it might be an AI error, send it back if requestId exists
        final data = jsonDecode(message);
        final requestId = data['requestId'];
        if (requestId != null) {
          _sendResponse(requestId, {'error': e.toString()});
        }
      }
    }
  }

  void _sendResponse(String? requestId, Map<String, dynamic> response) {
    if (requestId != null) {
      final jsonResponse = jsonEncode(response);
      _controller?.runJavaScript('window.MicroForge._handleResponse("$requestId", $jsonResponse)');
    }
  }

  @override
  void didUpdateWidget(PreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code || oldWidget.appId != widget.appId) {
      _controller?.loadHtmlString(_buildHtmlShell(widget.code));
    }
  }

  String _buildHtmlShell(String code) {
    // Optimization: Inline standard libraries if possible or use reliable CDNs
    // Added minimal loading overlay and transition
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <style>
    body { margin: 0; padding: 16px; font-family: sans-serif; background-color: white; opacity: 0; transition: opacity 0.3s ease-in; }
    body.ready { opacity: 1; }
  </style>
</head>
<body onload="document.body.className='ready'">
  <div id="forge-target">
    $code
  </div>
  <script>
    (function() {
      const pendingRequests = new Map();
      
      window.MicroForge = {
        _handleResponse: (requestId, response) => {
          if (pendingRequests.has(requestId)) {
            pendingRequests.get(requestId)(response);
            pendingRequests.delete(requestId);
          }
        },
        _sendRequest: (action, params) => {
          const requestId = Math.random().toString(36).substring(2, 11);
          return new Promise((resolve, reject) => {
            pendingRequests.set(requestId, (response) => {
              if (response.error) {
                reject(new Error(response.error));
              } else {
                resolve(response);
              }
            });
            MicroForgeChannel.postMessage(JSON.stringify({
              action,
              requestId,
              ...params
            }));
          });
        },
        saveData: (key, val) => window.MicroForge._sendRequest('saveData', { key, value: val }),
        getData: (key) => window.MicroForge._sendRequest('getData', { key }).then(r => r.value),
        deleteData: (key) => window.MicroForge._sendRequest('deleteData', { key }),
        listAll: () => window.MicroForge._sendRequest('listAll', {}).then(r => r.data),
        promptAi: (prompt, systemInstruction) => window.MicroForge._sendRequest('promptAi', { prompt, systemInstruction }).then(r => r.text),
        pickFiles: (options = {}) => window.MicroForge._sendRequest('pickFiles', options).then(r => r.files),
        ${context.read<SettingsProvider>().allowGeolocation ? "getLocation: () => window.MicroForge._sendRequest('getLocation', {})," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "getAccelerometer: () => window.MicroForge._sendRequest('getAccelerometer', {})," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "watchAccelerometer: (callback) => { window.onAccelerometerUpdate = callback; return window.MicroForge._sendRequest('watchAccelerometer', {}); }," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "stopAccelerometer: () => window.MicroForge._sendRequest('stopAccelerometer', {})," : ""}
        closeApp: () => {
          MicroForgeChannel.postMessage(JSON.stringify({
            action: 'closeApp'
          }));
        }
      };
    })();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.05) {
          widget.onClose?.call();
          return true;
        }
        return false;
      },
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.9,
        minChildSize: 0.0,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.0, 0.9, 1.0],
        builder: (context, scrollController) {
          final isFullScreen = _currentExtent > 0.95;
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isFullScreen 
                  ? null 
                  : const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(blurRadius: 10, color: Colors.black26, offset: const Offset(0, -2)),
              ],
            ),
            child: SafeArea(
              top: isFullScreen,
              bottom: false,
              child: Column(
                children: [
                  // Top handle and header are wrapped in SingleChildScrollView to make them draggable
                  SingleChildScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Grab handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox.shrink(),
                              Row(
                                children: [
                                  if (widget.onEnhance != null)
                                    TextButton.icon(
                                      icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                                      label: const Text('Enhance', style: TextStyle(color: Colors.indigo)),
                                      onPressed: widget.onEnhance,
                                    ),
                                  if (widget.onFeedback != null)
                                    TextButton.icon(
                                      icon: const Icon(Icons.feedback_outlined, size: 18),
                                      label: const Text('Feedback'),
                                      onPressed: () {
                                        BetterFeedback.of(context).show((feedback) {
                                          widget.onFeedback?.call(feedback.text, feedback.screenshot);
                                        });
                                      },
                                    ),
                                  if (widget.designDoc != null && widget.designDoc!.isNotEmpty)
                                    TextButton.icon(
                                      icon: const Icon(Icons.description_outlined, size: 18),
                                      label: const Text('Design'),
                                      onPressed: () => _showDesignDoc(context),
                                    ),
                                  if (isFullScreen)
                                    IconButton(
                                      icon: const Icon(Icons.fullscreen_exit),
                                      iconSize: 20,
                                      onPressed: _toggleFullScreen,
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    iconSize: 20,
                                    onPressed: widget.onClose ?? () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _controller != null 
                        ? WebViewWidget(controller: _controller!)
                        : const Center(child: Text('WebView Placeholder')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
