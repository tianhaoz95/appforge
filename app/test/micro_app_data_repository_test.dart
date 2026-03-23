import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:appforge/repositories/micro_app_data_repository.dart';
import 'package:appforge/repositories/local_database.dart';

void main() {
  late LocalDatabase dbHelper;
  late MicroAppDataRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalDatabase.setTestPath(inMemoryDatabasePath);
  });

  setUp(() async {
    dbHelper = LocalDatabase();
    repository = MicroAppDataRepository(dbHelper: dbHelper);
    
    // Ensure a clean database for each test
    final db = await dbHelper.database;
    await db.delete('micro_app_data');
  });

  test('saveData and getData works', () async {
    const appId = 'test-app';
    const key = 'user_settings';
    final value = {'theme': 'dark', 'notifications': true};

    await repository.saveData(appId, key, value);
    final retrievedValue = await repository.getData(appId, key);

    expect(retrievedValue, value);
  });

  test('deleteData works', () async {
    const appId = 'test-app';
    const key = 'temp_data';
    await repository.saveData(appId, key, 'to be deleted');
    
    await repository.deleteData(appId, key);
    final value = await repository.getData(appId, key);

    expect(value, isNull);
  });

  test('listAll works and respects appId isolation', () async {
    await repository.saveData('app1', 'k1', 'v1');
    await repository.saveData('app1', 'k2', 'v2');
    await repository.saveData('app2', 'k1', 'other');

    final app1Data = await repository.listAll('app1');
    expect(app1Data, {'k1': 'v1', 'k2': 'v2'});
    expect(app1Data.length, 2);

    final app2Data = await repository.listAll('app2');
    expect(app2Data, {'k1': 'other'});
  });
}
