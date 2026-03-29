import 'package:flutter/material.dart';

class BrandedErrorView extends StatelessWidget {
  final String title;
  final String message;
  final Widget? illustration;
  final VoidCallback? onRetry;
  final List<Widget>? actions;

  const BrandedErrorView({
    super.key,
    required this.title,
    required this.message,
    this.illustration,
    this.onRetry,
    this.actions,
  });

  factory BrandedErrorView.resting({VoidCallback? onRetry}) {
    return BrandedErrorView(
      title: 'Gemini is resting',
      message: 'Our AI engine is temporarily unavailable (503). This usually happens during high demand. Please try again in a few moments.',
      illustration: const _ErrorIcon(icon: Icons.bedtime_outlined, color: Colors.indigo),
      onRetry: onRetry,
    );
  }

  factory BrandedErrorView.offline({VoidCallback? onRetry}) {
    return BrandedErrorView(
      title: 'Forge Link Interrupted',
      message: 'You appear to be offline. We need an internet connection to reach the AI forge.',
      illustration: const _ErrorIcon(icon: Icons.wifi_off_rounded, color: Colors.blueGrey),
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (illustration != null) ...[
                illustration!,
                const SizedBox(height: 40),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),
              if (onRetry != null)
                SizedBox(
                  width: 220,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ),
              if (actions != null) ...[
                const SizedBox(height: 16),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ErrorIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 80,
        color: color,
      ),
    );
  }
}
