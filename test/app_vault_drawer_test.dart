import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/app_vault_drawer.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockMicroAppRepository extends Mock implements MicroAppRepository {}

void main() {
  late MockMicroAppRepository mockRepository;

  setUp(() {
    mockRepository = MockMicroAppRepository();
  });

  testWidgets('AppVaultDrawer shows list of apps from repository', (WidgetTester tester) async {
    final apps = [
      {'appId': '1', 'name': 'App 1', 'icon': 'rocket'},
      {'appId': '2', 'name': 'App 2', 'icon': 'speed'},
    ];

    when(() => mockRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => apps);

    await tester.pumpWidget(MaterialApp(
      home: Provider<MicroAppRepository>.value(
        value: mockRepository,
        child: const Scaffold(
          drawer: AppVaultDrawer(),
          body: Center(child: Text('Body')),
        ),
      ),
    ));

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('App 1'), findsOneWidget);
    expect(find.text('App 2'), findsOneWidget);
  });
}
