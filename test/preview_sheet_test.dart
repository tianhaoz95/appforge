import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/preview_sheet.dart';

void main() {
  setUpAll(() {
    PreviewSheet.skipWebViewForTesting = true;
  });

  testWidgets('PreviewSheet shows content and close button', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: PreviewSheet(code: '<h1>Hello</h1>'),
      ),
    ));

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('App Preview'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
