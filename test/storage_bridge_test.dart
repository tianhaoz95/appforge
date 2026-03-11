import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMicroAppDataRepository extends Mock implements MicroAppDataRepository {}

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Bridge Integration Tests', () {
    late MockMicroAppDataRepository mockRepository;

    setUpAll(() async {
      PreviewSheet.skipWebViewForTesting = true;
    });

    setUp(() async {
      mockRepository = MockMicroAppDataRepository();
    });

    testWidgets('Bridge processes saveData message', (WidgetTester tester) async {
      const appId = 'bridge-app';
      const key = 'test_key';
      const value = {'foo': 'bar'};

      when(() => mockRepository.saveData(any(), any(), any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(MaterialApp(
        home: Provider<MicroAppDataRepository>.value(
          value: mockRepository,
          child: const PreviewSheet(
            code: '<div></div>',
            appId: appId,
          ),
        ),
      ));

      final previewSheetState = tester.state<PreviewSheetState>(find.byType(PreviewSheet));
      
      // Simulate message from WebView
      await previewSheetState.handleMessage(jsonEncode({
        'action': 'saveData',
        'requestId': 'req-1',
        'key': key,
        'value': value,
      }));

      // Verify data in repository
      verify(() => mockRepository.saveData(appId, key, value)).called(1);
    });

    testWidgets('Bridge processes getData message', (WidgetTester tester) async {
      const appId = 'bridge-app';
      const key = 'existing_key';
      const value = 'important data';
      
      when(() => mockRepository.getData(any(), any()))
          .thenAnswer((_) async => value);

      await tester.pumpWidget(MaterialApp(
        home: Provider<MicroAppDataRepository>.value(
          value: mockRepository,
          child: const PreviewSheet(
            code: '<div></div>',
            appId: appId,
          ),
        ),
      ));

      final previewSheetState = tester.state<PreviewSheetState>(find.byType(PreviewSheet));
      
      await previewSheetState.handleMessage(jsonEncode({
        'action': 'getData',
        'requestId': 'req-2',
        'key': key,
      }));
      
      verify(() => mockRepository.getData(appId, key)).called(1);
    });
  });
}

// Helper to access private state for testing
extension PreviewSheetStateTester on WidgetTester {
  PreviewSheetState state<T>(Finder finder) => (element(finder) as StatefulElement).state as PreviewSheetState;
}
