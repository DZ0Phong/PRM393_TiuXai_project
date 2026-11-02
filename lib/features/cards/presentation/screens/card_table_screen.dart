import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/card_table_widgets.dart';
import '../widgets/ba_cay/ba_cay_arena_view.dart';

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
  final _raise = TextEditingController(text: '100');
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
  bool _showHoleCards = true;
  bool _botsInCreateDraft = false;
  int _createBotCount = 1;
  bool _showMoreFinished = false;
  final _createPanelKey = GlobalKey();
  bool _busy = false;
  bool _botsEnabled = false;
  int _maxBots = 1;
  bool _botConfigLoaded = false;
  String? _botConfigError;
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
              (data['botsEnabled'] != null && data['botsEnabled'] is! bool) ||
              (data['maxBots'] != null &&
                  (data['maxBots'] is! int ||
                      (data['maxBots'] as int) < 0 ||
                      (data['maxBots'] as int) >
                          (data['maxSeats'] as int) - 1)) ||
              !_validId(data['requestId'] as String))) {
        throw const FormatException('Thao tác tạo bàn lưu tạm không hợp lệ.');
      }
      if (mounted && key == _createKey) {
        setState(() {
          _pendingCreate = data;
          _pendingLoaded = true;
          _pendingLoadError = null;
          if (data != null) {
            _maxSeats = data['maxSeats'] as int;
            _botsInCreateDraft = widget.isAdmin && data['botsEnabled'] == true;
            final savedBotCount = data['maxBots'];
            _createBotCount = _botsInCreateDraft && savedBotCount is int
                ? savedBotCount.clamp(1, _maxSeats - 1).toInt()
                : 1;
          }
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
    _raise.dispose();
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
    _botConfigLoaded = false;
    _botConfigError = null;
    _reason.clear();
    if (widget.isAdmin) _loadBotConfig(id);
  }

  Future<void> _loadBotConfig(String tableId) async {
    try {
      final response = await _functions.httpsCallable('getCardBotConfig').call({
        'tableId': tableId,
      });
      if (!mounted || _tableId != tableId) return;
      final config = response.data;
      if (config is! Map ||
          config['maxBots'] is! int ||
          config['botsEnabled'] is! bool) {
        throw const FormatException('Cấu hình bot không hợp lệ.');
      }
      setState(() {
        _botsEnabled = config['botsEnabled'] as bool;
        _maxBots = config['maxBots'] as int;
        _botConfigLoaded = true;
        _botConfigError = null;
      });
    } catch (error) {
      if (!mounted || _tableId != tableId) return;
      setState(() {
        _botConfigLoaded = false;
        _botConfigError = _errorText(error);
      });
    }
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
          'botsEnabled': widget.isAdmin && _botsInCreateDraft,
          'maxBots': widget.isAdmin && _botsInCreateDraft
              ? _createBotCount.clamp(1, _maxSeats - 1).toInt()
              : 0,
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
      String? botSetupError;
      final createIntent = _pendingCreate!;
      if (widget.isAdmin && createIntent['botsEnabled'] == true) {
        try {
          await _functions.httpsCallable('configureCardBots').call({
            'tableId': id,
            'enabled': true,
            'maxBots': createIntent['maxBots'],
          });
        } catch (error) {
          // The table is already created. Open it so the admin can retry the
          // bot setup from the table controls without losing the table ID.
          botSetupError = _errorText(error);
        }
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
          _message = botSetupError == null
              ? 'Đã tạo bàn $id${createIntent['botsEnabled'] == true ? ' và thêm bot.' : '.'}'
              : 'Đã tạo bàn $id nhưng chưa thêm được bot: $botSetupError';
          _messageIsError = botSetupError != null;
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
    final pokerTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffffc174),
        brightness: Brightness.dark,
        surface: const Color(0xff10131a),
      ),
      scaffoldBackgroundColor: const Color(0xff10131a),
      cardTheme: CardThemeData(
        color: const Color(0xff272a31),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff0b0e14),
        foregroundColor: Color(0xffe1e2eb),
      ),
    );
    return Theme(
      data: widget.game == 'poker' || widget.game == 'ba_cay'
          ? pokerTheme
          : Theme.of(context),
      child: Scaffold(
        backgroundColor: widget.game == 'poker' || widget.game == 'ba_cay'
            ? const Color(0xff10131a)
            : null,
        appBar: AppBar(
          backgroundColor: widget.game == 'poker' || widget.game == 'ba_cay'
              ? const Color(0xff0b0e14)
              : null,
          foregroundColor: widget.game == 'poker' || widget.game == 'ba_cay'
              ? const Color(0xffe1e2eb)
              : null,
          title: Text('Bàn $title'),
          actions: [
            if (widget.game == 'poker')
              IconButton(
                tooltip: 'Tạo bàn',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  final target = _createPanelKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
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
        bottomNavigationBar: widget.game == 'poker' || widget.game == 'ba_cay'
            ? NavigationBar(
                backgroundColor: const Color(0xff0b0e14),
                indicatorColor: const Color(0x33ffc174),
                selectedIndex: 1,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.view_carousel),
                    label: 'Lobby',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.style),
                    label: 'Arena',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.analytics),
                    label: 'Cầu Road',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.military_tech),
                    label: 'VIP Vault',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings),
                    label: 'Rank',
                  ),
                ],
                onDestinationSelected: (index) {
                  if (index == 0) {
                    Navigator.of(context).maybePop();
                  }
                  if (index > 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mục này đang ở chế độ giao diện xu ảo.'),
                      ),
                    );
                  }
                },
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.game == 'poker') ...[
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _db.doc('users/${widget.uid}').snapshots(),
                    builder: (context, snapshot) {
                      final user = snapshot.data?.data();
                      final balance = user?['balance'];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xff0b0e14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xff534434)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 17,
                              backgroundColor: Color(0xffffc174),
                              child: Icon(
                                Icons.person,
                                color: Color(0xff472a00),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${user?['nickname'] ?? 'Người chơi'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xffd8c3ad),
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    'Số dư ${balance ?? '—'} TX ảo',
                                    style: const TextStyle(
                                      color: Color(0xffffc174),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.monetization_on,
                              color: Color(0xffffc174),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff191c22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xff534434)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0x33ffc174),
                          child: Icon(Icons.casino, color: Color(0xffffc174)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LIVE TABLE • TIUXAI ARENA',
                                style: TextStyle(
                                  color: Color(0xffffc174),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                'Đấu Trường Quý Tộc',
                                style: TextStyle(
                                  color: Color(0xffe1e2eb),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Sảnh Poker TiuXai • xu ảo',
                                style: TextStyle(
                                  color: Color(0xffd8c3ad),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Thiết lập bàn mới',
                          onPressed: () {
                            final target = _createPanelKey.currentContext;
                            if (target != null) {
                              Scrollable.ensureVisible(
                                target,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.add_circle,
                            color: Color(0xffffc174),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (widget.game != 'ba_cay' || _tableId == null)
                  Card(
                    color: widget.game == 'poker'
                        ? const Color(0xff191c22)
                        : null,
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
      ),
    );
  }

  Widget _lobby() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Card(
        key: widget.game == 'poker' ? _createPanelKey : null,
        color: widget.game == 'poker' ? const Color(0xff272a31) : null,
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
                onChanged: widget.game == 'poker'
                    ? (_) => setState(() {})
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Ante (10–100 xu ảo)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.game == 'poker') ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mức cược Ante',
                        style: TextStyle(color: Color(0xffd8c3ad)),
                      ),
                    ),
                    Text(
                      '${int.tryParse(_stake.text) ?? 10} TX',
                      style: const TextStyle(
                        color: Color(0xffffc174),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: (int.tryParse(_stake.text) ?? 10)
                      .clamp(10, 100)
                      .toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 90,
                  activeColor: const Color(0xffffc174),
                  onChanged: _busy || _pendingCreate != null
                      ? null
                      : (value) => setState(
                          () => _stake.text = value.round().toString(),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xff191c22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        color: Color(0xffffc174),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mức mua vào (10 × Ante)',
                          style: TextStyle(
                            color: Color(0xffd8c3ad),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${(int.tryParse(_stake.text) ?? 10) * 10} TX',
                        style: const TextStyle(
                          color: Color(0xffffc174),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.game == 'poker') ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Số lượng ghế • $_maxSeats ghế',
                    style: const TextStyle(
                      color: Color(0xffd8c3ad),
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 2, label: Text('2P')),
                    ButtonSegment(value: 4, label: Text('4P')),
                    ButtonSegment(value: 6, label: Text('6P')),
                  ],
                  selected: {
                    _maxSeats == 2
                        ? 2
                        : _maxSeats == 4
                        ? 4
                        : 6,
                  },
                  onSelectionChanged: _busy || _pendingCreate != null
                      ? null
                      : (values) => setState(() {
                          _maxSeats = values.first;
                          _createBotCount = _createBotCount
                              .clamp(1, _maxSeats - 1)
                              .toInt();
                        }),
                ),
              ] else
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
                      : (value) => setState(() {
                          _maxSeats = value!;
                          _createBotCount = _createBotCount
                              .clamp(1, _maxSeats - 1)
                              .toInt();
                        }),
                ),
              if (widget.isAdmin) _createBotControls(),
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
      Text('Bàn Chờ Đang Mở', style: Theme.of(context).textTheme.titleLarge),
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
          final tables = snapshot.data!.docs
              .where((doc) => doc.data()['status'] == 'waiting')
              .toList();
          final finished =
              snapshot.data!.docs
                  .where((doc) => doc.data()['status'] == 'settled')
                  .toList()
                ..sort((a, b) {
                  final x =
                      (a.data()['settledAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  final y =
                      (b.data()['settledAt'] as Timestamp?)
                          ?.millisecondsSinceEpoch ??
                      0;
                  return y.compareTo(x);
                });
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
                  color: widget.game == 'poker'
                      ? const Color(0xff272a31)
                      : null,
                  child: ListTile(
                    title: Text('Bàn ${doc.id}'),
                    subtitle: Text(
                      '${doc.data()['stake'] ?? '—'} xu ảo • '
                      '${cardSeats(doc.data()).length}/${doc.data()['maxSeats'] ?? '—'} ghế',
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
              const SizedBox(height: 18),
              Text(
                'Lịch Sử 10 Ván Gần Nhất • ${finished.length} bàn đã hoàn tất',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final doc in finished.take(_showMoreFinished ? 10 : 4))
                ListTile(
                  dense: true,
                  title: Text('Bàn ${doc.id}'),
                  subtitle: Text(
                    'Thắng: ${cardWinners(doc.data()['winners'])} • ${doc.data()['stake'] ?? '—'} xu',
                  ),
                  onTap: () => setState(() => _openTable(doc.id)),
                ),
              if (finished.length > 4)
                Center(
                  child: TextButton(
                    onPressed: () =>
                        setState(() => _showMoreFinished = !_showMoreFinished),
                    child: Text(
                      _showMoreFinished
                          ? 'Thu Gọn Lịch Sử'
                          : 'Xem Thêm 6 Ván Trước Đó',
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
      final seats = cardSeats(table);
      final seated = seats.any((seat) => seat['uid'] == widget.uid);
      final waiting = status == 'waiting';
      final playing = status == 'playing';
      final maxSeats = table['maxSeats'] is int ? table['maxSeats'] as int : 2;
      final canAct = !_busy && !offline;
      if (widget.game == 'ba_cay') {
        return _baCayTableView(
          id: id,
          table: table,
          seats: seats,
          status: status,
          maxSeats: maxSeats,
          seated: seated,
          waiting: waiting,
          offline: offline,
          canAct: canAct,
        );
      }
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
          if (playing && widget.game == 'poker')
            PokerFeltTable(
              seats: seats,
              board: table['board'],
              pot: table['pot'],
              turnUid: table['turnUid'],
              myUid: widget.uid,
              street: '${table['street'] ?? 'Preflop'}',
            ),
          if (!playing || widget.game != 'poker') ...[
            Text('Người chơi', style: Theme.of(context).textTheme.titleMedium),
            if (seats.isEmpty) const Text('Bàn chưa có người chơi.'),
            for (final seat in seats)
              ListTile(
                dense: true,
                leading: Icon(Icons.person_outline),
                title: Text(
                  '${seat['nickname'] ?? seat['uid'] ?? 'Ghế trống'}',
                ),
                subtitle: Text(
                  '${seat['stack'] ?? '—'} xu ảo'
                  '${seat['uid'] == widget.uid ? ' • Bạn' : ''}'
                  '${seat['uid'] == table['turnUid'] && playing ? ' • Đến lượt' : ''}',
                ),
              ),
          ],
          if (waiting && !seated && seats.length < maxSeats)
            FilledButton(
              onPressed: canAct ? () => _join(id) : null,
              child: const Text('Tham gia bàn'),
            ),
          if (waiting && seats.length < 2)
            const Text('Cần thêm ít nhất một người hoặc bot để bắt đầu.'),
          if (waiting && (table['ownerUid'] == widget.uid || widget.isAdmin))
            FilledButton.icon(
              onPressed: canAct && seats.length >= 2
                  ? () => _call('startCardHand', {'tableId': id})
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(
                seats.length >= 2 ? 'Bắt đầu ván' : 'Chờ thêm người hoặc bot',
              ),
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
              _botConfigLoaded
                  ? 'Cấu hình riêng của admin đã tải.'
                  : 'Đang tải cấu hình bot riêng của admin…',
            ),
            _botControls(id, maxSeats, canAct),
          ],
          if (widget.isAdmin && (waiting || playing))
            _cancelControls(id, canAct),
          if (!playing || widget.game != 'poker') ...[
            const Divider(height: 32),
            Text('Bài chung', style: Theme.of(context).textTheme.titleMedium),
            cardFaces(table['board']),
          ],
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
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => setState(
                                () => _showHoleCards = !_showHoleCards,
                              ),
                              tooltip: _showHoleCards
                                  ? 'Ẩn bài riêng'
                                  : 'Hiện bài riêng',
                              icon: Icon(
                                _showHoleCards
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: const Color(0xffffc174),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _showHoleCards ? 1 : .18,
                            duration: const Duration(milliseconds: 180),
                            child: cardFaces(cards),
                          ),
                        ],
                      );
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
            TextField(
              controller: _raise,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mức tố thêm (tối thiểu ante)',
              ),
            ),
            Builder(
              builder: (context) {
                final raiseValue = (int.tryParse(_raise.text) ?? 300).clamp(
                  10,
                  2500,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tố thêm: $raiseValue TX',
                      style: const TextStyle(
                        color: Color(0xffffc174),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: raiseValue.toDouble(),
                      min: 10,
                      max: 2500,
                      divisions: 249,
                      activeColor: const Color(0xffffc174),
                      onChanged: canAct
                          ? (value) => setState(
                              () => _raise.text = value.round().toString(),
                            )
                          : null,
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final preset in const [
                          ('1/2 Pot', 625),
                          ('3/4 Pot', 938),
                          ('Pot (1.2K)', 1250),
                          ('ALL-IN', 2500),
                        ])
                          OutlinedButton(
                            onPressed: canAct
                                ? () => setState(
                                    () => _raise.text = preset.$2.toString(),
                                  )
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xffffc174),
                              side: const BorderSide(color: Color(0xff534434)),
                            ),
                            child: Text(
                              preset.$1,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
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
                  'all-in',
                ])
                  FilledButton.tonal(
                    onPressed: canAct && table['actionVersion'] is int
                        ? () => _call('cardAction', {
                            'tableId': id,
                            'type': action,
                            if (action == 'raise')
                              'amount': int.tryParse(_raise.text.trim()),
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
                        'all-in': 'All-in',
                      }[action]!,
                    ),
                  ),
              ],
            ),
          ],
          if (status == 'settled') ...[
            const Divider(height: 32),
            Text('Kết quả', style: Theme.of(context).textTheme.titleMedium),
            Text('Người thắng: ${cardWinners(table['winners'])}'),
            Text('Pot: ${table['pot'] ?? '—'} xu ảo'),
            if (widget.game == 'ba_cay')
              Text(
                'Chương: ${table['dealerUid'] ?? '—'} • phí: ${table['rake'] ?? 0} xu',
              ),
          ],
          if (status == 'cancelled')
            const Text('Bàn đã hủy; kết quả/số dư do máy chủ xử lý.'),
        ],
      );
    },
  );

  Widget _baCayTableView({
    required String id,
    required Map<String, dynamic> table,
    required List<Map> seats,
    required String status,
    required int maxSeats,
    required bool seated,
    required bool waiting,
    required bool offline,
    required bool canAct,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (offline)
        const Text(
          'Đang xem dữ liệu lưu tạm; cần kết nối để xác nhận kết quả.',
        ),
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.doc('users/${widget.uid}').snapshots(),
        builder: (context, user) {
          final value = user.data?.data()?['balance'];
          final balance = value is num ? value.toInt() : 0;
          Widget arena(Object? cards) => BaCayArenaView(
            tableId: id,
            table: table,
            seats: seats,
            uid: widget.uid,
            balance: balance,
            privateCards: cards,
            onNewTable: () => setState(() {
              _tableId = null;
              _table = null;
              _hand = null;
              _message = null;
            }),
            onCreateTable: () => setState(() {
              _tableId = null;
              _table = null;
              _hand = null;
              _message = null;
            }),
          );
          if (seated && (status == 'playing' || status == 'settled')) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _hand,
              builder: (context, hand) {
                if (hand.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      arena(null),
                      Text(
                        'Không tải được bài riêng: ${_errorText(hand.error!)}',
                      ),
                    ],
                  );
                }
                if (!hand.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [arena(null), const LinearProgressIndicator()],
                  );
                }
                final privateCards = hand.data!.data()?['cards'];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    arena(privateCards),
                    if (hand.data!.metadata.isFromCache)
                      const Text(
                        'Bài riêng đang lưu tạm; chờ kết nối để xác nhận.',
                      ),
                  ],
                );
              },
            );
          }
          return arena(null);
        },
      ),
      if (waiting && !seated && seats.length < maxSeats)
        FilledButton(
          onPressed: canAct ? () => _join(id) : null,
          child: const Text('Tham gia bàn'),
        ),
      if (waiting && seats.length < 2)
        const Text('Cần thêm ít nhất một người hoặc bot để bắt đầu.'),
      if (waiting && (table['ownerUid'] == widget.uid || widget.isAdmin))
        FilledButton.icon(
          onPressed: canAct && seats.length >= 2
              ? () => _call('startCardHand', {'tableId': id})
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(
            seats.length >= 2 ? 'Bắt đầu ván' : 'Chờ thêm người hoặc bot',
          ),
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
      if (widget.isAdmin && (waiting || status == 'playing')) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUẢN TRỊ BÀN ĐẤU',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('Chủ bàn: ${table['ownerUid'] ?? '—'}'),
                if (waiting) _botControls(id, maxSeats, canAct),
                _cancelControls(id, canAct),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _createBotControls() => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Thêm bot đối thủ',
          style: TextStyle(color: Color(0xffe1e2eb)),
        ),
        subtitle: const Text(
          'Admin có thể dùng bot để thử bàn một mình.',
          style: TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
        ),
        value: _botsInCreateDraft,
        onChanged: _busy || _pendingCreate != null
            ? null
            : (value) => setState(() {
                _botsInCreateDraft = value;
                _createBotCount = value ? 1 : 0;
              }),
      ),
      if (_botsInCreateDraft)
        Row(
          children: [
            const Text('Số bot', style: TextStyle(color: Color(0xffd8c3ad))),
            const Spacer(),
            IconButton(
              onPressed: _busy || _pendingCreate != null || _createBotCount <= 1
                  ? null
                  : () => setState(() => _createBotCount--),
              icon: const Icon(Icons.remove),
            ),
            Text(
              '$_createBotCount',
              style: const TextStyle(
                color: Color(0xffffc174),
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed:
                  _busy ||
                      _pendingCreate != null ||
                      _createBotCount >= _maxSeats - 1
                  ? null
                  : () => setState(() => _createBotCount++),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
    ],
  );

  Widget _botControls(String id, int maxSeats, bool canAct) => Card(
    color: widget.game == 'poker' ? const Color(0xff272a31) : null,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin • Bot', style: Theme.of(context).textTheme.titleMedium),
          if (_botConfigError != null) ...[
            Text(_botConfigError!),
            TextButton(
              onPressed: () => _loadBotConfig(id),
              child: const Text('Tải lại cấu hình'),
            ),
          ],
          SwitchListTile(
            title: const Text('Bật bot'),
            value: _botsEnabled,
            onChanged: canAct
                ? (value) => setState(() => _botsEnabled = value)
                : null,
          ),
          DropdownButtonFormField<int>(
            // Clamp local draft if a different table has fewer seats.
            key: ValueKey('bot_count_${id}_$_maxBots'),
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
            onPressed: canAct && _botConfigLoaded
                ? () => _call('configureCardBots', {
                    'tableId': id,
                    'enabled': _botsEnabled,
                    'maxBots': _botsEnabled
                        ? _maxBots.clamp(0, maxSeats - 1)
                        : 0,
                  }, onSuccess: (_) => _loadBotConfig(id))
                : null,
            child: const Text('Lưu cấu hình bot'),
          ),
        ],
      ),
    ),
  );

  Widget _cancelControls(String id, bool canAct) => Card(
    color: widget.game == 'poker' ? const Color(0xff272a31) : null,
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
