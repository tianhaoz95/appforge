import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/vibe_detector.dart';

void main() {
  testWidgets('VibeDetector shows deploy button when <forge> tags present', (WidgetTester tester) async {
    const message = 'Hello! <forge>alert("Hello")</forge> This is your app.';
    
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: VibeDetector(message: message),
      ),
    ));

    expect(find.text('Deploy to App Bar'), findsOneWidget);
    // Markdown might split texts, so we check for fragments or use find.byType
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

    expect(find.text('Deploy to App Bar'), findsNothing);
    expect(find.textContaining('Just a regular message.'), findsOneWidget);
  });
}
