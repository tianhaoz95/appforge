import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:appforge/firebase_options.dart';

import 'package:appforge/main.dart';
import 'package:appforge/widgets/preview_sheet.dart';
import 'package:appforge/repositories/local_database.dart';
import 'package:appforge/providers/auth_provider.dart';
import 'package:appforge/providers/settings_provider.dart';
import 'package:appforge/repositories/micro_app_repository.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

class MockLlmProvider extends LlmProvider with ChangeNotifier {
  final List<ChatMessage> _history = [];

  @override
  List<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> newHistory) {
    _history.clear();
    _history.addAll(newHistory);
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    if (prompt.toLowerCase().contains('todo')) {
      final mockResponse = '''
<name>Todo App</name>
<icon>✅</icon>
<design>A simple todo app using local database.</design>
<version>1.0.0</version>
<release_notes>Initial release</release_notes>
<forge>
<div x-data="todoApp()" class="p-4 h-full flex flex-col">
  <h1 class="text-2xl font-bold mb-4">Todo App</h1>
  <div class="flex mb-4">
    <input x-model="newTask" class="flex-1 p-2 border" id="todo-input" />
    <button @click="addTask" class="ml-2 p-2 bg-blue-500 text-white" id="todo-add">Add</button>
  </div>
  <ul>
    <template x-for="task in tasks" :key="task.id">
      <li x-text="task.text"></li>
    </template>
  </ul>
</div>
<script>
document.addEventListener('alpine:init', () => {
  Alpine.data('todoApp', () => ({
    tasks: [],
    newTask: '',
    async init() {
      let saved = await window.MicroForge.getData('todos');
      if (!saved || saved === '[]') {
        await window.MicroForge.saveData('todos', JSON.stringify([{id: '1', text: 'Auto Task', done: false}]));
        saved = await window.MicroForge.getData('todos');
      }
      this.tasks = JSON.parse(saved);
    },
    async addTask() {
      if (this.newTask.trim() === '') return;
      this.tasks.push({ id: Date.now().toString(), text: this.newTask, done: false });
      this.newTask = '';
      await window.MicroForge.saveData('todos', JSON.stringify(this.tasks));
    }
  }));
});
</script>
</forge>
''';
      for (var i = 0; i < mockResponse.length; i += 50) {
        final end = (i + 50 < mockResponse.length) ? i + 50 : mockResponse.length;
        yield mockResponse.substring(i, end);
        await Future.delayed(const Duration(milliseconds: 10));
      }
    } else {
      yield "I don't know how to do that.";
    }
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment> attachments = const []}) async* {
    yield* sendMessageStream(prompt, attachments: attachments);
  }
}

class MockAuthProvider extends AuthProvider {
  @override
  bool get isAuthenticated => true;

  @override
  User? get user => null; 
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    PreviewSheet.skipWebViewForTesting = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Todo App Generation and Database Operations Test', (WidgetTester tester) async {
    MicroForgeHomePage.mockProvider = MockLlmProvider();

    final dbHelper = LocalDatabase();
    final settingsProvider = SettingsProvider();
    await settingsProvider.loadSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider(create: (_) => MicroAppRepository(dbHelper: dbHelper)),
          Provider(create: (_) => MicroAppDataRepository(dbHelper: dbHelper)),
          ChangeNotifierProvider(create: (_) => ConversationRepository(dbHelper: dbHelper)),
          ChangeNotifierProvider<AuthProvider>(create: (_) => MockAuthProvider()),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Now on MicroForgeHomePage
    // Instead of typing, just set the history to simulate the completed generation
    final mockResponse = '''
<name>Todo App</name>
<icon>✅</icon>
<design>A simple todo app using local database.</design>
<version>1.0.0</version>
<release_notes>Initial release</release_notes>
<forge>
<div x-data="todoApp()" class="p-4 h-full flex flex-col">
  <h1 class="text-2xl font-bold mb-4">Todo App</h1>
  <div class="flex mb-4">
    <input x-model="newTask" class="flex-1 p-2 border" id="todo-input" />
    <button @click="addTask" class="ml-2 p-2 bg-blue-500 text-white" id="todo-add">Add</button>
  </div>
  <ul>
    <template x-for="task in tasks" :key="task.id">
      <li x-text="task.text"></li>
    </template>
  </ul>
</div>
<script>
document.addEventListener('alpine:init', () => {
  Alpine.data('todoApp', () => ({
    tasks: [],
    newTask: '',
    async init() {
      let saved = await window.MicroForge.getData('todos');
      if (!saved || saved === '[]') {
        await window.MicroForge.saveData('todos', JSON.stringify([{id: '1', text: 'Auto Task', done: false}]));
        saved = await window.MicroForge.getData('todos');
      }
      this.tasks = JSON.parse(saved);
    },
    async addTask() {
      if (this.newTask.trim() === '') return;
      this.tasks.push({ id: Date.now().toString(), text: this.newTask, done: false });
      this.newTask = '';
      await window.MicroForge.saveData('todos', JSON.stringify(this.tasks));
    }
  }));
});
</script>
</forge>
''';

    MicroForgeHomePage.mockProvider!.history = [
      ChatMessage(origin: MessageOrigin.user, text: 'make a todo app', attachments: const []),
      ChatMessage(origin: MessageOrigin.llm, text: mockResponse, attachments: const []),
    ];
    
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Tap deploy button
    final deployButton = find.text('Deploy', skipOffstage: false);
    expect(deployButton, findsOneWidget, reason: 'Deploy button not found');
    await tester.ensureVisible(deployButton);
    await tester.pumpAndSettle();
    await tester.tap(deployButton);

    // Wait for PreviewSheet and WebView to load, then JS init to execute
    await tester.pumpAndSettle(const Duration(seconds: 5));
    // Additional delay for JS execution across the bridge
    await Future.delayed(const Duration(seconds: 5));

    // Verify database operations
    final db = await dbHelper.database;
    final data = await db.query('micro_app_data', where: 'key = ?', whereArgs: ['todos']);
    
    expect(data.isNotEmpty, isTrue, reason: 'Database should contain saved todos data');
    
    final savedValue = data.first['value'] as String;
    expect(savedValue.contains('Auto Task'), isTrue, reason: 'Saved value should contain Auto Task');
  });
}
