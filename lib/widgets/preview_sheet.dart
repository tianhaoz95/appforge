import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_js/flutter_js.dart';
import 'dart:async';
import '../repositories/micro_app_data_repository.dart';
import '../repositories/micro_app_repository.dart';
import '../providers/settings_provider.dart';

class PreviewSheet extends StatefulWidget {
  final String code;
  final String? backendCode;
  final String? periodicBackendCode;
  final String? designDoc;
  final String? releaseNotes;
  final String appId;
  final VoidCallback? onClose;
  final VoidCallback? onEnhance;
  final Function(List<String> logs, Uint8List screenshot)? onAutoRefine;
  final Function(String text, Uint8List screenshot)? onFeedback;
  final Function(String key, dynamic value)? onSaveData;
  
  static bool skipWebViewForTesting = false;

  const PreviewSheet({
    super.key, 
    required this.code, 
    this.backendCode,
    this.periodicBackendCode,
    this.designDoc,
    this.releaseNotes,
    required this.appId,
    this.onClose,
    this.onEnhance,
    this.onAutoRefine,
    this.onFeedback,
    this.onSaveData,
  });

  @override
  State<PreviewSheet> createState() => PreviewSheetState();
}

class PreviewSheetState extends State<PreviewSheet> with SingleTickerProviderStateMixin {
  WebViewController? _controller;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _currentExtent = 0.9;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final GlobalKey _repaintKey = GlobalKey();
  
  late TabController _tabController;
  JavascriptRuntime? _jsRuntime;
  final List<String> _logs = [];
  String? _lastThemeSignature;

