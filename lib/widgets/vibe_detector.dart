import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'mini_app_preview.dart';

class VibeDetector extends StatelessWidget {
  final String message;
  final Function(String code, String? backendCode, String? name, String? designDoc, String? version, String? releaseNotes)? onDeploy;
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
    final versionRegex = RegExp(r'<version>([\s\S]*?)<\/version>');
    final releaseNotesRegex = RegExp(r'<release_notes>([\s\S]*?)<\/release_notes>');
    final suggestAppRegex = RegExp(r'<suggest_app id="([^"]+)">([\s\S]*?)<\/suggest_app>');

    final forgeMatch = forgeRegex.firstMatch(message);
    final backendMatch = backendRegex.firstMatch(message);
    final nameMatch = nameRegex.firstMatch(message);
    final designMatch = designRegex.firstMatch(message);
    final versionMatch = versionRegex.firstMatch(message);
    final releaseNotesMatch = releaseNotesRegex.allMatches(message).lastOrNull;
    final suggestAppMatches = suggestAppRegex.allMatches(message).toList();

    if (forgeMatch != null || suggestAppMatches.isNotEmpty) {
      String cleanMessage = message.replaceAll(forgeRegex, '');
      cleanMessage = cleanMessage.replaceAll(backendRegex, '');
      cleanMessage = cleanMessage.replaceAll(nameRegex, '');
      cleanMessage = cleanMessage.replaceAll(designRegex, '');
      cleanMessage = cleanMessage.replaceAll(versionRegex, '');
      cleanMessage = cleanMessage.replaceAll(releaseNotesRegex, '');
      cleanMessage = cleanMessage.replaceAll(suggestAppRegex, '');
      cleanMessage = cleanMessage.trim();

      final forgeCode = forgeMatch?.group(1);
      final backendCode = backendMatch?.group(1);
      final name = nameMatch?.group(1)?.trim();
      final designDoc = designMatch?.group(1)?.trim();
      final version = versionMatch?.group(1)?.trim();
      final releaseNotes = releaseNotesMatch?.group(1)?.trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forgeMatch != null) ...[
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  name != null ? 'Preview: $name' : 'App Preview',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MiniAppPreview(code: forgeCode ?? ''),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Details & Description', style: TextStyle(fontSize: 14, color: Colors.blueGrey)),
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
                  MarkdownBody(data: '```html\n${forgeCode ?? ''}\n```'),
                  if (backendCode != null && backendCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Backend Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                    MarkdownBody(data: '```javascript\n$backendCode\n```'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => onDeploy?.call(forgeCode ?? '', backendCode, name, designDoc, version, releaseNotes),
              icon: const Icon(Icons.rocket_launch),
              label: Text(name != null ? 'Deploy $name' : 'Deploy App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ] else if (cleanMessage.isNotEmpty) ...[
            MarkdownBody(data: cleanMessage),
          ],
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
