import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class VibeDetector extends StatelessWidget {
  final String message;
  final Function(String code, String? backendCode, String? name, String? designDoc)? onDeploy;
  final Function(String appId)? onOpenApp;

  const VibeDetector({
    super.key,
    required this.message,
    this.onDeploy,
    this.onOpenApp,
  });

  @override
  Widget build(BuildContext context) {
    final forgeRegex = RegExp(r'<forge>([\s\S]*?)<\/forge>');
    final backendRegex = RegExp(r'<backend>([\s\S]*?)<\/backend>');
    final nameRegex = RegExp(r'<name>([\s\S]*?)<\/name>');
    final designRegex = RegExp(r'<design>([\s\S]*?)<\/design>');
    final suggestAppRegex = RegExp(r'<suggest_app id="([^"]+)">([\s\S]*?)<\/suggest_app>');

    final forgeMatch = forgeRegex.firstMatch(message);
    final backendMatch = backendRegex.firstMatch(message);
    final nameMatch = nameRegex.firstMatch(message);
    final designMatch = designRegex.firstMatch(message);
    final suggestAppMatches = suggestAppRegex.allMatches(message).toList();

    if (forgeMatch != null || suggestAppMatches.isNotEmpty) {
      String cleanMessage = message.replaceAll(forgeRegex, '');
      cleanMessage = cleanMessage.replaceAll(backendRegex, '');
      cleanMessage = cleanMessage.replaceAll(nameRegex, '');
      cleanMessage = cleanMessage.replaceAll(designRegex, '');
      cleanMessage = cleanMessage.replaceAll(suggestAppRegex, '');
      cleanMessage = cleanMessage.trim();

      final forgeCode = forgeMatch?.group(1);
      final backendCode = backendMatch?.group(1);
      final name = nameMatch?.group(1)?.trim();
      final designDoc = designMatch?.group(1)?.trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleanMessage.isNotEmpty) MarkdownBody(data: cleanMessage),
          const SizedBox(height: 8),
          if (forgeMatch != null)
            ElevatedButton.icon(
              onPressed: () => onDeploy?.call(forgeCode ?? '', backendCode, name, designDoc),
              icon: const Icon(Icons.rocket_launch),
              label: Text(name != null ? 'Deploy $name' : 'Deploy App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
              ),
            ),
          if (suggestAppMatches.isNotEmpty)
            ...suggestAppMatches.map((match) {
              final appId = match.group(1);
              final appName = match.group(2)?.trim();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ElevatedButton.icon(
                  onPressed: () => onOpenApp?.call(appId ?? ''),
                  icon: const Icon(Icons.open_in_new),
                  label: Text('Open ${appName ?? 'Existing App'}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              );
            }),
        ],
      );
    }

    return MarkdownBody(data: message);
  }
}
