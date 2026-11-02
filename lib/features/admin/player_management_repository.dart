import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerRecord {
  const PlayerRecord({required this.uid, required this.data, this.cursor});

  final String uid;
  final Map<String, dynamic> data;
  final Object? cursor;
}

abstract interface class PlayerManagementRepository {
  Stream<List<PlayerRecord>> watchLatest(int limit);

  Future<PlayerRecord?> getByUid(String uid);

  Future<List<PlayerRecord>> fetchAfter(PlayerRecord cursor, int limit);
}

class FirebasePlayerManagementRepository implements PlayerManagementRepository {
  FirebasePlayerManagementRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Query<Map<String, dynamic>> _query(int limit) => _firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(limit);

  PlayerRecord _record(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      PlayerRecord(uid: doc.id, data: doc.data(), cursor: doc);

  @override
  Stream<List<PlayerRecord>> watchLatest(int limit) => _query(
    limit,
  ).snapshots().map((snapshot) => snapshot.docs.map(_record).toList());

  @override
  Future<PlayerRecord?> getByUid(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return PlayerRecord(uid: doc.id, data: doc.data()!);
  }

  @override
  Future<List<PlayerRecord>> fetchAfter(PlayerRecord cursor, int limit) async {
    final document = cursor.cursor;
    if (document is! QueryDocumentSnapshot<Map<String, dynamic>>) {
      throw StateError('Không có cursor Firestore để tải trang tiếp theo.');
    }
    final page = await _query(limit).startAfterDocument(document).get();
    return page.docs.map(_record).toList();
  }
}
