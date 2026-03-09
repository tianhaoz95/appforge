import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class VibeDetector extends StatelessWidget {
  final String message;
  final Function(String code)? onDeploy;

  const VibeDetector({super.key, required this.message, this.onDeploy});

  @override
  Widget build(BuildContext context) {
    final forgeRegex = RegExp(r'<forge>([\s\S]*?)<\/forge>');
    final match = forgeRegex.firstMatch(message);

    if (match != null) {
      final forgeCode = match.group(1);
      final cleanMessage = message.replaceAll(forgeRegex, '').trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleanMessage.isNotEmpty) MarkdownBody(data: cleanMessage),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => onDeploy?.call(forgeCode ?? ''),
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Deploy to App Bar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      );
    }

    return MarkdownBody(data: message);
  }
}
