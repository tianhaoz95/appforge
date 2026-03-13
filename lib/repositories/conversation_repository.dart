import 'dart:convert';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'local_database.dart';
import 'package:sqflite/sqflite.dart';

class ConversationData {
  final List<ChatMessage> history;
  final String? enhancementCode;
  final String? enhancementBackend;
  final String? enhancementDesign;
  final String? enhancementAppId;

  ConversationData({
    required this.history, 
    this.enhancementCode, 
    this.enhancementBackend,
    this.enhancementDesign,
    this.enhancementAppId,
  });
}

class ConversationRepository {
  final LocalDatabase _dbHelper;

  ConversationRepository({LocalDatabase? dbHelper})
      : _dbHelper = dbHelper ?? LocalDatabase();

  Future<void> saveConversation(
    String conversationId,
    String title,
    List<ChatMessage> history, {
    String? enhancementCode,
    String? enhancementBackend,
    String? enhancementDesign,
    String? enhancementAppId,
  }) async {
    final db = await _dbHelper.database;
    final messages = history.map((m) => m.toJson()).toList();

    await db.insert(
      'conversations',
      {
        'conversationId': conversationId,
        'title': title,
        'history': jsonEncode(messages),
        'enhancement_code': enhancementCode,
        'enhancement_backend': enhancementBackend,
        'enhancement_design': enhancementDesign,
        'enhancement_app_id': enhancementAppId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await _dbHelper.database;
    return await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
  }

  Future<ConversationData> getConversation(String conversationId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );

    if (maps.isEmpty) {
      return ConversationData(history: []);
    }

    final data = maps.first;
    final historyJson = jsonDecode(data['history'] as String) as List<dynamic>;

    final history = historyJson
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();

    return ConversationData(
      history: history,
      enhancementCode: data['enhancement_code'] as String?,
      enhancementBackend: data['enhancement_backend'] as String?,
      enhancementDesign: data['enhancement_design'] as String?,
      enhancementAppId: data['enhancement_app_id'] as String?,
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'conversations',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
    );
  }
}
