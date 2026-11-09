import 'package:cloud_functions/cloud_functions.dart';

/// A server deadline is a normal race, not a stack trace to show the player.
/// Other failures may have an unknown outcome; the pending request retains its
/// requestId until it can be retried safely.
String betFailureNotice(Object error) {
  if (error is FirebaseFunctionsException) {
    if (error.code == 'failed-precondition' &&
        error.message?.contains('Đã khóa cược') == true) {
      return 'Đã khóa cược. Cược đã nhận vẫn được giữ.';
    }
    final reason = error.message?.split('\n').first.trim();
    if (reason != null && reason.isNotEmpty) {
      return 'Cược chưa được xác nhận: $reason';
    }
  }
  return 'Chưa xác nhận cược. Kiểm tra cược đã nhận trước khi thử lại.';
}