  // Versioning state
  List<Map<String, dynamic>> _versions = [];
  String? _currentVersion;
  String? _activeCode;
  String? _activeBackendCode;
  String? _activePeriodicBackendCode;
  String? _activeDesignDoc;
  String? _activeReleaseNotes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild dropdown when swipe completes
      }
    });
    _activeCode = widget.code;
    _activeBackendCode = widget.backendCode;
    _activePeriodicBackendCode = widget.periodicBackendCode;
    _activeDesignDoc = widget.designDoc;
    _activeReleaseNotes = widget.releaseNotes;
    
    _initJsRuntime();
    _initController();
    _sheetController.addListener(_onSheetChanged);
    _loadVersions();
  }

  void _loadVersions() async {
    if (widget.appId == 'unknown' || widget.appId == 'temp-preview') return;
    try {
      final repository = context.read<MicroAppRepository>();
      final versions = await repository.getAppVersions(widget.appId);
      if (mounted) {
        setState(() {
          _versions = versions;
          if (_versions.isNotEmpty) {
            // Find the version that matches the current code/version
            // For now, assume the one passed in is the latest or matches one of them
            final matching = _versions.firstWhere(
              (v) => v['html_blob'] == widget.code,
              orElse: () => _versions.first,
            );
            _currentVersion = matching['version'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading versions: $e');
    }
  }

  void _switchVersion(String version) {
    final v = _versions.firstWhere((v) => v['version'] == version);
    setState(() {
      _currentVersion = version;
      _activeCode = v['html_blob'];
      _activeBackendCode = v['backend_blob'];
      _activePeriodicBackendCode = v['periodic_backend_blob'];
      _activeDesignDoc = v['design_doc'];
      _activeReleaseNotes = v['release_notes'];
      _logs.clear();
    });
    
    _jsRuntime?.dispose();
    _initJsRuntime();
    _controller?.loadHtmlString(_buildHtmlShell(_activeCode!));
  }

  void _addLog(String source, String message) {
    setState(() {
      _logs.add('[$source] $message');
    });
    debugPrint('[$source] $message');
  }

  void _initJsRuntime() {
    if (_activeBackendCode == null || _activeBackendCode!.trim().isEmpty) return;

    try {
      _jsRuntime = getJavascriptRuntime();
      _addLog('Backend', 'Initializing JS Runtime...');

      // Expose Bridge to Backend JS
      _jsRuntime!.onMessage('MicroForgeBridge', (dynamic args) {
        final data = jsonDecode(args.toString()) as Map<String, dynamic>;
        final action = data['action'];
        final repository = context.read<MicroAppDataRepository>();
        final settings = context.read<SettingsProvider>();

        if (action == 'log') {
          _addLog('Backend Log', data['message'] ?? '');
          return jsonEncode({'success': true});
        } else if (action == 'saveData') {
          if (!settings.allowBackendDatabase) {
            return jsonEncode({'error': 'Database access disabled in settings.'});
          }
          return repository.saveData(widget.appId, data['key'], data['value']).then((_) => jsonEncode({'success': true}));
        } else if (action == 'getData') {
          if (!settings.allowBackendDatabase) {
            return jsonEncode({'error': 'Database access disabled in settings.'});
          }
          return repository.getData(widget.appId, data['key']).then((val) => jsonEncode({'value': val}));
        } else if (action == 'deleteData') {
          if (!settings.allowBackendDatabase) {
            return jsonEncode({'error': 'Database access disabled in settings.'});
          }
          return repository.deleteData(widget.appId, data['key']).then((_) => jsonEncode({'success': true}));
        } else if (action == 'listAll') {
          if (!settings.allowBackendDatabase) {
            return jsonEncode({'error': 'Database access disabled in settings.'});
          }
          return repository.listAll(widget.appId).then((data) => jsonEncode({'data': data}));
        } else if (action == 'showNotification') {
          if (!settings.allowNotifications) {
            return jsonEncode({'error': 'Notification access disabled in settings.'});
          }
          return _showNotification(data['title'], data['body'], data['payload']).then((_) => jsonEncode({'success': true}));
        }
        return jsonEncode({'error': 'Unknown action: $action'});
      });

      // Inject helper for backend JS
      final wrapper = '''
        var window = this;
        var MicroForge = {
          saveData: (key, value) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'saveData', key, value})).then(r => JSON.parse(r)),
          getData: (key) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'getData', key})).then(r => JSON.parse(r).value),
          deleteData: (key) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'deleteData', key})).then(r => JSON.parse(r)),
          listAll: () => sendMessage('MicroForgeBridge', JSON.stringify({action: 'listAll'})).then(r => JSON.parse(r).data),
          showNotification: (title, body, payload) => sendMessage('MicroForgeBridge', JSON.stringify({action: 'showNotification', title, body, payload})).then(r => JSON.parse(r))
        };
        window.MicroForge = MicroForge;
        
        var console = {
          log: (...args) => sendMessage('MicroForgeBridge', JSON.stringify({
            action: 'log', 
            message: args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' ')
          }))
        };
        
        $_activeBackendCode
      ''';

      _jsRuntime!.evaluate(wrapper);
      _addLog('Backend', 'Backend engine ready.');
    } catch (e) {
      _addLog('Backend Error', e.toString());
    }
  }

  Future<void> _showNotification(String? title, String? body, String? payload) async {
    const androidDetails = AndroidNotificationDetails(
      'micro_app_channel',
      'Micro App Notifications',
      channelDescription: 'Notifications from forged micro-apps',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title ?? 'MicroForge',
      body: body ?? '',
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _accelerometerSubscription?.cancel();
    _jsRuntime?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncThemeToWebView();
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
        ..setNavigationDelegate(NavigationDelegate(
          onWebResourceError: (error) {
            _addLog('WebView Error', '${error.description} (${error.errorCode})');
          },
          onPageFinished: (_) {
            _syncThemeToWebView();
          },
        ))
        ..addJavaScriptChannel(
          'MicroForgeChannel',
          onMessageReceived: (JavaScriptMessage message) => handleMessage(message.message),
        )
        ..addJavaScriptChannel(
          'MicroForgeLogger',
          onMessageReceived: (JavaScriptMessage message) {
            _addLog('Frontend', message.message);
          },
        )
        ..loadHtmlString(_buildHtmlShell(_activeCode!));
    }
  }

  Widget _buildAppView() {
    return _controller != null 
        ? RepaintBoundary(
            key: _repaintKey,
            child: WebViewWidget(controller: _controller!),
          )
        : const Center(child: Text('WebView Placeholder'));
  }

  Future<void> handleAutoRefine() async {
    if (widget.onAutoRefine == null) return;
    
    try {
      // Capture screenshot
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final screenshot = byteData!.buffer.asUint8List();
      
      widget.onAutoRefine?.call(List.from(_logs), screenshot);
    } catch (e) {
      debugPrint('Error capturing screenshot for Auto Refine: $e');
    }
  }

  Widget _buildDesignLogView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_activeReleaseNotes != null && _activeReleaseNotes!.isNotEmpty) ...[
            Text(
              'Release Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Text(
                _activeReleaseNotes!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ],
          MarkdownBody(
            data: _activeDesignDoc ?? 'No design documentation provided.',
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyMedium,
              h1: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              h3: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              listBullet: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy Errors'),
                onPressed: _copyErrorLogs,
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Clear Logs'),
                onPressed: () => setState(() => _logs.clear()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _logs.isEmpty 
            ? Center(
                child: Text(
                  'No logs yet.', 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color textColor = Theme.of(context).colorScheme.onSurface;
                  if (log.contains('Error')) textColor = Theme.of(context).colorScheme.error;
                  if (log.contains('Backend')) textColor = Theme.of(context).colorScheme.primary;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: textColor,
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  void _copyErrorLogs() {
    final errorLogs = _logs.where((log) => log.contains('Error')).toList();
    if (errorLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No error logs to copy.')),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: errorLogs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error logs copied to clipboard.')),
    );
  }

  Widget _buildMergedCodeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frontend',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: '```html\n$_activeCode\n```',
            selectable: true,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Backend',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: '```javascript\n${_activeBackendCode ?? '// No backend code provided.'}\n```',
            selectable: true,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Background Periodic',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: '```javascript\n${_activePeriodicBackendCode ?? '// No background periodic code provided.'}\n```',
            selectable: true,
          ),
        ],
      ),
    );
  }

  Future<String> _promptAi(String prompt, {String? systemInstruction}) async {
    final primaryModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      systemInstruction: systemInstruction != null ? Content.system(systemInstruction) : null,
      tools: [
        Tool.urlContext(),
      ],
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
          tools: [
            Tool.urlContext(),
          ],
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
      } else if (action == 'showNotification') {
        final settings = context.read<SettingsProvider>();
        if (!settings.allowNotifications) {
          _sendResponse(requestId, {'error': 'Notifications are disabled in settings.'});
          return;
        }

        await _showNotification(data['title'], data['body'], data['payload']?.toString());
        _sendResponse(requestId, {'success': true});
      } else if (action == 'callBackend') {
        if (_jsRuntime == null) {
          _sendResponse(requestId, {'error': 'Backend engine is not initialized.'});
          return;
        }
        final api = data['api'];
        final payload = data['payload'] ?? {};
        
        final input = jsonEncode({'api': api, 'payload': payload});
        _addLog('Backend Call', 'API: $api');
        
        try {
          final result = _jsRuntime!.evaluate('JSON.stringify(handleRequest($input))');
          _sendResponse(requestId, jsonDecode(result.stringResult));
        } catch (e) {
          _addLog('Backend Call Error', e.toString());
          _sendResponse(requestId, {'status': 'error', 'payload': e.toString()});
        }
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
    if (oldWidget.code != widget.code || oldWidget.appId != widget.appId || 
        oldWidget.backendCode != widget.backendCode || 
        oldWidget.periodicBackendCode != widget.periodicBackendCode) {
      setState(() {
        _activeCode = widget.code;
        _activeBackendCode = widget.backendCode;
        _activePeriodicBackendCode = widget.periodicBackendCode;
        _activeDesignDoc = widget.designDoc;
        _activeReleaseNotes = widget.releaseNotes;
      });
      _jsRuntime?.dispose();
      _initJsRuntime();
      _controller?.loadHtmlString(_buildHtmlShell(_activeCode!));
      _loadVersions();
    }
    _syncThemeToWebView();
  }

  Map<String, dynamic> _buildThemePayload() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.read<SettingsProvider>();
    final brightness = theme.brightness;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    final source = settings.themeMode == ThemeMode.system
        ? 'system'
        : (settings.themeMode == ThemeMode.dark ? 'dark' : 'light');

    return {
      'mode': mode,
      'source': source,
      'colors': {
        'background': _colorToHex(scheme.background),
        'surface': _colorToHex(scheme.surface),
        'text': _colorToHex(scheme.onSurface),
        'muted': _colorToHex(scheme.onSurfaceVariant),
        'primary': _colorToHex(scheme.primary),
        'onPrimary': _colorToHex(scheme.onPrimary),
        'secondary': _colorToHex(scheme.secondary),
        'onSecondary': _colorToHex(scheme.onSecondary),
        'outline': _colorToHex(scheme.outline),
      },
    };
  }

  String _colorToHex(Color color) {
    final value = color.value & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  void _syncThemeToWebView() {
    if (_controller == null) return;
    final payload = _buildThemePayload();
    final signature = jsonEncode(payload);
    if (_lastThemeSignature == signature) return;
    _lastThemeSignature = signature;
    _controller?.runJavaScript(
      'window.MicroForge && window.MicroForge._setTheme && window.MicroForge._setTheme($signature);',
    );
  }

  String _buildHtmlShell(String code) {
    // Optimization: Inline standard libraries if possible or use reliable CDNs
    // Added minimal loading overlay and transition
    final themePayload = jsonEncode(_buildThemePayload());
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script>tailwind.config = { darkMode: 'class' };</script>
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <style>
    :root {
      --mf-bg: #ffffff;
      --mf-surface: #ffffff;
      --mf-text: #111827;
      --mf-muted: #6b7280;
      --mf-primary: #3b82f6;
      --mf-on-primary: #ffffff;
      --mf-secondary: #6366f1;
      --mf-on-secondary: #ffffff;
      --mf-outline: #d1d5db;
    }
    body {
      margin: 0;
      padding: 16px;
      font-family: sans-serif;
      background-color: var(--mf-bg);
      color: var(--mf-text);
      opacity: 0;
      transition: opacity 0.3s ease-in, background-color 0.2s ease, color 0.2s ease;
    }
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
      const themeListeners = new Set();

      function applyTheme(theme) {
        if (!theme || !theme.colors) return;
        const root = document.documentElement;
        root.classList.toggle('dark', theme.mode === 'dark');
        root.style.setProperty('--mf-bg', theme.colors.background);
        root.style.setProperty('--mf-surface', theme.colors.surface);
        root.style.setProperty('--mf-text', theme.colors.text);
        root.style.setProperty('--mf-muted', theme.colors.muted);
        root.style.setProperty('--mf-primary', theme.colors.primary);
        root.style.setProperty('--mf-on-primary', theme.colors.onPrimary);
        root.style.setProperty('--mf-secondary', theme.colors.secondary);
        root.style.setProperty('--mf-on-secondary', theme.colors.onSecondary);
        root.style.setProperty('--mf-outline', theme.colors.outline);
      }
      
      // Override console.log to send logs to Flutter
      const oldLog = console.log;
      console.log = function(...args) {
        MicroForgeLogger.postMessage(args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' '));
        oldLog.apply(console, args);
      };

      window.MicroForge = {
        theme: null,
        getTheme: () => window.MicroForge.theme,
        onThemeChange: (callback) => {
          themeListeners.add(callback);
          return () => themeListeners.delete(callback);
        },
        _setTheme: (theme) => {
          window.MicroForge.theme = theme;
          applyTheme(theme);
          themeListeners.forEach((cb) => {
            try { cb(theme); } catch (_) {}
          });
        },
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
        callBackend: (api, payload) => window.MicroForge._sendRequest('callBackend', { api, payload }),
        ${context.read<SettingsProvider>().allowGeolocation ? "getLocation: () => window.MicroForge._sendRequest('getLocation', {})," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "getAccelerometer: () => window.MicroForge._sendRequest('getAccelerometer', {})," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "watchAccelerometer: (callback) => { window.onAccelerometerUpdate = callback; return window.MicroForge._sendRequest('watchAccelerometer', {}); }," : ""}
        ${context.read<SettingsProvider>().allowAccelerometer ? "stopAccelerometer: () => window.MicroForge._sendRequest('stopAccelerometer', {})," : ""}
        ${context.read<SettingsProvider>().allowNotifications ? "showNotification: (title, body, payload) => window.MicroForge._sendRequest('showNotification', { title, body, payload })," : ""}
        closeApp: () => {
          MicroForgeChannel.postMessage(JSON.stringify({
            action: 'closeApp'
          }));
        }
      };

      const initialTheme = $themePayload;
      window.MicroForge._setTheme(initialTheme);
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
              color: Theme.of(context).colorScheme.surface,
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
              child: Material(
                color: Theme.of(context).colorScheme.surface,
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
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (_versions.length > 1)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _currentVersion,
                                            icon: const Icon(Icons.history, size: 14),
                                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                                            onChanged: (String? newValue) {
                                              if (newValue != null) _switchVersion(newValue);
                                            },
                                            items: _versions.map<DropdownMenuItem<String>>((Map<String, dynamic> v) {
                                              return DropdownMenuItem<String>(
                                                value: v['version'],
                                                child: Text(
                                                  'v${v['version']}',
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      )
                                    else if (_currentVersion != null)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'v$_currentVersion',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _tabController.index,
                                          isDense: true,
                                          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                                          onChanged: (int? newValue) {
                                            if (newValue != null) {
                                              _tabController.animateTo(newValue);
                                            }
                                          },
                                          items: [
                                            DropdownMenuItem(
                                                value: 0,
                                                child: Row(children: [
                                                  const Icon(Icons.apps, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text("App", style: Theme.of(context).textTheme.bodyMedium)
                                                ])),
                                            DropdownMenuItem(
                                                value: 1,
                                                child: Row(children: [
                                                  const Icon(Icons.description_outlined, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text("Design", style: Theme.of(context).textTheme.bodyMedium)
                                                ])),
                                            DropdownMenuItem(
                                                value: 2,
                                                child: Row(children: [
                                                  const Icon(Icons.code_outlined, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text("Code", style: Theme.of(context).textTheme.bodyMedium)
                                                ])),
                                            DropdownMenuItem(
                                                value: 3,
                                                child: Row(children: [
                                                  const Icon(Icons.terminal_outlined, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text("Logs", style: Theme.of(context).textTheme.bodyMedium)
                                                ])),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (widget.onEnhance != null)
                                    IconButton(
                                      icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                                      onPressed: widget.onEnhance,
                                      tooltip: 'Enhance',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  const SizedBox(width: 8),
                                  if (widget.onFeedback != null)
                                    IconButton(
                                      icon: const Icon(Icons.feedback_outlined, size: 18),
                                      onPressed: () {
                                        BetterFeedback.of(context).show((feedback) {
                                          widget.onFeedback?.call(feedback.text, feedback.screenshot);
                                        });
                                      },
                                      tooltip: 'Feedback',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  const SizedBox(width: 8),
                                  if (isFullScreen)
                                    IconButton(
                                      icon: const Icon(Icons.fullscreen_exit, size: 20),
                                      onPressed: _toggleFullScreen,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: widget.onClose ?? () => Navigator.pop(context),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAppView(),
                        _buildDesignLogView(),
                        _buildMergedCodeView(),
                        _buildLogsView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
}
