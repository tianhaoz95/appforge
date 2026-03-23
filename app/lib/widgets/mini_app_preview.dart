import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class MiniAppPreview extends StatefulWidget {
  final String code;
  final double height;
  final VoidCallback? onFullScreen;
  
  static bool skipWebViewForTesting = false;

  const MiniAppPreview({
    super.key,
    required this.code,
    this.height = 400,
    this.onFullScreen,
  });

  @override
  State<MiniAppPreview> createState() => _MiniAppPreviewState();
}

class _MiniAppPreviewState extends State<MiniAppPreview> {
  WebViewController? _controller;
  String? _lastThemeSignature;

  @override
  void initState() {
    super.initState();
    if (!MiniAppPreview.skipWebViewForTesting) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent);
    }
  }

  @override
  void didUpdateWidget(MiniAppPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code && _controller != null) {
      _controller!.loadHtmlString(_buildHtmlShell(widget.code));
    }
    _syncThemeToWebView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null && _lastThemeSignature == null) {
      _controller!.loadHtmlString(_buildHtmlShell(widget.code));
    }
    _syncThemeToWebView();
  }

  Map<String, dynamic> _buildThemePayload(SettingsProvider? settings) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    final source = settings == null
        ? 'system'
        : (settings.themeMode == ThemeMode.system
            ? 'system'
            : (settings.themeMode == ThemeMode.dark ? 'dark' : 'light'));

    return {
      'mode': mode,
      'source': source,
      'colors': {
        'background': _colorToHex(scheme.surface),
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
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  void _syncThemeToWebView() {
    if (_controller == null) return;
    SettingsProvider? settings;
    try {
      settings = context.read<SettingsProvider>();
    } catch (_) {}
    final payload = _buildThemePayload(settings);
    final signature = jsonEncode(payload);
    if (_lastThemeSignature == signature) return;
    _lastThemeSignature = signature;
    _controller?.runJavaScript(
      'window.MicroForge && window.MicroForge._setTheme && window.MicroForge._setTheme($signature);',
    );
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
    final themePayload = _buildThemePayload(settings);
    
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
      padding: 0;
      font-family: sans-serif;
      background-color: var(--mf-bg);
      color: var(--mf-text);
      transition: background-color 0.2s ease, color 0.2s ease;
      zoom: 0.6;
    }
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

    // Minimal MicroForge bridge for preview
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

    window.MicroForge._setTheme(${jsonEncode(themePayload)});
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _controller != null 
              ? WebViewWidget(controller: _controller!)
              : const Center(child: Text('WebView Placeholder')),
          if (widget.onFullScreen != null)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  onPressed: widget.onFullScreen,
                  tooltip: 'Full Screen',
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
