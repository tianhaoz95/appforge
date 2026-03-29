import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'mini_app_preview.dart';
import 'markdown_utils.dart';
import 'branded_error_view.dart';
import '../theme.dart';

class VibeDetector extends StatefulWidget {
  final String message;
  final Function(String code, String? backendCode, String? periodicBackendCode, String? name, String? designDoc, String? version, String? releaseNotes, String? icon, {bool isTemporary})? onDeploy;
  final Function(String appId)? onOpenApp;
  final Function(String code, String? backendCode, String? periodicBackendCode, String? name, String? designDoc, String? version, String? releaseNotes, String? icon)? onAutoRefine;
  final VoidCallback? onViewContext;
  final VoidCallback? onRetry;

  const VibeDetector({
    super.key,
    required this.message,
    this.onDeploy,
    this.onOpenApp,
    this.onAutoRefine,
    this.onViewContext,
    this.onRetry,
  });

  @override
  State<VibeDetector> createState() => _VibeDetectorState();
}

class _VibeDetectorState extends State<VibeDetector> {
  @override
  void initState() {
    super.initState();
    _checkHaptic();
  }

  @override
  void didUpdateWidget(VibeDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _checkHaptic();
    }
  }

  void _checkHaptic() {
    if (widget.message.contains('<forge>')) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.contains('<error_resting/>')) {
      return BrandedErrorView.resting(
        isCompact: true,
        onRetry: widget.onRetry,
      );
    }
    if (widget.message.contains('<error_offline/>')) {
      return BrandedErrorView.offline(
        isCompact: true,
        onRetry: widget.onRetry,
      );
    }

    if (widget.message.contains('<enhancement_context/>')) {
      final colorScheme = Theme.of(context).colorScheme;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              const Text('App code & design included.', style: TextStyle(fontSize: 13)),
            ],
          ),
          const Text('You can start customizing.', style: TextStyle(fontSize: 13)),
          if (widget.onViewContext != null)
            GestureDetector(
              onTap: widget.onViewContext,
              child: Text('View code & design', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ),
        ],
      );
    }
    final forgeRegex = RegExp(r'<forge>([\s\S]*?)<\/forge>');
    final backendRegex = RegExp(r'<backend>([\s\S]*?)<\/backend>');
    final periodicBackendRegex = RegExp(r'<periodic_backend>([\s\S]*?)<\/periodic_backend>');
    final nameRegex = RegExp(r'<name>([\s\S]*?)<\/name>');
    final iconRegex = RegExp(r'<icon>([\s\S]*?)<\/icon>');
    final designRegex = RegExp(r'<design>([\s\S]*?)<\/design>');
    final versionRegex = RegExp(r'<version>([\s\S]*?)<\/version>');
    final releaseNotesRegex = RegExp(r'<release_notes>([\s\S]*?)<\/release_notes>');
    final suggestAppRegex = RegExp(r'<suggest_app id="([^"]+)">([\s\S]*?)<\/suggest_app>');

    final forgeMatch = forgeRegex.firstMatch(widget.message);
    final backendMatch = backendRegex.firstMatch(widget.message);
    final periodicBackendMatch = periodicBackendRegex.firstMatch(widget.message);
    final nameMatch = nameRegex.firstMatch(widget.message);
    final iconMatch = iconRegex.firstMatch(widget.message);
    final designMatch = designRegex.firstMatch(widget.message);
    final versionMatch = versionRegex.firstMatch(widget.message);
    final releaseNotesMatch = releaseNotesRegex.allMatches(widget.message).lastOrNull;
    final suggestAppMatches = suggestAppRegex.allMatches(widget.message).toList();

    if (forgeMatch != null || suggestAppMatches.isNotEmpty) {
      String cleanMessage = widget.message.replaceAll(forgeRegex, '');
      cleanMessage = cleanMessage.replaceAll(backendRegex, '');
      cleanMessage = cleanMessage.replaceAll(periodicBackendRegex, '');
      cleanMessage = cleanMessage.replaceAll(nameRegex, '');
      cleanMessage = cleanMessage.replaceAll(iconRegex, '');
      cleanMessage = cleanMessage.replaceAll(designRegex, '');
      cleanMessage = cleanMessage.replaceAll(versionRegex, '');
      cleanMessage = cleanMessage.replaceAll(releaseNotesRegex, '');
      cleanMessage = cleanMessage.replaceAll(suggestAppRegex, '');
      cleanMessage = cleanMessage.trim();

      final forgeCode = forgeMatch?.group(1);
      final backendCode = backendMatch?.group(1);
      final periodicBackendCode = periodicBackendMatch?.group(1);
      final name = nameMatch?.group(1)?.trim();
      final icon = iconMatch?.group(1)?.trim();
      final designDoc = designMatch?.group(1)?.trim();
      final version = versionMatch?.group(1)?.trim();
      final releaseNotes = releaseNotesMatch?.group(1)?.trim();

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (forgeMatch != null) ...[
              Row(
                children: [
                  if (icon != null && icon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(icon, style: const TextStyle(fontSize: 20)),
                    )
                  else
                    const GradientIcon(icon: Icons.auto_awesome, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    name != null ? 'Preview: $name' : 'App Preview',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ForgingAnimation(
                child: MiniAppPreview(
                  code: forgeCode ?? '',
                  onFullScreen: () => widget.onDeploy?.call(
                    forgeCode ?? '',
                    backendCode,
                    periodicBackendCode,
                    name,
                    designDoc,
                    version,
                    releaseNotes,
                    icon,
                    isTemporary: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    'Details & Description',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white60
                          : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    if (cleanMessage.isNotEmpty) MarkdownBody(data: cleanMessage),
                    if (designDoc != null) ...[
                      const SizedBox(height: 12),
                      const Text('Design Document:', style: TextStyle(fontWeight: FontWeight.bold)),
                      MarkdownBody(data: designDoc),
                    ],
                    const SizedBox(height: 12),
                    const Text('Source Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                    MarkdownBody(
                      data: '```html\n${forgeCode ?? ''}\n```',
                      selectable: true,
                      builders: {
                        'code': CodeElementBuilder(context),
                      },
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        code: const TextStyle(backgroundColor: Colors.transparent),
                      ),
                    ),
                    if (backendCode != null && backendCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Backend Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                      MarkdownBody(
                        data: '```javascript\n$backendCode\n```',
                        selectable: true,
                        builders: {
                          'code': CodeElementBuilder(context),
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          code: const TextStyle(backgroundColor: Colors.transparent),
                        ),
                      ),
                    ],
                    if (periodicBackendCode != null && periodicBackendCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Background Periodic Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                      MarkdownBody(
                        data: '```javascript\n$periodicBackendCode\n```',
                        selectable: true,
                        builders: {
                          'code': CodeElementBuilder(context),
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          code: const TextStyle(backgroundColor: Colors.transparent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onAutoRefine != null) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onAutoRefine?.call(forgeCode ?? '', backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon),
                        icon: const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Refine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white12 
                              : Colors.black.withValues(alpha: 0.05),
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.vibrantGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onDeploy?.call(forgeCode ?? '', backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon),
                        icon: const Icon(Icons.rocket_launch, size: 18),
                        label: const Text('Deploy'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (cleanMessage.isNotEmpty) ...[
              MarkdownBody(data: cleanMessage),
            ],
            if (suggestAppMatches.isNotEmpty)
              ...suggestAppMatches.map((match) {
                final appId = match.group(1);
                final appName = match.group(2)?.trim();
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onOpenApp?.call(appId ?? ''),
                      icon: const Icon(Icons.open_in_new),
                      label: Text('Open ${appName ?? 'Existing App'}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    }

    return MarkdownBody(data: widget.message);
  }
}

class ForgingAnimation extends StatefulWidget {
  final Widget child;
  const ForgingAnimation({super.key, required this.child});

  @override
  State<ForgingAnimation> createState() => _ForgingAnimationState();
}

class _ForgingAnimationState extends State<ForgingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ForgingPainter(
            animationValue: _controller.value,
            gradient: AppTheme.vibrantGradient,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _ForgingPainter extends CustomPainter {
  final double animationValue;
  final Gradient gradient;

  _ForgingPainter({required this.animationValue, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw multiple pulses
    for (int i = 0; i < 3; i++) {
      final pulseValue = (animationValue + (i * 0.33)) % 1.0;
      final opacity = (1.0 - pulseValue).clamp(0.0, 1.0) * 0.6;
      
      final pulseRect = rect.inflate(pulseValue * 12.0);
      final pulseRRect = RRect.fromRectAndRadius(pulseRect, Radius.circular(16 + (pulseValue * 4.0)));
      
      paint.shader = gradient.createShader(pulseRect);
      paint.color = Colors.white.withValues(alpha: opacity);
      paint.strokeWidth = 1.0 + (pulseValue * 2.0);
      
      canvas.drawRRect(pulseRRect, paint);
    }
  }

  @override
  bool shouldRepaint(_ForgingPainter oldDelegate) => true;
}
