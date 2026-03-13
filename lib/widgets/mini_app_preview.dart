import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class MiniAppPreview extends StatefulWidget {
  final String code;
  final double height;
  
  static bool skipWebViewForTesting = false;

  const MiniAppPreview({
    super.key,
    required this.code,
    this.height = 300,
  });

  @override
  State<MiniAppPreview> createState() => _MiniAppPreviewState();
}

class _MiniAppPreviewState extends State<MiniAppPreview> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!MiniAppPreview.skipWebViewForTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..loadHtmlString(_buildHtmlShell(widget.code));
    }
  }

  @override
  void didUpdateWidget(MiniAppPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code && _controller != null) {
      _controller!.loadHtmlString(_buildHtmlShell(widget.code));
    }
  }

  String _buildHtmlShell(String code) {
    // Check if context is available (it might not be in some test scenarios)
    SettingsProvider? settings;
    try {
      settings = context.read<SettingsProvider>();
    } catch (_) {
      // Fallback if provider not found
    }
    
    final allowGeo = settings?.allowGeolocation ?? false;
    
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="https://cdn.tailwindcss.com"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
  <style>
    body { margin: 0; padding: 12px; font-family: sans-serif; background-color: white; }
    /* Hide scrollbars for mini preview if preferred, or keep them */
    ::-webkit-scrollbar { width: 4px; }
    ::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 4px; }
  </style>
</head>
<body>
  <div id="forge-target">
    $code
  </div>
  <script>
    // Minimal MicroForge bridge for preview
    window.MicroForge = {
      saveData: () => Promise.resolve({ success: true }),
      getData: () => Promise.resolve(null),
      deleteData: () => Promise.resolve({ success: true }),
      listAll: () => Promise.resolve({}),
      promptAi: () => Promise.resolve("AI features are disabled in preview."),
      pickFiles: () => Promise.resolve([]),
      callBackend: () => Promise.resolve({ status: "error", payload: "Backend is disabled in preview." }),
      ${allowGeo ? "getLocation: () => Promise.reject('Geolocation disabled in preview.')," : ""}
      closeApp: () => {}
    };
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _controller != null 
          ? WebViewWidget(controller: _controller!)
          : const Center(child: Text('WebView Placeholder')),
    );
  }
}
