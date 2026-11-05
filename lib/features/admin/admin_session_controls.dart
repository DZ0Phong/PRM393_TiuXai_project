import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/currency_format.dart';
import '../game/game_specs.dart';
import '../game/round_bets.dart';
import 'round_outcome_picker.dart';

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

  final _reason = TextEditingController(
    text: 'Điều hành phiên mô phỏng trong lớp',
  );
  String _newSessionMode = 'random';
  String? _busyAction;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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

  String _number(int value) => formatCurrencyAmount(value);

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
          _resultConsole(roundId, round, status, deadline),
        ],
        if (active) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, time, _) => Theme(
              data: ThemeData.dark(useMaterial3: true),
              child: RoundBets(roundId: roundId, game: widget.game, now: time),
            ),
          ),
        ],
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

  Widget _resultConsole(
    String roundId,
    Map<String, dynamic> round,
    String status,
    Timestamp? deadline,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.doc('roundPlans/$roundId').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _error('Không tải được kết quả đã chọn: ${snapshot.error}');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator(color: _gold);
      final planned = snapshot.data!.data();
      return _surfaceCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CHỌN KẾT QUẢ • ADMIN',
              style: TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            if (planned != null) ...[
              Text(
                'Đã chọn: ${(planned['result'] as List?)?.join(' • ') ?? '—'}',
                style: const TextStyle(color: _green, fontSize: 11),
              ),
              const Text(
                'Đã ghi nhận một lần; server tự chốt sau khi cược hết giờ. Không thể đổi.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
            ] else if (status == 'open') ...[
              const Text(
                'Xem cược từng cửa rồi chọn kết quả bằng một nút. Lựa chọn chỉ được ghi nhận trước khi hết giờ cược.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
              const SizedBox(height: 7),
              _reasonInput(),
              ValueListenableBuilder<DateTime>(
                valueListenable: _now,
                builder: (context, time, _) => RoundOutcomePicker(
                  game: widget.game,
                  round: round,
                  enabled:
                      _busyAction == null &&
                      _validReason &&
                      deadline != null &&
                      deadline.toDate().isAfter(time),
                  onSelected: (choice) => _plan(roundId, choice.result),
                ),
              ),
            ] else
              const Text(
                'Đã hết hạn chọn kết quả; backend tự chốt ngẫu nhiên nếu chưa có lựa chọn.',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
          ],
        ),
      );
    },
  );

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
              'Tổng: ${_number(stake)} VNĐ',
            ),
          ),
        ],
      );
    },
  );

  Future<void> _plan(String roundId, List<dynamic> result) async {
    await _call('setRoundOutcome', {
      'roundId': roundId,
      'result': result,
      'reason': _reason.text.trim(),
    }, success: 'Đã lưu kết quả; chờ hết hạn cược để chốt.');
  }

  Future<void> _confirmCancel(String roundId) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Hủy phiên và hoàn cược?'),
        titleTextStyle: const TextStyle(color: _gold, fontSize: 20),
        contentTextStyle: const TextStyle(color: _muted, fontSize: 14),
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
                  'Chọn trước hạn',
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
