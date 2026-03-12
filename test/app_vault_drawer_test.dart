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

  testWidgets('AppVaultDrawer shows delete dialog on long press and deletes app', (WidgetTester tester) async {
    final app = {'appId': '1', 'name': 'Deletable App', 'icon': 'rocket', 'version': '1.0.0'};
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => [app]);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => []);
    when(() => mockAppRepository.deleteApp(any())).thenAnswer((_) async {});

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

    // Long press on app
    await tester.longPress(find.text('Deletable App'));
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Delete Micro App?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify repository call
    verify(() => mockAppRepository.deleteApp('1')).called(1);
  });

  testWidgets('AppVaultDrawer shows delete dialog on long press and deletes conversation', (WidgetTester tester) async {
    final conv = {'conversationId': 'c1', 'title': 'Deletable Chat', 'updated_at': 12345};
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => []);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => [conv]);
    when(() => mockConvRepository.deleteConversation(any())).thenAnswer((_) async {});

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

    // Long press on conversation
    await tester.longPress(find.text('Deletable Chat'));
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Delete Conversation?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Tap delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify repository call
    verify(() => mockConvRepository.deleteConversation('c1')).called(1);
  });
}
