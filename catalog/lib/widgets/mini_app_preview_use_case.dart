import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:appforge/widgets/mini_app_preview.dart';
import 'package:appforge/providers/settings_provider.dart';

@widgetbook.UseCase(
  name: 'Default',
  type: MiniAppPreview,
)
Widget buildMiniAppPreviewUseCase(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: const MiniAppPreview(
            code: '<div class="p-8 bg-blue-500 text-white rounded-xl shadow-lg">Hello from Widgetbook!</div>',
            height: 200,
          ),
        ),
      ),
    ),
  );
}

@widgetbook.UseCase(
  name: 'Complex App',
  type: MiniAppPreview,
)
Widget buildMiniAppPreviewComplexUseCase(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
          child: const MiniAppPreview(
            code: '''
<div class="p-6 max-w-sm mx-auto bg-white rounded-xl shadow-md flex items-center space-x-4">
  <div class="flex-shrink-0">
    <div class="h-12 w-12 bg-indigo-500 rounded-full flex items-center justify-center text-white">WF</div>
  </div>
  <div>
    <div class="text-xl font-medium text-black">WidgetForge</div>
    <p class="text-gray-500">You have a new message!</p>
  </div>
</div>
''',
            height: 300,
          ),
        ),
      ),
    ),
  );
}
