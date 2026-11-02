import 'dart:convert';

const _auditAccentGroups = <String, String>{
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

String normalizeAuditSearch(String value) {
  final lower = value.toLowerCase();
  final normalized = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    var replacement = character;
    for (final group in _auditAccentGroups.entries) {
      if (group.value.contains(character)) {
        replacement = group.key;
        break;
      }
    }
    normalized.write(replacement);
  }
  return normalized.toString();
}

String auditCategoryForAction(String action) {
  if (action == 'INTERVENE_ROUND' || action == 'SETTLE') return 'round_result';
  if (action == 'ADJUST_BALANCE') return 'balance';
  if (action == 'CANCEL' ||
      action == 'TABLE_CANCEL' ||
      action == 'BET_REFUND') {
    return 'cancel';
  }
  if (action == 'BLOCK_PLAYER' || action == 'UNBLOCK_PLAYER') return 'account';
  if (action == 'BET') return 'bet';
  if (action == 'TABLE_BOT_CONFIG') return 'bot';
  if (action.startsWith('TABLE_')) return 'table';
  if (action == 'WELCOME') return 'system';
  return 'round';
}

bool auditMatchesCategory(String action, String category) =>
    category == 'all' || auditCategoryForAction(action) == category;

String auditSearchableText(String documentId, Map<String, dynamic> data) =>
    normalizeAuditSearch(
      '$documentId ${data['actor'] ?? ''} ${data['action'] ?? ''} '
      '${jsonEncode(data['details'] ?? {})}',
    );

bool auditMatchesSearch({
  required String documentId,
  required Map<String, dynamic> data,
  required String query,
}) {
  final normalizedQuery = normalizeAuditSearch(query.trim());
  return normalizedQuery.isEmpty ||
      auditSearchableText(documentId, data).contains(normalizedQuery);
}
