import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  const AuditLogEntry({required this.id, required this.data, this.cursor});

  final String id;
  final Map<String, dynamic> data;
  final Object? cursor;
}

abstract interface class AuditLogRepository {
  Stream<List<AuditLogEntry>> watchLatest(int limit);

  Future<List<AuditLogEntry>> fetchAfter(AuditLogEntry cursor, int limit);
}

class FirebaseAuditLogRepository implements AuditLogRepository {
  FirebaseAuditLogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AuditLogEntry>> watchLatest(int limit) => _query(
    limit,
  ).snapshots().map((snapshot) => snapshot.docs.map(_entry).toList());

  @override
  Future<List<AuditLogEntry>> fetchAfter(
    AuditLogEntry cursor,
    int limit,
  ) async {
    final document = cursor.cursor;
    if (document is! QueryDocumentSnapshot<Map<String, dynamic>>) {
      throw StateError('Không có cursor Firestore để tải trang tiếp theo.');
    }
    final page = await _query(limit).startAfterDocument(document).get();
    return page.docs.map(_entry).toList();
  }

  Query<Map<String, dynamic>> _query(int limit) => _firestore
      .collection('auditLogs')
      .orderBy('at', descending: true)
      .limit(limit);

  AuditLogEntry _entry(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      AuditLogEntry(id: doc.id, data: doc.data(), cursor: doc);
}
