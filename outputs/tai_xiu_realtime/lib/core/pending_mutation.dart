import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMutationStore {
  String key(String uid) => 'pending_mutation_v1_$uid';
  Future<Map<String, dynamic>?> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final value = prefs.getString(key(uid));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> save(String uid, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(key(uid)) != null) {
      throw StateError('Có thao tác chờ chưa xác nhận; không ghi đè requestId');
    }
    if (!await prefs.setString(key(uid), jsonEncode(value))) {
      throw StateError('Không lưu được thao tác chờ; chưa gửi lên server');
    }
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(key(uid))) {
      throw StateError(
        'Không xóa được thao tác chờ; thử lại cùng requestId vẫn an toàn',
      );
    }
  }
}
