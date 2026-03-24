import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/app_vault_title.dart';

void main() {
  testWidgets('AppVaultTitle shows "Saved Scripts" on iOS', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppVaultTitle(),
      ),
    ));

    expect(find.text('Saved Scripts'), findsOneWidget);
    expect(find.text('Forged Utils'), findsNothing);
    
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppVaultTitle shows "Saved Scripts" on macOS', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppVaultTitle(),
      ),
    ));

    expect(find.text('Saved Scripts'), findsOneWidget);
    expect(find.text('Forged Utils'), findsNothing);
    
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppVaultTitle shows "Forged Utils" on Android', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppVaultTitle(),
      ),
    ));

    expect(find.text('Forged Utils'), findsOneWidget);
    expect(find.text('Saved Scripts'), findsNothing);
    
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('AppVaultTitle shows "Forged Utils" on Windows', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppVaultTitle(),
      ),
    ));

    expect(find.text('Forged Utils'), findsOneWidget);
    expect(find.text('Saved Scripts'), findsNothing);
    
    debugDefaultTargetPlatformOverride = null;
  });
}
