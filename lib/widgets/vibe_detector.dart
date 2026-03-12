import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class VibeDetector extends StatelessWidget {
  final String message;
  final Function(String code, String? name, String? designDoc)? onDeploy;

  const VibeDetector({super.key, required this.message, this.onDeploy});

  @override
  Widget build(BuildContext context) {
    final forgeRegex = RegExp(r'<forge>([\s\S]*?)<\/forge>');
    final nameRegex = RegExp(r'<name>([\s\S]*?)<\/name>');
    final designRegex = RegExp(r'<design>([\s\S]*?)<\/design>');

    final forgeMatch = forgeRegex.firstMatch(message);
    final nameMatch = nameRegex.firstMatch(message);
    final designMatch = designRegex.firstMatch(message);

    if (forgeMatch != null) {
      final forgeCode = forgeMatch.group(1);
      final name = nameMatch?.group(1)?.trim();
      final designDoc = designMatch?.group(1)?.trim();

      String cleanMessage = message.replaceAll(forgeRegex, '');
      cleanMessage = cleanMessage.replaceAll(nameRegex, '');
      cleanMessage = cleanMessage.replaceAll(designRegex, '').trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleanMessage.isNotEmpty) MarkdownBody(data: cleanMessage),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => onDeploy?.call(forgeCode ?? '', name, designDoc),
            icon: const Icon(Icons.rocket_launch),
            label: Text(name != null ? 'Deploy $name' : 'Deploy to App Bar'),
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
