import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/app_vault_drawer.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockMicroAppRepository extends Mock implements MicroAppRepository {}
class MockConversationRepository extends Mock implements ConversationRepository {}

void main() {
  late MockMicroAppRepository mockAppRepository;
  late MockConversationRepository mockConvRepository;

  setUp(() {
    mockAppRepository = MockMicroAppRepository();
    mockConvRepository = MockConversationRepository();
  });

  testWidgets('AppVaultDrawer shows list of apps from repository', (WidgetTester tester) async {
    final apps = [
      {'appId': '1', 'name': 'App 1', 'icon': 'rocket', 'version': '1.0.0'},
      {'appId': '2', 'name': 'App 2', 'icon': 'speed', 'version': '1.0.0'},
    ];

    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => apps);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          Provider<MicroAppRepository>.value(value: mockAppRepository),
          Provider<ConversationRepository>.value(value: mockConvRepository),
        ],
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
