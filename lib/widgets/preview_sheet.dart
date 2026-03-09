import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PreviewSheet extends StatefulWidget {
  final String code;
  final VoidCallback? onClose;
  final Function(String key, dynamic value)? onSaveData;
  
  static bool skipWebViewForTesting = false;

  const PreviewSheet({
    super.key, 
    required this.code, 
    this.onClose,
    this.onSaveData,
  });

  @override
  State<PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<PreviewSheet> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (!PreviewSheet.skipWebViewForTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent) // Optimization for rendering
        ..addJavaScriptChannel(
          'AppForgeChannel',
          onMessageReceived: (JavaScriptMessage message) {
            try {
              final data = jsonDecode(message.message);
              final action = data['action'];
              if (action == 'saveData') {
                widget.onSaveData?.call(data['key'], data['value']);
              } else if (action == 'closeApp') {
                if (widget.onClose != null) {
                  widget.onClose?.call();
                } else {
                  Navigator.pop(context);
                }
              }
            } catch (e) {
              debugPrint('Error decoding AppForgeChannel message: $e');
            }
          },
        )
        ..loadHtmlString(_buildHtmlShell(widget.code));
    }
  }

  @override
  void didUpdateWidget(PreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
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
    window.AppForge = {
      saveData: (key, val) => { 
        AppForgeChannel.postMessage(JSON.stringify({
          action: 'saveData',
          key: key,
          value: val
        }));
      },
      closeApp: () => {
        AppForgeChannel.postMessage(JSON.stringify({
          action: 'closeApp'
        }));
      }
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(blurRadius: 10, color: Colors.black26, offset: Offset(0, -2)),
            ],
          ),
          child: Column(
            children: [
              // Grab handle for DraggableScrollableSheet
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
                    const Text(
                      'App Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
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
        );
      },
    );
  }
}
