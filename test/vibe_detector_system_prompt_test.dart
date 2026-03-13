import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/vibe_detector.dart';

void main() {
  testWidgets('VibeDetector handles multiline <forge> tags', (WidgetTester tester) async {
    const message = '''
Here is your app:
<forge>
<div class="bg-blue-500 p-4">
  <h1 x-text="title"></h1>
</div>
</forge>
Hope you like it!
''';
    
    String? capturedCode;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VibeDetector(
          message: message,
          onDeploy: (code, backendCode, name, designDoc, version, releaseNotes) => capturedCode = code,
        ),
      ),
    ));

    expect(find.text('Deploy App'), findsOneWidget);
    
    await tester.tap(find.text('Deploy App'));
    
    expect(capturedCode, contains('<div class="bg-blue-500 p-4">'));
    expect(capturedCode, contains('<h1 x-text="title"></h1>'));
  });
}
