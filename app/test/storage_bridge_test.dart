import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockMicroAppDataRepository extends Mock implements MicroAppDataRepository {}
class MockMicroAppRepository extends Mock implements MicroAppRepository {}

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Storage Bridge Integration Tests', () {
    late MockMicroAppDataRepository mockDataRepository;
    late MockMicroAppRepository mockAppRepository;

    setUpAll(() async {
      PreviewSheet.skipWebViewForTesting = true;
    });

    setUp(() async {
      mockDataRepository = MockMicroAppDataRepository();
      mockAppRepository = MockMicroAppRepository();
      when(() => mockAppRepository.getAppVersions(any())).thenAnswer((_) async => []);
    });

    testWidgets('Bridge processes saveData message', (WidgetTester tester) async {
      const appId = 'bridge-app';
      const key = 'test_key';
      const value = {'foo': 'bar'};

      when(() => mockDataRepository.saveData(any(), any(), any()))
          .thenAnswer((_) async => {});

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<MicroAppDataRepository>.value(value: mockDataRepository),
            ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ],
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
      verify(() => mockDataRepository.saveData(appId, key, value)).called(1);
    });

    testWidgets('Bridge processes getData message', (WidgetTester tester) async {
      const appId = 'bridge-app';
      const key = 'existing_key';
      const value = 'important data';
      
      when(() => mockDataRepository.getData(any(), any()))
          .thenAnswer((_) async => value);

      await tester.pumpWidget(MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<MicroAppDataRepository>.value(value: mockDataRepository),
            ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ],
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
      
      verify(() => mockDataRepository.getData(appId, key)).called(1);
    });
  });
}

// Helper to access private state for testing
extension PreviewSheetStateTester on WidgetTester {
  PreviewSheetState state<T>(Finder finder) => (element(finder) as StatefulElement).state as PreviewSheetState;
}
