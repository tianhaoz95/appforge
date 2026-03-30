import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'rolling_greeting.dart';
import '../theme.dart';

class ChatGreeting extends StatelessWidget {
  final TextStyle? style;
  final bool useGradient;

  const ChatGreeting({
    super.key,
    this.style,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS || 
                    defaultTargetPlatform == TargetPlatform.macOS;

    if (isApple) {
      if (useGradient) {
        return GradientText(
          "Let's chat!",
          style: style,
        );
      }
      return Text(
        "Let's chat!",
        style: style,
      );
    }

    return RollingGreeting(
      style: style,
      useGradient: useGradient,
    );
  }
}
