import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/vibe_detector.dart';
import 'package:appforge/widgets/mini_app_preview.dart';

void main() {
  setUp(() {
    MiniAppPreview.skipWebViewForTesting = true;
  });

  testWidgets('VibeDetector shows deploy button when <forge> tags present', (WidgetTester tester) async {
    const message = 'Hello! <name>My App</name> <forge>alert("Hello")</forge> This is your app.';
    
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VibeDetector(message: message),
      ),
    ));

    expect(find.text('Deploy My App'), findsOneWidget);
    expect(find.text('Preview: My App'), findsOneWidget);
    
    // Original message is collapsed by default
    expect(find.textContaining('Hello!'), findsNothing);
    
    // Open the expansion tile
    await tester.tap(find.text('Details & Description'));
    await tester.pumpAndSettle();
    
    expect(find.textContaining('Hello!'), findsOneWidget);
    expect(find.textContaining('This is your app.'), findsOneWidget);
  });

  testWidgets('VibeDetector does not show deploy button when no <forge> tags', (WidgetTester tester) async {
    const message = 'Just a regular message.';
    
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VibeDetector(message: message),
      ),
    ));

    expect(find.text('Deploy App'), findsNothing);
    expect(find.text('Deploy My App'), findsNothing);
    expect(find.textContaining('Just a regular message.'), findsOneWidget);
  });

  testWidgets('VibeDetector shows open button when <suggest_app> tags present', (WidgetTester tester) async {
    const message = 'You already have an app for this: <suggest_app id="test-id">My Existing App</suggest_app>';
    String? openedAppId;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VibeDetector(
          message: message,
          onOpenApp: (appId) => openedAppId = appId,
        ),
      ),
    ));

    expect(find.text('Open My Existing App'), findsOneWidget);
    expect(find.textContaining('You already have an app for this:'), findsOneWidget);

    await tester.tap(find.text('Open My Existing App'));
    expect(openedAppId, 'test-id');
  });

  testWidgets('VibeDetector parses and shows emoji icon', (WidgetTester tester) async {
    const message = '<icon>🚀</icon><name>Rocket App</name><forge><h1>Rocket</h1></forge>';
    
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VibeDetector(message: message),
      ),
    ));

    expect(find.text('🚀'), findsOneWidget);
    expect(find.text('Preview: Rocket App'), findsOneWidget);
    expect(find.text('Deploy Rocket App'), findsOneWidget);
  });

  testWidgets('MiniAppPreview has a full screen button that triggers onDeploy with isTemporary: true', (WidgetTester tester) async {
    const message = '<name>Test App</name><forge><h1>Test</h1></forge>';
    bool onDeployCalled = false;
    bool isTemp = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VibeDetector(
          message: message,
          onDeploy: (code, backendCode, periodicBackendCode, name, designDoc, version, releaseNotes, icon, {isTemporary = false}) {
            onDeployCalled = true;
            isTemp = isTemporary;
          },
        ),
      ),
    ));

    // Initially should show MiniAppPreview
    expect(find.byType(MiniAppPreview), findsOneWidget);

    // Find the full screen button in the overlay
    final fullScreenButton = find.byIcon(Icons.fullscreen);
    expect(fullScreenButton, findsOneWidget);

    // Tap it
    await tester.tap(fullScreenButton);
    await tester.pump();

    // Verify callback was triggered correctly
    expect(onDeployCalled, isTrue);
    expect(isTemp, isTrue);
  });
}
