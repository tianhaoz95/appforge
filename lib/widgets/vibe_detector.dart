import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'mini_app_preview.dart';

class VibeDetector extends StatelessWidget {
  final String message;
  final Function(String code, String? backendCode, String? periodicBackendCode, String? name, String? designDoc, String? version, String? releaseNotes, String? icon, {bool isTemporary})? onDeploy;
  final Function(String appId)? onOpenApp;
  final Function(String code, String? backendCode, String? periodicBackendCode, String? name, String? designDoc, String? version, String? releaseNotes, String? icon)? onAutoRefine;

  const VibeDetector({
    super.key,
    required this.message,
    this.onDeploy,
    this.onOpenApp,
    this.onAutoRefine,
  });

  @override
  Widget build(BuildContext context) {
    final forgeRegex = RegExp(r'<forge>([\s\S]*?)<\/forge>');
    final backendRegex = RegExp(r'<backend>([\s\S]*?)<\/backend>');
    final periodicBackendRegex = RegExp(r'<periodic_backend>([\s\S]*?)<\/periodic_backend>');
    final nameRegex = RegExp(r'<name>([\s\S]*?)<\/name>');
    final iconRegex = RegExp(r'<icon>([\s\S]*?)<\/icon>');
    final designRegex = RegExp(r'<design>([\s\S]*?)<\/design>');
    final versionRegex = RegExp(r'<version>([\s\S]*?)<\/version>');
    final releaseNotesRegex = RegExp(r'<release_notes>([\s\S]*?)<\/release_notes>');
    final suggestAppRegex = RegExp(r'<suggest_app id="([^"]+)">([\s\S]*?)<\/suggest_app>');

    final forgeMatch = forgeRegex.firstMatch(message);
    final backendMatch = backendRegex.firstMatch(message);
    final periodicBackendMatch = periodicBackendRegex.firstMatch(message);
    final nameMatch = nameRegex.firstMatch(message);
    final iconMatch = iconRegex.firstMatch(message);
    final designMatch = designRegex.firstMatch(message);
    final versionMatch = versionRegex.firstMatch(message);
    final releaseNotesMatch = releaseNotesRegex.allMatches(message).lastOrNull;
    final suggestAppMatches = suggestAppRegex.allMatches(message).toList();

    if (forgeMatch != null || suggestAppMatches.isNotEmpty) {
      String cleanMessage = message.replaceAll(forgeRegex, '');
      cleanMessage = cleanMessage.replaceAll(backendRegex, '');
      cleanMessage = cleanMessage.replaceAll(periodicBackendRegex, '');
      cleanMessage = cleanMessage.replaceAll(nameRegex, '');
      cleanMessage = cleanMessage.replaceAll(iconRegex, '');
      cleanMessage = cleanMessage.replaceAll(designRegex, '');
      cleanMessage = cleanMessage.replaceAll(versionRegex, '');
      cleanMessage = cleanMessage.replaceAll(releaseNotesRegex, '');
      cleanMessage = cleanMessage.replaceAll(suggestAppRegex, '');
      cleanMessage = cleanMessage.trim();

      final forgeCode = forgeMatch?.group(1);
      final backendCode = backendMatch?.group(1);
      final periodicBackendCode = periodicBackendMatch?.group(1);
      final name = nameMatch?.group(1)?.trim();
      final icon = iconMatch?.group(1)?.trim();
      final designDoc = designMatch?.group(1)?.trim();
      final version = versionMatch?.group(1)?.trim();
      final releaseNotes = releaseNotesMatch?.group(1)?.trim();

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (forgeMatch != null) ...[
              Row(
                children: [
                  if (icon != null && icon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(icon, style: const TextStyle(fontSize: 20)),
                    )
                  else
                    const Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    name != null ? 'Preview: $name' : 'App Preview',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MiniAppPreview(
                code: forgeCode ?? '',
                onFullScreen: () => onDeploy?.call(
                  forgeCode ?? '',
                  backendCode,
                  periodicBackendCode,
                  name,
                  designDoc,
                  version,
                  releaseNotes,
                  icon,
                  isTemporary: true,
                ),
              ),
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
                    if (periodicBackendCode != null && periodicBackendCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Background Periodic Code:', style: TextStyle(fontWeight: FontWeight.bold)),
                      MarkdownBody(data: '```javascript\n$periodicBackendCode\n```'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (onAutoRefine != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onAutoRefine?.call(forgeCode ?? '', backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Auto Refine'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onDeploy?.call(forgeCode ?? '', backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon),
                  icon: const Icon(Icons.rocket_launch),
                  label: Text(name != null ? 'Deploy $name' : 'Deploy App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                  ),
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
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onOpenApp?.call(appId ?? ''),
                      icon: const Icon(Icons.open_in_new),
                      label: Text('Open ${appName ?? 'Existing App'}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      );
    }

    return MarkdownBody(data: message);
  }
}
