import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:appforge/widgets/vibe_detector.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';

class MockMicroAppDataRepository extends StatelessWidget {
  final Widget child;
  const MockMicroAppDataRepository({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return child;
  }
}

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PreviewSheet.skipWebViewForTesting = true;
  });

  testWidgets('VibeDetector Deployment Logic Test', (WidgetTester tester) async {
    String? deployedCode;
    bool showPreview = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Provider<MicroAppDataRepository>(
          create: (_) => MicroAppDataRepository(),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Stack(
                  children: [
                    VibeDetector(
                      message: 'Here is your app: <forge><h1>Hello</h1></forge>',
                      onDeploy: (code, name, designDoc) {
                        setState(() {
                          deployedCode = code;
                          showPreview = true;
                        });
                      },
                    ),
                    if (showPreview && deployedCode != null)
                      PreviewSheet(
                        code: deployedCode!,
                        appId: 'test-app',
                        onClose: () => setState(() => showPreview = false),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    // 1. Verify VibeDetector found the tag and showed the button
    expect(find.text('Deploy App'), findsOneWidget);

    // 2. Tap Deploy
    await tester.tap(find.text('Deploy App'));
    await tester.pumpAndSettle();

    // 3. Verify PreviewSheet is shown
    expect(find.byType(PreviewSheet), findsOneWidget);
    expect(deployedCode, '<h1>Hello</h1>');
  });
}
