import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class MicroAppRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  MicroAppRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> saveApp(Map<String, dynamic> appData) async {
    final appId = appData['appId'] ?? _uuid.v4();
    final data = {
      ...appData,
      'appId': appId,
      'created_at': appData['created_at'] ?? FieldValue.serverTimestamp(),
    };

    await _firestore.collection('micro_apps').doc(appId).set(data);
    return appId;
  }

  Future<Map<String, dynamic>?> getApp(String appId) async {
    final doc = await _firestore.collection('micro_apps').doc(appId).get();
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getAppsForOwner(String ownerId) async {
    final query = await _firestore
        .collection('micro_apps')
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('created_at', descending: true)
        .get();

    return query.docs.map((doc) => doc.data()).toList();
  }
}
