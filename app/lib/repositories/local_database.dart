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
      version: 13,
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
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN enhancement_app_id TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 8) {
      await db.transaction((txn) async {
        // 1. Create new table with composite primary key and release_notes column
        await txn.execute('''
          CREATE TABLE micro_apps_new (
            appId TEXT,
            ownerId TEXT,
            conversationId TEXT,
            name TEXT,
            html_blob TEXT,
            backend_blob TEXT,
            design_doc TEXT,
            release_notes TEXT,
            version TEXT,
            icon TEXT,
            created_at INTEGER,
            PRIMARY KEY (appId, version)
          )
        ''');

        // 2. Copy data from old table
        await txn.execute('''
          INSERT INTO micro_apps_new (
            appId, ownerId, conversationId, name, html_blob, backend_blob, 
            design_doc, version, icon, created_at
          )
          SELECT 
            appId, ownerId, conversationId, name, html_blob, backend_blob, 
            design_doc, version, icon, created_at
          FROM micro_apps
        ''');

        // 3. Drop old table
        await txn.execute('DROP TABLE micro_apps');

        // 4. Rename new table to original name
        await txn.execute('ALTER TABLE micro_apps_new RENAME TO micro_apps');
      });
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN periodic_backend_blob TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN enhancement_periodic_backend TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN is_pinned INTEGER DEFAULT 0');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN forge_mode INTEGER');
      } catch (e) {
        // Column might already exist
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE micro_apps ADD COLUMN screenshot_blob TEXT');
      } catch (e) {
        // Column might already exist
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE micro_apps (
        appId TEXT,
        ownerId TEXT,
        conversationId TEXT,
        name TEXT,
        html_blob TEXT,
        backend_blob TEXT,
        periodic_backend_blob TEXT,
        design_doc TEXT,
        release_notes TEXT,
        version TEXT,
        icon TEXT,
        screenshot_blob TEXT,
        created_at INTEGER,
        is_pinned INTEGER DEFAULT 0,
        PRIMARY KEY (appId, version)
      )
    ''');

    await db.execute('''
      CREATE TABLE conversations (
        conversationId TEXT PRIMARY KEY,
        title TEXT,
        history TEXT,
        enhancement_code TEXT,
        enhancement_backend TEXT,
        enhancement_periodic_backend TEXT,
        enhancement_design TEXT,
        enhancement_app_id TEXT,
        forge_mode INTEGER,
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
