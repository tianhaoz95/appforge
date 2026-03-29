import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'local_database.dart';

class MicroAppRepository extends ChangeNotifier {
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
      'periodic_backend_blob': appData['periodic_backend_blob'],
      'design_doc': appData['design_doc'],
      'release_notes': appData['release_notes'],
      'version': appData['version'],
      'icon': appData['icon'],
      'screenshot_blob': appData['screenshot_blob'],
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

    await db.insert(
      'micro_apps',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
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
      WHERE (appId, created_at) IN (
        SELECT appId, MAX(created_at)
        FROM micro_apps
        WHERE ownerId = ?
        GROUP BY appId
      )
      ORDER BY is_pinned DESC, created_at DESC
    ''', [ownerId]);

    return maps;
  }

  Future<void> pinApp(String appId, bool pinned) async {
    final db = await _dbHelper.database;
    await db.update(
      'micro_apps',
      {'is_pinned': pinned ? 1 : 0},
      where: 'appId = ?',
      whereArgs: [appId],
    );
    notifyListeners();
  }

  Future<void> renameApp(String appId, String newName) async {
    final db = await _dbHelper.database;
    await db.update(
      'micro_apps',
      {'name': newName},
      where: 'appId = ?',
      whereArgs: [appId],
    );
    notifyListeners();
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
    notifyListeners();
  }

  Future<void> deleteApps(List<String> appIds) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in appIds) {
        batch.delete(
          'micro_apps',
          where: 'appId = ?',
          whereArgs: [id],
        );
        batch.delete(
          'micro_app_data',
          where: 'appId = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
    notifyListeners();
  }
}
