import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMicroAppDataRepository extends Mock implements MicroAppDataRepository {}

void main() {
  setUpAll(() {
    PreviewSheet.skipWebViewForTesting = true;
  });

  testWidgets('PreviewSheet shows content and close button', (WidgetTester tester) async {
    final mockRepo = MockMicroAppDataRepository();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Provider<MicroAppDataRepository>.value(
          value: mockRepo,
          child: const PreviewSheet(
            code: '<h1>Hello</h1>',
            appId: 'test-app',
          ),
        ),
      ),
    ));

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('App Preview'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
