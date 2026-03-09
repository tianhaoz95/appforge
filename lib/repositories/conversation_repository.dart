import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

class ConversationRepository {
  final FirebaseFirestore _firestore;

  ConversationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> saveConversation(String conversationId, List<ChatMessage> history) async {
    final messages = history.map((m) => m.toJson()).toList();
    await _firestore.collection('conversations').doc(conversationId).set({
      'history': messages,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<ChatMessage>> getConversation(String conversationId) async {
    final doc = await _firestore.collection('conversations').doc(conversationId).get();
    if (!doc.exists) return [];

    final data = doc.data()!;
    final history = (data['history'] as List<dynamic>)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    
    return history;
  }
}
