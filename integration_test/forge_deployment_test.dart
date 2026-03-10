import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:appforge/widgets/vibe_detector.dart';
import 'package:appforge/widgets/preview_sheet.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PreviewSheet.skipWebViewForTesting = true;
  });

  testWidgets('VibeDetector Deployment Logic Test', (WidgetTester tester) async {
    String? deployedCode;
    bool showPreview = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Stack(
                children: [
                  VibeDetector(
                    message: 'Here is your app: <forge><h1>Hello</h1></forge>',
                    onDeploy: (code) {
                      setState(() {
                        deployedCode = code;
                        showPreview = true;
                      });
                    },
                  ),
                  if (showPreview && deployedCode != null)
                    PreviewSheet(
                      code: deployedCode!,
                      onClose: () => setState(() => showPreview = false),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // 1. Verify VibeDetector found the tag and showed the button
    expect(find.text('Deploy to App Bar'), findsOneWidget);

    // 2. Tap Deploy
    await tester.tap(find.text('Deploy to App Bar'));
    await tester.pumpAndSettle();

    // 3. Verify PreviewSheet is shown
    expect(find.byType(PreviewSheet), findsOneWidget);
    expect(find.text('App Preview'), findsOneWidget);
    expect(deployedCode, '<h1>Hello</h1>');
  });
}
