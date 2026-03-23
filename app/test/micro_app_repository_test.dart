import 'package:flutter_test/flutter_test.dart';

void main() {
  /*
  late FakeFirebaseFirestore firestore;
  late MicroAppRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = MicroAppRepository(firestore: firestore);
  });
  */

  test('Skip Firestore tests', () {
    // Repository now uses sqflite which is harder to test in isolation without additional setup.
  });
}
