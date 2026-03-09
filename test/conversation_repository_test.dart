import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:appforge/repositories/conversation_repository.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ConversationRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ConversationRepository(firestore: firestore);
  });

  test('Save and retrieve a conversation', () async {
    final conversationId = 'test_id';
    final history = [
      ChatMessage(origin: MessageOrigin.user, text: 'Hello', attachments: []),
      ChatMessage(origin: MessageOrigin.llm, text: 'Hi there!', attachments: []),
    ];

    await repository.saveConversation(conversationId, history);

    final retrievedHistory = await repository.getConversation(conversationId);
    
    expect(retrievedHistory.length, 2);
    expect(retrievedHistory[0].text, 'Hello');
    expect(retrievedHistory[1].text, 'Hi there!');
    expect(retrievedHistory[0].origin, MessageOrigin.user);
    expect(retrievedHistory[1].origin, MessageOrigin.llm);
  });
}
