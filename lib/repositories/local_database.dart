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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE micro_apps (
        appId TEXT PRIMARY KEY,
        ownerId TEXT,
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
        history TEXT,
        updated_at INTEGER
      )
    ''');
  }
}
