import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:appforge/widgets/branded_error_view.dart';

@widgetbook.UseCase(
  name: 'Resting (Compact)',
  type: BrandedErrorView,
)
Widget buildBrandedErrorViewRestingCompactUseCase(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BrandedErrorView.resting(
          isCompact: true,
          onRetry: () {},
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Offline (Compact)',
  type: BrandedErrorView,
)
Widget buildBrandedErrorViewOfflineCompactUseCase(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: BrandedErrorView.offline(
          isCompact: true,
          onRetry: () {},
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Forbidden (Full)',
  type: BrandedErrorView,
)
Widget buildBrandedErrorViewForbiddenFullUseCase(BuildContext context) {
  return BrandedErrorView.forbidden(
    onRetry: () {},
  );
}

@widgetbook.UseCase(
  name: 'Custom Error',
  type: BrandedErrorView,
)
Widget buildBrandedErrorViewCustomUseCase(BuildContext context) {
  return BrandedErrorView(
    title: 'Something went wrong',
    message: 'We encountered an unexpected error while forging your app. Our team has been notified.',
    illustration: const Icon(Icons.bug_report, size: 64, color: Colors.red),
    onRetry: () {},
    actions: [
      TextButton(
        onPressed: () {},
        child: const Text('Contact Support'),
      ),
    ],
  );
}
