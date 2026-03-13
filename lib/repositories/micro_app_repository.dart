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
      'release_notes': appData['release_notes'],
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

  Future<Map<String, dynamic>?> getApp(String appId, {String? version}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'micro_apps',
      where: version != null ? 'appId = ? AND version = ?' : 'appId = ?',
      whereArgs: version != null ? [appId, version] : [appId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getAppVersions(String appId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'micro_apps',
      where: 'appId = ?',
      whereArgs: [appId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAppsForOwner(String ownerId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT * FROM micro_apps 
      WHERE ownerId = ? 
      GROUP BY appId 
      HAVING MAX(created_at)
      ORDER BY created_at DESC
    ''', [ownerId]);

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
