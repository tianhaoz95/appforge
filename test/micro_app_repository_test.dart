import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:appforge/repositories/micro_app_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late MicroAppRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MicroAppRepository(firestore: firestore);
  });

  test('Save and retrieve a micro-app', () async {
    final appData = {
      'name': 'Test App',
      'ownerId': 'user_1',
      'version': 1.0,
      'html_blob': '<h1>Hello</h1>',
      'icon': 'rocket',
    };

    final appId = await repository.saveApp(appData);
    expect(appId, isNotNull);

    final retrievedApp = await repository.getApp(appId);
    expect(retrievedApp?['name'], 'Test App');
    expect(retrievedApp?['html_blob'], '<h1>Hello</h1>');
  });

  test('List apps for owner', () async {
    await repository.saveApp({'name': 'App 1', 'ownerId': 'user_1', 'html_blob': '...', 'version': 1.0, 'icon': '1'});
    await repository.saveApp({'name': 'App 2', 'ownerId': 'user_1', 'html_blob': '...', 'version': 1.0, 'icon': '2'});
    await repository.saveApp({'name': 'App 3', 'ownerId': 'user_2', 'html_blob': '...', 'version': 1.0, 'icon': '3'});

    final user1Apps = await repository.getAppsForOwner('user_1');
    expect(user1Apps.length, 2);
  });
}
