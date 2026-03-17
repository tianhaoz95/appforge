import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class MicroAppDataRepository {
  final LocalDatabase _dbHelper;

  MicroAppDataRepository({LocalDatabase? dbHelper})
      : _dbHelper = dbHelper ?? LocalDatabase();

  Future<void> saveData(String appId, String key, dynamic value) async {
    final db = await _dbHelper.database;
    final jsonValue = jsonEncode(value);
    
    await db.insert(
      'micro_app_data',
      {
        'appId': appId,
        'key': key,
        'value': jsonValue,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> getData(String appId, String key) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'micro_app_data',
      where: 'appId = ? AND key = ?',
      whereArgs: [appId, key],
    );

    if (results.isEmpty) return null;
    return jsonDecode(results.first['value']);
  }

  Future<void> deleteData(String appId, String key) async {
    final db = await _dbHelper.database;
    await db.delete(
      'micro_app_data',
      where: 'appId = ? AND key = ?',
      whereArgs: [appId, key],
    );
  }

  Future<Map<String, dynamic>> listAll(String appId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'micro_app_data',
      where: 'appId = ?',
      whereArgs: [appId],
    );

    final Map<String, dynamic> data = {};
    for (var row in results) {
      data[row['key']] = jsonDecode(row['value']);
    }
    return data;
  }
}
