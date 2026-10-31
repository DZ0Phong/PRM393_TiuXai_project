import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push this screen with the signed-in UID, admin claim, and 'poker' or 'ba_cay'.
/// The parent configures Firebase and the Functions emulator before opening it.
class CardTableScreen extends StatefulWidget {
  final String uid;
  final bool isAdmin;
  final String game;

  const CardTableScreen({
    super.key,
    required this.uid,
    required this.isAdmin,
    required this.game,
  }) : assert(game == 'poker' || game == 'ba_cay');

  @override
  State<CardTableScreen> createState() => _CardTableScreenState();
}

class _CardTableScreenState extends State<CardTableScreen> {
  final _stake = TextEditingController(text: '100');
  final _tableInput = TextEditingController();
  final _reason = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  final _db = FirebaseFirestore.instance;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _waitingTables;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _table;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _hand;
  String? _tableId;
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;
  bool _botsEnabled = false;
  int _maxBots = 1;
  int _maxSeats = 2;
  Map<String, dynamic>? _pendingCreate;
  bool _pendingLoaded = false;
  String? _pendingLoadError;
  String get _createKey => 'card_create_v1_${widget.uid}_${widget.game}';

  @override
  void initState() {
    super.initState();
    _listenForTables();
    _loadPendingCreate();
  }

