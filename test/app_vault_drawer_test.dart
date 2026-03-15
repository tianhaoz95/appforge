import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/widgets/app_vault_drawer.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockMicroAppRepository extends Mock implements MicroAppRepository {}
class MockConversationRepository extends Mock implements ConversationRepository {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockSettingsProvider extends Mock implements SettingsProvider {}

void main() {
  late MockMicroAppRepository mockAppRepository;
  late MockConversationRepository mockConvRepository;
  late MockAuthProvider mockAuthProvider;
  late MockSettingsProvider mockSettingsProvider;

  setUp(() {
    mockAppRepository = MockMicroAppRepository();
    mockConvRepository = MockConversationRepository();
    mockAuthProvider = MockAuthProvider();
    mockSettingsProvider = MockSettingsProvider();
    
    when(() => mockAuthProvider.user).thenReturn(null);
    when(() => mockSettingsProvider.localAvatarPath).thenReturn('');
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
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // Long press on app to enter selection mode
    await tester.longPress(find.text('Deletable App'));
    await tester.pumpAndSettle();

    // Now long press AGAIN while in selection mode to show single delete dialog
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

  testWidgets('AppVaultDrawer enters selection mode on long press and bulk deletes', (WidgetTester tester) async {
    final convs = [
      {'conversationId': 'c1', 'title': 'Chat 1', 'updated_at': 1000},
      {'conversationId': 'c2', 'title': 'Chat 2', 'updated_at': 900},
    ];
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => []);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => convs);
    when(() => mockConvRepository.deleteConversations(any())).thenAnswer((_) async {});

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // Long press on Chat 1 to enter selection mode
    await tester.longPress(find.text('Chat 1'));
    await tester.pumpAndSettle();

    // Verify selection mode header
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2)); // Checkboxes should appear

    // Select Chat 2
    await tester.tap(find.text('Chat 2'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Tap delete in header
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Delete 2 Items?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify repository call
    verify(() => mockConvRepository.deleteConversations(['c1', 'c2'])).called(1);
    expect(find.text('Recent Chats'), findsOneWidget); // Back to normal mode
  });

  testWidgets('AppVaultDrawer enters selection mode on app long press and bulk deletes apps', (WidgetTester tester) async {
    final apps = [
      {'appId': 'a1', 'name': 'App 1', 'icon': 'rocket', 'version': '1.0.0'},
      {'appId': 'a2', 'name': 'App 2', 'icon': 'speed', 'version': '1.0.0'},
    ];
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => apps);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => []);
    when(() => mockAppRepository.deleteApps(any())).thenAnswer((_) async {});

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // Long press on App 1 to enter selection mode
    await tester.longPress(find.text('App 1'));
    await tester.pumpAndSettle();

    // Verify selection mode header
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2)); // Checkboxes should appear

    // Select App 2
    await tester.tap(find.text('App 2'));
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Tap delete in header
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Check dialog
    expect(find.text('Delete 2 Items?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify repository call
    verify(() => mockAppRepository.deleteApps(['a1', 'a2'])).called(1);
  });

  testWidgets('AppVaultDrawer "Select All" selects both apps and conversations', (WidgetTester tester) async {
    final convs = [
      {'conversationId': 'c1', 'title': 'Chat 1', 'updated_at': 1000},
    ];
    final apps = [
      {'appId': 'a1', 'name': 'App 1', 'icon': 'rocket', 'version': '1.0.0'},
    ];
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => apps);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => convs);

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // Enter selection mode via App
    await tester.longPress(find.text('App 1'));
    await tester.pumpAndSettle();

    // Tap Select All
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('2 Selected'), findsOneWidget);
    
    // Tap Deselect All
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(find.text('0 Selected'), findsOneWidget);
  });

  testWidgets('AppVaultDrawer "Select All" selects all conversations', (WidgetTester tester) async {
    final convs = [
      {'conversationId': 'c1', 'title': 'Chat 1', 'updated_at': 1000},
      {'conversationId': 'c2', 'title': 'Chat 2', 'updated_at': 900},
      {'conversationId': 'c3', 'title': 'Chat 3', 'updated_at': 800},
      {'conversationId': 'c4', 'title': 'Chat 4', 'updated_at': 700},
    ];
    
    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => []);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => convs);

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // Enter selection mode
    await tester.longPress(find.text('Chat 1'));
    await tester.pumpAndSettle();

    // Tap Select All
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    expect(find.text('4 Selected'), findsOneWidget);
    
    // Tap Deselect All
    await tester.tap(find.text('Deselect All'));
    await tester.pumpAndSettle();
    expect(find.text('0 Selected'), findsOneWidget);
  });

  testWidgets('AppVaultDrawer does not show Sign Out button', (WidgetTester tester) async {
    when(() => mockAppRepository.getAppsForOwner(any())).thenAnswer((_) async => []);
    when(() => mockConvRepository.getConversations()).thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
        ],
        child: const Scaffold(
          drawer: AppVaultDrawer(),
          body: Center(child: Text('Body')),
        ),
      ),
    ));

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Sign Out'), findsNothing);
  });

  testWidgets('AppVaultDrawer shows only 3 recent chats directly and others in ExpansionTile', (WidgetTester tester) async {
    final convs = List.generate(5, (i) => {
      'conversationId': 'c$i',
      'title': 'Chat $i',
      'updated_at': 1000 - i,
    });

    when(() => mockAppRepository.getAppsForOwner(any()))
        .thenAnswer((_) async => []);
    when(() => mockConvRepository.getConversations())
        .thenAnswer((_) async => convs);

    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<MicroAppRepository>.value(value: mockAppRepository),
          ChangeNotifierProvider<ConversationRepository>.value(value: mockConvRepository),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: mockSettingsProvider),
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

    // The first 3 should be visible
    expect(find.text('Chat 0'), findsOneWidget);
    expect(find.text('Chat 1'), findsOneWidget);
    expect(find.text('Chat 2'), findsOneWidget);

    // The rest should NOT be visible initially (inside collapsed ExpansionTile)
    expect(find.text('Chat 3'), findsNothing);
    expect(find.text('Chat 4'), findsNothing);

    // Check for the ExpansionTile title
    expect(find.text('Older Chats (2)'), findsOneWidget);

    // Expand the tile
    await tester.tap(find.text('Older Chats (2)'));
    await tester.pumpAndSettle();

    // Now they should be visible
    expect(find.text('Chat 3'), findsOneWidget);
    expect(find.text('Chat 4'), findsOneWidget);
  });
}
