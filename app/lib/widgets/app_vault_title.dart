import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppVaultTitle extends StatelessWidget {
  final TextStyle? style;

  const AppVaultTitle({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    String title;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        title = 'Saved Scripts';
        break;
      default:
        title = 'Forged Utils';
        break;
    }

    return Text(
      title,
      style: style ?? const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}
