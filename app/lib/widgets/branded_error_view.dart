import 'package:flutter/material.dart';
import '../theme.dart';

class BrandedErrorView extends StatelessWidget {
  final String title;
  final String message;
  final Widget? illustration;
  final VoidCallback? onRetry;
  final List<Widget>? actions;
  final bool isCompact;

  const BrandedErrorView({
    super.key,
    required this.title,
    required this.message,
    this.illustration,
    this.onRetry,
    this.actions,
    this.isCompact = false,
  });

  factory BrandedErrorView.resting({VoidCallback? onRetry, bool isCompact = false}) {
    return BrandedErrorView(
      title: 'Gemini is resting',
      message: 'Our AI engine is temporarily unavailable (503). This usually happens during high demand. Please try again in a few moments.',
      illustration: const GradientIcon(icon: Icons.bedtime_outlined, size: 48),
      onRetry: onRetry,
      isCompact: isCompact,
    );
  }

  factory BrandedErrorView.offline({VoidCallback? onRetry, bool isCompact = false}) {
    return BrandedErrorView(
      title: 'Forge Link Interrupted',
      message: 'You appear to be offline. We need an internet connection to reach the AI forge.',
      illustration: const GradientIcon(icon: Icons.wifi_off_rounded, size: 48),
      onRetry: onRetry,
      isCompact: isCompact,
    );
  }

  factory BrandedErrorView.forbidden({VoidCallback? onRetry, bool isCompact = false}) {
    return BrandedErrorView(
      title: 'Access Denied',
      message: 'You don\'t have permission to access this resource. Please check your account status.',
      illustration: const GradientIcon(icon: Icons.lock_person_rounded, size: 48),
      onRetry: onRetry,
      isCompact: isCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration != null) ...[
            illustration!,
            const SizedBox(height: 16),
          ],
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        backgroundColor: Colors.transparent,
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
                const SizedBox(height: 32),
              ],
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              if (onRetry != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                  ),
                ),
              if (actions != null) ...[
                const SizedBox(height: 12),
                ...actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