  @override
  void didUpdateWidget(covariant CardTableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game != widget.game || oldWidget.uid != widget.uid) {
      _listenForTables();
      _tableId = null;
      _table = null;
      _hand = null;
      _tableInput.clear();
      _pendingCreate = null;
      _pendingLoaded = false;
      _loadPendingCreate();
    }
  }

  void _listenForTables() {
    // Filter status locally: only the game field needs a Firestore query index.
    _waitingTables = _db
        .collection('cardTables')
        .where('game', isEqualTo: widget.game)
        .snapshots(includeMetadataChanges: true);
  }

  Future<void> _loadPendingCreate() async {
    final key = _createKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final saved = prefs.getString(key);
      final data = saved == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (data != null &&
          (data['game'] != widget.game ||
              data['stake'] is! int ||
              (data['stake'] as int) < 10 ||
              (data['stake'] as int) > 100 ||
              data['maxSeats'] is! int ||
              (data['maxSeats'] as int) < 2 ||
              (data['maxSeats'] as int) > 6 ||
              data['requestId'] is! String ||
              (data['requestId'] as String).length < 8 ||
              (data['requestId'] as String).length > 80 ||
              !_validId(data['requestId'] as String))) {
        throw const FormatException('Thao tác tạo bàn lưu tạm không hợp lệ.');
      }
      if (mounted && key == _createKey) {
        setState(() {
          _pendingCreate = data;
          _pendingLoaded = true;
          _pendingLoadError = null;
        });
      }
    } catch (error) {
      if (mounted && key == _createKey) {
        setState(() {
          _pendingLoaded = false;
          _pendingLoadError = 'Không đọc được thao tác tạo bàn: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _stake.dispose();
    _tableInput.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _openTable(String id) {
    _tableId = id;
    _table = _db.doc('cardTables/$id').snapshots(includeMetadataChanges: true);
    _hand = _db
        .doc('cardTables/$id/hands/${widget.uid}')
        .snapshots(includeMetadataChanges: true);
    _botsEnabled = false;
    _maxBots = 1;
    _reason.clear();
  }

  bool _validId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id);

  void _openTypedTable() {
    final id = _tableInput.text.trim();
    if (_busy) return;
    if (!_validId(id)) {
      setState(() {
        _message = 'Nhập mã bàn hợp lệ (chữ, số, _ hoặc -).';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _openTable(id);
      _message = null;
    });
  }

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? 'Máy chủ từ chối (${error.code}).';
    }
    if (error is FirebaseException) {
      return error.message ?? 'Không đọc được dữ liệu (${error.code}).';
    }
    if (error is FormatException || error is StateError) return '$error';
    return 'Không kết nối được. Kiểm tra mạng rồi thử lại: $error';
  }

  Future<void> _call(
    String name,
    Map<String, dynamic> data, {
    void Function(dynamic)? onSuccess,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await _functions.httpsCallable(name).call(data);
      if (!mounted) return;
      onSuccess?.call(response.data);
      setState(() {
        _message = 'Thao tác đã được máy chủ xác nhận.';
        _messageIsError = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _errorText(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy || !_pendingLoaded) return;
    final stake = int.tryParse(_stake.text.trim());
    if (_pendingCreate == null &&
        (stake == null || stake < 10 || stake > 100)) {
      setState(() {
        _message = 'Nhập mức ante từ 10 đến 100 xu ảo.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingCreate == null) {
        // Save before sending: a timeout may hide a successfully created table.
        await prefs.reload();
        if (prefs.getString(_createKey) != null) {
          throw StateError(
            'Có yêu cầu tạo bàn cũ; tải lại để thử đúng requestId.',
          );
        }
        final intent = <String, dynamic>{
          'game': widget.game,
          'stake': stake,
          'maxSeats': _maxSeats,
          'requestId': 'card_${_db.collection('cardTables').doc().id}',
        };
        if (!await prefs.setString(_createKey, jsonEncode(intent))) {
          throw StateError(
            'Không lưu được yêu cầu tạo bàn; chưa gửi lên máy chủ.',
          );
        }
        _pendingCreate = intent;
      }
      final response = await _functions
          .httpsCallable('createCardTable')
          .call(_pendingCreate);
      final data = response.data;
      final id = data is Map ? data['tableId'] : null;
      if (id is! String || !_validId(id)) {
        throw const FormatException('Máy chủ không trả về mã bàn hợp lệ.');
      }
      if (!await prefs.remove(_createKey)) {
        throw StateError(
          'Đã tạo bàn nhưng không xóa được yêu cầu chờ; thử lại cùng requestId.',
        );
      }
      _pendingCreate = null;
      if (mounted) {
        setState(() {
          _openTable(id);
          _message = 'Đã tạo bàn $id.';
          _messageIsError = false;
        });
      }
    } catch (error) {
      // Only a definite server rejection can free the key for a new intent.
      if (error is FirebaseFunctionsException &&
          const {
            'invalid-argument',
            'failed-precondition',
            'permission-denied',
            'unauthenticated',
          }.contains(error.code)) {
        try {
          final prefs = await SharedPreferences.getInstance();
          if (await prefs.remove(_createKey)) _pendingCreate = null;
        } catch (_) {
          // Keep the same requestId if local cleanup fails.
        }
      }
      if (mounted) {
        setState(() {
          _message = _errorText(error);
          _messageIsError = true;
        });
        if (_pendingCreate == null) {
          setState(() => _pendingLoaded = false);
          await _loadPendingCreate();
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _join(String id, {bool openAfterJoin = false}) {
    _call(
      'joinCardTable',
      {'tableId': id},
      onSuccess: (_) {
        if (openAfterJoin) _openTable(id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.game == 'poker' ? 'Poker' : 'Ba Cây';
    return Scaffold(
      appBar: AppBar(
        title: Text('Bàn $title'),
        actions: [
          if (_tableId != null)
            IconButton(
              tooltip: 'Danh sách bàn',
              icon: const Icon(Icons.list_alt_outlined),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _tableId = null;
                      _table = null;
                      _hand = null;
                      _message = null;
                    }),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'CHỈ XU ẢO • Điểm ảo không phải tiền thật, không nạp/rút '
                    'và không có giải thưởng.',
                  ),
                ),
              ),
              if (widget.game == 'poker')
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Poker: ante và cược giới hạn cố định; máy chủ quyết định lượt và mức cược.',
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Ba Cây: góp ante, chia bài rồi so điểm ngay; không có lượt cược.',
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _messageIsError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (_tableId == null) _lobby() else _tableView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lobby() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tạo bàn', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _stake,
                enabled: _pendingCreate == null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ante (10–100 xu ảo)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _maxSeats,
                decoration: const InputDecoration(
                  labelText: 'Số ghế tối đa',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var count = 2; count <= 6; count++)
                    DropdownMenuItem(value: count, child: Text('$count ghế')),
                ],
                onChanged: _busy || _pendingCreate != null
                    ? null
                    : (value) => setState(() => _maxSeats = value!),
              ),
              const SizedBox(height: 12),
              if (_pendingLoadError != null) Text(_pendingLoadError!),
              if (!_pendingLoaded)
                TextButton(
                  onPressed: _busy ? null : _loadPendingCreate,
                  child: const Text('Tải lại yêu cầu chờ'),
                ),
              if (_pendingCreate != null)
                Text(
                  'Yêu cầu chờ: ${_pendingCreate!['stake']} xu ảo • '
                  '${_pendingCreate!['maxSeats']} ghế. '
                  'Thử lại cùng requestId, không tạo yêu cầu mới.',
                ),
              FilledButton.icon(
                onPressed: _busy || !_pendingLoaded ? null : _create,
                icon: const Icon(Icons.add),
                label: Text(
                  _pendingCreate == null ? 'Tạo bàn' : 'Thử lại tạo bàn',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tableInput,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _openTypedTable(),
        decoration: InputDecoration(
          labelText: 'Mã bàn được mời',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: 'Mở bàn theo mã',
            onPressed: _openTypedTable,
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text('Bàn đang chờ', style: Theme.of(context).textTheme.titleLarge),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _waitingTables,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Không tải được danh sách bàn: ${_errorText(snapshot.error!)}',
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final offline = snapshot.data!.metadata.isFromCache;
          final tables = snapshot.data!.docs.where(
            (doc) => doc.data()['status'] == 'waiting',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (offline)
                const Text(
                  'Danh sách lưu tạm (ngoại tuyến); hãy kết nối lại để tham gia.',
                ),
              if (tables.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Chưa có bàn nào đang chờ.'),
                ),
              for (final doc in tables)
                Card(
                  child: ListTile(
                    title: Text('Bàn ${doc.id}'),
                    subtitle: Text(
                      '${doc.data()['stake'] ?? '—'} xu ảo • '
                      '${_seats(doc.data()).length}/${doc.data()['maxSeats'] ?? '—'} ghế',
                    ),
                    onTap: _busy
                        ? null
                        : () => setState(() => _openTable(doc.id)),
                    trailing: TextButton(
                      onPressed: _busy || offline
                          ? null
                          : () => _join(doc.id, openAfterJoin: true),
                      child: const Text('Tham gia'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _tableView() => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _table,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text('Không tải được bàn: ${_errorText(snapshot.error!)}');
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final table = snapshot.data!.data();
      if (table == null) {
        return const Text('Không tìm thấy bàn hoặc bạn không có quyền xem.');
      }
      if (table['game'] != widget.game) {
        return const Text('Bàn này thuộc trò chơi khác.');
      }
      final id = _tableId!;
      final offline = snapshot.data!.metadata.isFromCache;
      final status = table['status']?.toString() ?? 'không rõ';
      final seats = _seats(table);
      final seated = seats.any((seat) => seat['uid'] == widget.uid);
      final waiting = status == 'waiting';
      final playing = status == 'playing';
      final maxSeats = table['maxSeats'] is int ? table['maxSeats'] as int : 2;
      final canAct = !_busy && !offline;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (offline)
            const Text(
              'Đang xem dữ liệu lưu tạm; cần kết nối mạng để thao tác.',
            ),
          SelectableText(
            'Mã bàn: $id',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            'Trạng thái: $status • ${table['stake'] ?? '—'} xu ảo • '
            '${seats.length}/$maxSeats ghế',
          ),
          if (playing)
            Text(
              'Vòng: ${table['street'] ?? '—'} • Pot: ${table['pot'] ?? '—'} xu ảo',
            ),
          const SizedBox(height: 8),
          Text('Người chơi', style: Theme.of(context).textTheme.titleMedium),
          if (seats.isEmpty) const Text('Bàn chưa có người chơi.'),
          for (final seat in seats)
            ListTile(
              dense: true,
              leading: Icon(
                seat['isBot'] == true
                    ? Icons.smart_toy_outlined
                    : Icons.person_outline,
              ),
              title: Text('${seat['nickname'] ?? seat['uid'] ?? 'Ghế trống'}'),
              subtitle: Text(
                '${seat['stack'] ?? '—'} xu ảo'
                '${seat['uid'] == widget.uid ? ' • Bạn' : ''}'
                '${seat['uid'] == table['turnUid'] && playing ? ' • Đến lượt' : ''}',
              ),
            ),
          if (waiting && !seated && seats.length < maxSeats)
            FilledButton(
              onPressed: canAct ? () => _join(id) : null,
              child: const Text('Tham gia bàn'),
            ),
          if (waiting && (table['ownerUid'] == widget.uid || widget.isAdmin))
            FilledButton.icon(
              onPressed: canAct
                  ? () => _call('startCardHand', {'tableId': id})
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu ván'),
            ),
          if (waiting && seated)
            OutlinedButton(
              onPressed: canAct
                  ? () => _call(
                      'leaveCardTable',
                      {'tableId': id},
                      onSuccess: (_) {
                        _tableId = null;
                        _table = null;
                        _hand = null;
                      },
                    )
                  : null,
              child: const Text('Rời bàn'),
            ),
          if (widget.isAdmin && waiting) ...[
            Text(
              'Đang lưu: ${table['botsEnabled'] == true ? 'bật' : 'tắt'} bot • tối đa ${table['maxBots'] ?? 0}',
            ),
            _botControls(id, maxSeats, canAct),
          ],
          if (widget.isAdmin && (waiting || playing))
            _cancelControls(id, canAct),
          const Divider(height: 32),
          Text('Bài chung', style: Theme.of(context).textTheme.titleMedium),
          _cards(table['board']),
          if (seated && (playing || status == 'settled')) ...[
            const SizedBox(height: 12),
            Text(
              'Bài riêng của bạn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _hand,
              builder: (context, hand) {
                if (hand.hasError) {
                  return Text(
                    'Không tải được bài riêng: ${_errorText(hand.error!)}',
                  );
                }
                if (!hand.hasData) return const LinearProgressIndicator();
                if (hand.data!.metadata.isFromCache) {
                  return const Text(
                    'Bài riêng đang lưu tạm; chờ kết nối để xác nhận.',
                  );
                }
                final cards = hand.data!.data()?['cards'];
                return cards == null
                    ? const Text('Đang chờ chia bài…')
                    : _cards(cards);
              },
            ),
          ],
          if (playing &&
              widget.game == 'poker' &&
              seated &&
              table['turnUid'] == widget.uid) ...[
            const SizedBox(height: 12),
            Text(
              'Lượt của bạn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (table['actionVersion'] is! int)
              const Text('Đang chờ phiên bản lượt từ máy chủ.'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in const [
                  'check',
                  'bet',
                  'call',
                  'raise',
                  'fold',
                ])
                  FilledButton.tonal(
                    onPressed: canAct && table['actionVersion'] is int
                        ? () => _call('cardAction', {
                            'tableId': id,
                            'type': action,
                            'version': table['actionVersion'] as int,
                          })
                        : null,
                    child: Text(
                      {
                        'check': 'Check',
                        'bet': 'Bet',
                        'call': 'Call',
                        'raise': 'Raise',
                        'fold': 'Fold',
                      }[action]!,
                    ),
                  ),
              ],
            ),
          ],
          if (status == 'settled') ...[
            const Divider(height: 32),
            Text('Kết quả', style: Theme.of(context).textTheme.titleMedium),
            Text('Người thắng: ${_winners(table['winners'])}'),
            Text('Pot: ${table['pot'] ?? '—'} xu ảo'),
          ],
          if (status == 'cancelled')
            const Text('Bàn đã hủy; kết quả/số dư do máy chủ xử lý.'),
        ],
      );
    },
  );

  Widget _botControls(String id, int maxSeats, bool canAct) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin • Bot', style: Theme.of(context).textTheme.titleMedium),
          SwitchListTile(
            title: const Text('Bật bot'),
            value: _botsEnabled,
            onChanged: canAct
                ? (value) => setState(() => _botsEnabled = value)
                : null,
          ),
          DropdownButtonFormField<int>(
            // Clamp local draft if a different table has fewer seats.
            initialValue: _maxBots.clamp(0, maxSeats > 1 ? maxSeats - 1 : 1),
            decoration: const InputDecoration(labelText: 'Số bot tối đa'),
            items: [
              for (var count = 0; count < maxSeats; count++)
                DropdownMenuItem(value: count, child: Text('$count')),
            ],
            onChanged: canAct
                ? (value) => setState(() => _maxBots = value!)
                : null,
          ),
          FilledButton.tonal(
            onPressed: canAct
                ? () => _call('configureCardBots', {
                    'tableId': id,
                    'enabled': _botsEnabled,
                    'maxBots': _botsEnabled
                        ? _maxBots.clamp(0, maxSeats - 1)
                        : 0,
                  })
                : null,
            child: const Text('Lưu cấu hình bot'),
          ),
        ],
      ),
    ),
  );

  Widget _cancelControls(String id, bool canAct) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin • Hủy bàn',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextField(
            controller: _reason,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Lý do hủy (5–300 ký tự)',
              border: OutlineInputBorder(),
            ),
          ),
          OutlinedButton(
            onPressed: canAct
                ? () {
                    final reason = _reason.text.trim();
                    if (reason.length < 5 || reason.length > 300) {
                      setState(() {
                        _message = 'Nhập lý do từ 5 đến 300 ký tự.';
                        _messageIsError = true;
                      });
                      return;
                    }
                    _call('cancelCardTable', {'tableId': id, 'reason': reason});
                  }
                : null,
            child: const Text('Hủy bàn'),
          ),
        ],
      ),
    ),
  );
}

List<Map> _seats(Map<String, dynamic> table) {
  final raw = table['seats'];
  return raw is List ? raw.whereType<Map>().toList() : const [];
}

Widget _cards(Object? value) {
  final cards = value is List ? value : const [];
  if (cards.isEmpty) return const Text('Chưa có bài được công bố.');
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final card in cards) Chip(label: Text(_cardLabel(card)))],
  );
}

String _cardLabel(Object? value) {
  if (value is! String || !RegExp(r'^(10|[2-9TJQKA])[CDHS]$').hasMatch(value)) {
    return '🂠';
  }
  final suit = const {
    'C': '♣',
    'D': '♦',
    'H': '♥',
    'S': '♠',
  }[value.substring(value.length - 1)];
  final rank = value.substring(0, value.length - 1);
  return '${rank == 'T' ? '10' : rank}$suit';
}

String _winners(Object? value) {
  if (value is List) {
    if (value.isEmpty) return 'Chưa có';
    return value
        .map((winner) {
          if (winner is Map) {
            return '${winner['nickname'] ?? winner['uid'] ?? 'Người chơi'}';
          }
          return '$winner';
        })
        .join(', ');
  }
  if (value is Map) {
    if (value.isEmpty) return 'Chưa có';
    return value.keys.join(', ');
  }
  return 'Chưa có';
}
