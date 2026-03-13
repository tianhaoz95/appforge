import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class MicroAppRepository {
  final LocalDatabase _dbHelper;
  final _uuid = const Uuid();

  MicroAppRepository({LocalDatabase? dbHelper})
      : _dbHelper = dbHelper ?? LocalDatabase();

  Future<String> saveApp(Map<String, dynamic> appData) async {
    final appId = appData['appId'] ?? _uuid.v4();
    final db = await _dbHelper.database;
    
    final data = {
      'appId': appId,
      'ownerId': appData['ownerId'] ?? 'local-user',
      'conversationId': appData['conversationId'],
      'name': appData['name'],
      'html_blob': appData['html_blob'],
      'backend_blob': appData['backend_blob'],
      'design_doc': appData['design_doc'],
      'version': appData['version'],
      'icon': appData['icon'],
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    await db.insert(
      'micro_apps',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return appId;
  }

  Future<Map<String, dynamic>?> getApp(String appId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'micro_apps',
      where: 'appId = ?',
      whereArgs: [appId],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getAppsForOwner(String ownerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'micro_apps',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'created_at DESC',
    );

    return maps;
  }

  Future<void> deleteApp(String appId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'micro_apps',
        where: 'appId = ?',
        whereArgs: [appId],
      );
      await txn.delete(
        'micro_app_data',
        where: 'appId = ?',
        whereArgs: [appId],
      );
    });
  }
}
