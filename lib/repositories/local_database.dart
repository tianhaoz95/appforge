import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _database;

  LocalDatabase._internal();

  factory LocalDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'appforge.db');

    return await openDatabase(
      path,
      version: 2,
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
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE micro_apps (
        appId TEXT PRIMARY KEY,
        ownerId TEXT,
        conversationId TEXT,
        name TEXT,
        html_blob TEXT,
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
        updated_at INTEGER
      )
    ''');
  }
}
