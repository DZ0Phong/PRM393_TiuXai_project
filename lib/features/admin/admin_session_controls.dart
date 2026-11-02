import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../game/game_specs.dart';
import '../game/round_bets.dart';

class AdminSessionControls extends StatefulWidget {
  final GameSpec game;
  final Future<void> Function(String, Map<String, dynamic>) invoke;

  const AdminSessionControls({
    super.key,
    required this.game,
    required this.invoke,
  });

  @override
  State<AdminSessionControls> createState() => _AdminSessionControlsState();
}

class _AdminSessionControlsState extends State<AdminSessionControls> {
  static const _gold = Color(0xffffc174);
  static const _surface = Color(0xff191c22);
  static const _deep = Color(0xff0b0e14);
  static const _muted = Color(0xffd8c3ad);
  static const _green = Color(0xff56e5a9);

  final _reason = TextEditingController();
  List<dynamic> _result = [];
  String _newSessionMode = 'random';
  String? _busyAction;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _result = _defaultResult(widget.game);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _now.dispose();
    _reason.dispose();
    super.dispose();
  }

  List<dynamic> _defaultResult(GameSpec game) => switch (game.id) {
    'bau_cua' => ['nai', 'bau', 'ga'],
    'xoc_xoc' => [1, 0, 1, 0],
    _ => [3, 4, 4],
  };

  Future<void> _call(
    String action,
    Map<String, dynamic> data, {
    String? success,
  }) async {
    if (_busyAction != null) return;
    setState(() => _busyAction = action);
    try {
      await widget.invoke(action, data);
      if (mounted && success != null) _toast(success);
    } catch (error) {
      if (mounted) _toast('Không thực hiện được: $error', error: true);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xff8e2731)
            : const Color(0xff174b3c),
      ),
    );
  }

  int _totalStake(Map<String, dynamic> round) {
    final totals = round['totals'];
    if (totals is! Map) return 0;
    return totals.values.whereType<num>().fold(
      0,
      (runningTotal, value) => runningTotal + value.toInt(),
    );
  }

  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  String _preview() {
    if (widget.game.id == 'tai_xiu') {
      final dice = _result.cast<int>();
      final total = dice.fold<int>(
        0,
        (runningTotal, value) => runningTotal + value,
      );
      final triple = dice[0] == dice[1] && dice[1] == dice[2];
      return triple
          ? 'Tổng: $total • BỘ BA'
          : 'Tổng: $total • ${total >= 11 ? 'TÀI' : 'XỈU'}';
    }
    if (widget.game.id == 'bau_cua') {
      final names = {for (final side in widget.game.sides) side.$1: side.$2};
      return _result
          .map((value) => names[value] ?? value.toString())
          .join(' • ');
    }
    final red = _result.cast<int>().fold<int>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    return 'Có $red mặt đỏ • ${red.isEven ? 'CHẴN' : 'LẺ'}';
  }

  Widget _surfaceCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white.withValues(alpha: .055)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .doc('rooms/${widget.game.id}')
            .snapshots(includeMetadataChanges: true),
        builder: (context, roomSnapshot) {
          if (roomSnapshot.hasError) {
            return _error('Không tải được phòng: ${roomSnapshot.error}');
          }
          if (!roomSnapshot.hasData) {
            return const LinearProgressIndicator(color: _gold);
          }
          final roundId = roomSnapshot.data!.data()?['roundId'] as String?;
          if (roundId == null) return _noRound();
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey(roundId),
            stream: FirebaseFirestore.instance
                .doc('rounds/$roundId')
                .snapshots(includeMetadataChanges: true),
            builder: (context, roundSnapshot) {
              if (roundSnapshot.hasError) {
                return _error('Không tải được phiên: ${roundSnapshot.error}');
              }
              if (!roundSnapshot.hasData) {
                return const LinearProgressIndicator(color: _gold);
              }
              final round = roundSnapshot.data!.data();
              if (round == null) {
                return _error('Phiên không tồn tại hoặc đã bị xóa.');
              }
              if (round['game'] != widget.game.id) {
                return _error('Dữ liệu phiên không khớp trò chơi.');
              }
              return _sessionContent(roundId, round);
            },
          );
        },
      );

  Widget _sessionContent(String roundId, Map<String, dynamic> round) {
    final status = round['status']?.toString() ?? 'unknown';
    final adminMode = round['mode'] == 'admin';
    final deadline = _deadlineFor(round);
    final active = status == 'open' || status == 'locked';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle, color: Color(0xffb32638), size: 9),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'PHIÊN HIỆN TẠI',
                      style: TextStyle(
                        color: Color(0xffffb3ad),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  Text(
                    '#${roundId.length > 8 ? roundId.substring(0, 8).toUpperCase() : roundId.toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xffffddb8),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 7),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 9),
              _liveMetrics(roundId, round, status, deadline),
              const SizedBox(height: 9),
              SizedBox(
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: _busyAction != null || !active
                      ? null
                      : () => _confirmCancel(roundId),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xff272a31),
                    foregroundColor: const Color(0xffffb3ad),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                  ),
                  icon: const Icon(Icons.restart_alt, size: 15),
                  label: const Text(
                    'Hủy phiên & hoàn trả',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (active) ...[
          const SizedBox(height: 8),
          _resultConsole(roundId, status, adminMode),
        ],
        if (active) ...[const SizedBox(height: 8), RoundBets(roundId: roundId)],
        const SizedBox(height: 8),
        _newSessionCard(status),
        if (status == 'settled' && round['result'] is List)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Kết quả phiên: ${(round['result'] as List).join(' • ')}',
              style: const TextStyle(color: _green, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Timestamp? _deadlineFor(Map<String, dynamic> round) {
    final deadline = round['closesAt'];
    if (deadline is Timestamp) return deadline;
    final createdAt = round['createdAt'];
    if (createdAt is Timestamp) {
      return Timestamp.fromDate(
        createdAt.toDate().add(const Duration(seconds: 30)),
      );
    }
    return null;
  }

  Widget _metric(String label, String value, Color color, String detail) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: _deep,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 8),
            ),
          ],
        ),
      );

  Widget _resultConsole(String roundId, String status, bool adminMode) {
    final locked = status == 'locked';
    return _surfaceCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: _gold, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'NHẬP KẾT QUẢ PHIÊN • ADMIN',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                locked ? 'ĐÃ KHÓA' : 'CHỜ KHÓA',
                style: TextStyle(
                  color: locked ? _green : _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (locked && !adminMode) ...[
            const Text(
              'Phiên đang chờ máy chủ chốt. Tiếp quản để nhập kết quả thủ công.',
              style: TextStyle(color: _muted, fontSize: 9),
            ),
            const SizedBox(height: 7),
            _reasonInput(),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: FilledButton.icon(
                onPressed: _busyAction != null || !_validReason
                    ? null
                    : () => _call('interveneRound', {
                        'roundId': roundId,
                        'reason': _reason.text.trim(),
                      }, success: 'Đã tiếp quản phiên. Nhập kết quả để chốt.'),
                icon: const Icon(Icons.admin_panel_settings, size: 15),
                label: const Text(
                  'Tiếp quản kết quả',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ] else if (adminMode && (locked || status == 'open')) ...[
            _resultSelectors(),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _preview(),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _reasonInput(),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: FilledButton.icon(
                onPressed: _busyAction != null || !_validReason || !locked
                    ? null
                    : () => _settle(roundId),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff976414),
                  foregroundColor: const Color(0xffffe4ad),
                ),
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: Text(
                  locked
                      ? 'Chốt kết quả & trả thưởng'
                      : 'Chốt sau khi khóa cược',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            Text(
              adminMode
                  ? 'Chế độ ADMIN đã chọn. Nhập kết quả sau khi khóa cược.'
                  : 'Kết quả được máy chủ sinh ngẫu nhiên sau khi khóa cược.',
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
            const SizedBox(height: 6),
            _reasonInput(),
          ],
        ],
      ),
    );
  }

  bool get _validReason =>
      _reason.text.trim().length >= 5 && _reason.text.trim().length <= 300;

  Widget _reasonInput() => TextField(
    controller: _reason,
    maxLength: 300,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 10),
    decoration: InputDecoration(
      labelText: 'Lý do / biên bản chốt kết quả *',
      hintText: 'Nhập lý do từ 5 đến 300 ký tự',
      counterText: '${_reason.text.trim().length} / 300',
      labelStyle: const TextStyle(color: _muted, fontSize: 8),
      hintStyle: const TextStyle(color: _muted, fontSize: 8),
      counterStyle: const TextStyle(color: _muted, fontSize: 7),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
    ),
  );

  Widget _liveMetrics(
    String roundId,
    Map<String, dynamic> round,
    String status,
    Object? deadline,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('rounds/$roundId/bets')
        .snapshots(),
    builder: (context, snapshot) {
      final activeBets = snapshot.data?.docs.where((doc) {
        final amount = doc.data()['amount'];
        return amount is num && amount > 0;
      }).toList();
      final playerCount =
          activeBets?.length ?? (round['betCount'] as num?)?.toInt() ?? 0;
      final stake = activeBets == null
          ? _totalStake(round)
          : activeBets.fold<int>(0, (total, doc) {
              final amount = doc.data()['amount'];
              return total + (amount is num ? amount.toInt() : 0);
            });
      return Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<DateTime>(
              valueListenable: _now,
              builder: (context, time, _) {
                final remaining = deadline is Timestamp
                    ? deadline.toDate().difference(time).inSeconds
                    : null;
                return _metric(
                  'ĐẾM NGƯỢC CƯỢC',
                  remaining == null ? '—' : _clockText(remaining),
                  status == 'open' ? const Color(0xffffb3ad) : _muted,
                  status == 'open' ? 'Đang mở cược' : 'Đã khóa cược',
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metric(
              'NGƯỜI CƯỢC LIVE',
              snapshot.hasError ? '—' : '$playerCount',
              _gold,
              'Tổng: ${_number(stake)} TX',
            ),
          ),
        ],
      );
    },
  );

  Widget _resultSelectors() {
    final isBauCua = widget.game.id == 'bau_cua';
    final count = widget.game.id == 'xoc_xoc' ? 4 : 3;
    final options = isBauCua
        ? widget.game.sides
              .map((side) => (side.$1 as dynamic, side.$2))
              .toList()
        : (widget.game.id == 'xoc_xoc'
              ? [(0, 'Trắng'), (1, 'Đỏ')]
              : [
                  (1, 'Nhất'),
                  (2, 'Nhị'),
                  (3, 'Tam'),
                  (4, 'Tứ'),
                  (5, 'Ngũ'),
                  (6, 'Lục'),
                ]);
    return Row(
      children: [
        for (var index = 0; index < count; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Text(
                  isBauCua
                      ? 'Mặt ${index + 1}'
                      : widget.game.id == 'xoc_xoc'
                      ? 'Xu ${index + 1}'
                      : 'Xúc xắc ${index + 1}',
                  style: const TextStyle(color: _muted, fontSize: 7),
                ),
                const SizedBox(height: 3),
                DropdownButtonFormField<dynamic>(
                  key: ValueKey('${widget.game.id}-$index-${_result[index]}'),
                  initialValue: _result[index],
                  isExpanded: true,
                  dropdownColor: const Color(0xff272a31),
                  style: const TextStyle(color: _gold, fontSize: 9),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xff202329),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 7,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: [
                    for (final option in options)
                      DropdownMenuItem<dynamic>(
                        value: option.$1,
                        child: Text(
                          isBauCua ? option.$2 : '${option.$1} (${option.$2})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _result[index] = value);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _settle(String roundId) async {
    final result = widget.game.id == 'bau_cua'
        ? _result.cast<String>()
        : _result.cast<int>();
    await _call('settleRound', {
      'roundId': roundId,
      'result': result,
      'reason': _reason.text.trim(),
    }, success: 'Đã chốt kết quả và trả thưởng.');
  }

  Future<void> _confirmCancel(String roundId) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Hủy phiên và hoàn cược?'),
        content: const Text(
          'Backend sẽ hoàn lại cược đã ghi nhận cho người chơi trong phiên này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    if (!_validReason) {
      _toast('Nhập lý do hủy từ 5 đến 300 ký tự.', error: true);
      return;
    }
    await _call('cancelRound', {
      'roundId': roundId,
      'reason': _reason.text.trim(),
    }, success: 'Đã hủy phiên và hoàn cược.');
  }

  Widget _newSessionCard(String status) {
    final canStart = status == 'settled' || status == 'cancelled';
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: _gold, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'KHỞI TẠO PHIÊN MỚI',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '30 GIÂY',
                style: TextStyle(
                  color: canStart ? _green : _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Chế độ sinh kết quả:',
            style: TextStyle(color: _muted, fontSize: 8),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _modeOption(
                  'random',
                  'RANDOM',
                  'Máy chủ ngẫu nhiên',
                  Icons.shuffle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _modeOption(
                  'admin',
                  'ADMIN',
                  'Nhập tay sau khóa',
                  Icons.verified_user_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thời gian đặt cược\n30 giây theo backend',
                  style: TextStyle(color: _muted, fontSize: 8, height: 1.35),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: _busyAction != null || !canStart
                      ? null
                      : () => _call('startRound', {
                          'game': widget.game.id,
                          'mode': _newSessionMode,
                        }, success: 'Đã mở phiên mới.'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: const Color(0xff472a00),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 15),
                  label: Text(
                    canStart ? 'Mở phiên mới' : 'Chờ phiên kết thúc',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeOption(
    String mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _newSessionMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _newSessionMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xff32353c) : const Color(0xff202329),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? _gold.withValues(alpha: .35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _gold : _muted, size: 15),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? _gold : const Color(0xffe1e2eb),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'open'
        ? _green
        : status == 'locked'
        ? const Color(0xffffb3ad)
        : _muted;
    final label = switch (status) {
      'open' => 'MỞ',
      'locked' => 'KHÓA',
      'settled' => 'CHỐT',
      'cancelled' => 'HỦY',
      _ => status.toUpperCase(),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _clockText(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }

  Widget _noRound() => _surfaceCard(
    child: Column(
      children: [
        const Text(
          'Chưa có phiên hiện tại cho trò chơi này.',
          style: TextStyle(color: _muted, fontSize: 10),
        ),
        const SizedBox(height: 8),
        _newSessionCard('cancelled'),
      ],
    ),
  );

  Widget _error(String message) => Text(
    message,
    style: const TextStyle(color: Color(0xffffb4ab), fontSize: 10),
  );
}
