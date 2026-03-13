import 'dart:async';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;
  static String? _testPath;

  LocalDatabase._internal();

  factory LocalDatabase() => _instance;

  @visibleForTesting
  static void setTestPath(String path) {
    _testPath = path;
    _database = null;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (_testPath != null) {
      path = _testPath!;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, 'appforge.db');
    }

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add missing columns if upgrading from v1
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN conversationId TEXT');
      } catch (e) {
        // Column might already exist if dev environment was partially updated
      }
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN title TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE micro_app_data (
          appId TEXT,
          key TEXT,
          value TEXT,
          updated_at INTEGER,
          PRIMARY KEY (appId, key)
        )
      ''');
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN design_doc TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN enhancement_code TEXT');
        await db.execute('ALTER TABLE conversations ADD COLUMN enhancement_design TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN backend_blob TEXT');
        await db.execute('ALTER TABLE conversations ADD COLUMN enhancement_backend TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE micro_apps (
        appId TEXT PRIMARY KEY,
        ownerId TEXT,
        conversationId TEXT,
        name TEXT,
        html_blob TEXT,
        backend_blob TEXT,
        design_doc TEXT,
        version TEXT,
        icon TEXT,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE conversations (
        conversationId TEXT PRIMARY KEY,
        title TEXT,
        history TEXT,
        enhancement_code TEXT,
        enhancement_backend TEXT,
        enhancement_design TEXT,
        updated_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE micro_app_data (
        appId TEXT,
        key TEXT,
        value TEXT,
        updated_at INTEGER,
        PRIMARY KEY (appId, key)
      )
    ''');
  }
}
