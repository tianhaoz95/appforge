import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'rolling_greeting.dart';

class ChatGreeting extends StatelessWidget {
  final TextStyle? style;

  const ChatGreeting({
    super.key,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final isApple = defaultTargetPlatform == TargetPlatform.iOS || 
                    defaultTargetPlatform == TargetPlatform.macOS;

    if (isApple) {
      return Text(
        "Let's chat!",
        style: style,
      );
    }

    return RollingGreeting(
      style: style,
    );
  }
}
