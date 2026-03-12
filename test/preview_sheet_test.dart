import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:feedback/feedback.dart';

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
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('PreviewSheet shows Design button when designDoc is provided', (WidgetTester tester) async {
    final mockRepo = MockMicroAppDataRepository();
    const designDoc = '# My Design\nThis is a test design.';
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Provider<MicroAppDataRepository>.value(
          value: mockRepo,
          child: const PreviewSheet(
            code: '<h1>Hello</h1>',
            designDoc: designDoc,
            appId: 'test-app',
          ),
        ),
      ),
    ));

    expect(find.text('Design'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);

    // Tap the Design button
    await tester.tap(find.text('Design'));
    await tester.pumpAndSettle();

    // Verify modal is shown
    expect(find.text('Design Document'), findsOneWidget);
    expect(find.text('My Design'), findsOneWidget);
    expect(find.text('This is a test design.'), findsOneWidget);
  });

  testWidgets('PreviewSheet shows Enhance button when onEnhance is provided', (WidgetTester tester) async {
    final mockRepo = MockMicroAppDataRepository();
    bool enhanceTapped = false;
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Provider<MicroAppDataRepository>.value(
          value: mockRepo,
          child: PreviewSheet(
            code: '<h1>Hello</h1>',
            appId: 'test-app',
            onEnhance: () {
              enhanceTapped = true;
            },
          ),
        ),
      ),
    ));

    expect(find.text('Enhance'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    // Tap the Enhance button
    await tester.tap(find.text('Enhance'));
    await tester.pump();

    // Verify callback triggered
    expect(enhanceTapped, isTrue);
  });

  testWidgets('PreviewSheet shows Feedback button when onFeedback is provided', (WidgetTester tester) async {
    final mockRepo = MockMicroAppDataRepository();
    
    await tester.pumpWidget(BetterFeedback(
      child: MaterialApp(
        home: Scaffold(
          body: Provider<MicroAppDataRepository>.value(
            value: mockRepo,
            child: PreviewSheet(
              code: '<h1>Hello</h1>',
              appId: 'test-app',
              onFeedback: (text, screenshot) {
                // feedback triggered
              },
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Feedback'), findsOneWidget);
    expect(find.byIcon(Icons.feedback_outlined), findsOneWidget);

    // Tap the Feedback button
    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();

    // BetterFeedback shows its UI, but it's hard to test the whole flow here.
    // Just verifying it exists is a good start.
  });
}
