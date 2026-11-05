import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../core/currency_format.dart';
import '../cards/presentation/screens/card_table_screen.dart';
import '../game/detailed_road_screen.dart';
import '../game/game_specs.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';
import 'admin_session_controls.dart';
import 'audit_log_screen.dart';
import 'player_management_screen.dart';

bool definitiveAdjustError(String code) => const {
  'invalid-argument',
  'failed-precondition',
  'permission-denied',
  'unauthenticated',
  'already-exists',
  'not-found',
}.contains(code);

class AdminConsole extends StatefulWidget {
  final String uid;
  final Future<void> Function(String, Map<String, dynamic>) invoke;
  final Widget Function(GameSpec) roundBuilder;
  final bool initiallyExpanded;
  const AdminConsole({
    super.key,
    required this.uid,
    required this.invoke,
    required this.roundBuilder,
    this.initiallyExpanded = false,
  });

  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  static const _background = Color(0xff10131a);
  static const _surface = Color(0xff191c22);
  static const _surfaceHigh = Color(0xff272a31);
  static const _gold = Color(0xffffc174);
  static const _muted = Color(0xffd8c3ad);
  static const _green = Color(0xff56e5a9);
  static const _rose = Color(0xffffb3ad);

  int _selectedTab = 0;
  int _bottomIndex = 1;
  GameSpec _selectedGame = games.first;
  late final Future<void> profileReady = _ensureProfileAndRounds();

  Future<void> _ensureProfileAndRounds() async {
    await widget.invoke('ensureProfile', {});
  }

  void _openGame(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  void _navigateBottom(int index) {
    setState(() => _bottomIndex = index);
    if (index == 0) {
      setState(() {
        _selectedTab = 0;
        _selectedGame = games.first;
      });
      return;
    }
    if (index == 1) {
      setState(() => _selectedTab = 0);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (index == 2) {
      _openGame((_) => const DetailedRoadScreen());
    } else if (index == 3 && user != null) {
      _openGame((_) => ProfileScreen(user: user, isAdmin: true));
    } else if (index == 4) {
      _openGame(
        (_) => LeaderboardScreen(
          functions: FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
        ),
      );
    }
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedTab == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedTab = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: selected ? _surfaceHigh : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .22),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? _gold : _muted),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _gold : _muted,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundGameCard(GameSpec game, double width) {
    final selected = game.id == _selectedGame.id;
    return SizedBox(
      width: width,
      child: Card(
        color: selected ? const Color(0xff32353c) : const Color(0xff1d2026),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(
            color: selected ? _gold.withValues(alpha: .38) : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => _selectedGame = game),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                Icon(game.icon, color: selected ? _gold : _muted, size: 18),
                const SizedBox(height: 4),
                Text(
                  game.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _gold : const Color(0xffe1e2eb),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  game.id == 'tai_xiu'
                      ? '3 Xúc Xắc'
                      : game.id == 'bau_cua'
                      ? '6 Linh Vật'
                      : '4 Đồng Xu',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(color: _muted, fontSize: 7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardGameLink({
    required String title,
    required String subtitle,
    required IconData icon,
    required String game,
  }) => Card(
    color: _surface,
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      leading: Icon(icon, color: _gold),
      title: Text(title, style: const TextStyle(color: Color(0xffe1e2eb))),
      subtitle: Text(subtitle, style: const TextStyle(color: _muted)),
      trailing: const Icon(Icons.chevron_right, color: _gold),
      onTap: () => _openGame(
        (_) => CardTableScreen(uid: widget.uid, isAdmin: true, game: game),
      ),
    ),
  );

  Widget _sessionPanel() => LayoutBuilder(
    builder: (context, constraints) {
      final gap = 8.0;
      final width = (constraints.maxWidth - 20 - 2 * gap) / 3;
      return ListView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: .04)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.casino_outlined, color: _gold, size: 18),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'CHỌN TRÒ CHƠI ĐIỀU HÀNH',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    Icon(Icons.circle, color: _green, size: 7),
                    SizedBox(width: 5),
                    Text(
                      'BÀN ĐANG TRỰC',
                      style: TextStyle(
                        color: _green,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 7),
                Text(
                  'Mở phiên hiện tại để theo dõi cược. Backend tự khóa khi hết giờ; admin chốt kết quả hoặc hoàn cược theo quyền hệ thống.',
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ĐIỀU HÀNH PHIÊN TRÒ CHƠI',
            style: TextStyle(
              color: _gold,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: gap,
            runSpacing: 5,
            children: [for (final game in games) _roundGameCard(game, width)],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedGame.title.toUpperCase()} • ĐIỀU HÀNH TRỰC TIẾP',
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () =>
                    _openGame((_) => widget.roundBuilder(_selectedGame)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 30),
                ),
                icon: const Icon(Icons.open_in_full, size: 12),
                label: const Text(
                  'Toàn màn hình',
                  style: TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
          AdminSessionControls(
            key: ValueKey('admin_session_${_selectedGame.id}'),
            game: _selectedGame,
            invoke: widget.invoke,
          ),
          const SizedBox(height: 14),
          const Text(
            'BÀN BÀI',
            style: TextStyle(
              color: _gold,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          _cardGameLink(
            title: 'Poker',
            subtitle: 'Quản lý bàn, lượt chơi, bot và hoàn bàn theo backend',
            icon: Icons.style,
            game: 'poker',
          ),
          _cardGameLink(
            title: 'Ba Cây',
            subtitle: 'Quản lý bàn, ván chơi, bot và hủy/hoàn bàn',
            icon: Icons.style_outlined,
            game: 'ba_cay',
          ),
        ],
      );
    },
  );

  Widget _adminHeader() => Container(
    margin: const EdgeInsets.fromLTRB(10, 7, 10, 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff302315), _surface],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xff8d6b31)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _surfaceHigh,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.admin_panel_settings, color: _gold),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _badge('ROLE: ADMIN', _rose, const Color(0xff3b1720)),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline, color: _rose, size: 13),
                          SizedBox(width: 3),
                          Text(
                            'NỘI BỘ CẤP CAO',
                            style: TextStyle(
                              color: _rose,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Trung Tâm Quản Trị Hệ Thống',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin Desk • Giám sát phiên, người chơi và nhật ký',
                    style: TextStyle(
                      color: _muted.withValues(alpha: .9),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xff123329),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: _green, size: 7),
                  SizedBox(width: 5),
                  Text(
                    'SẴN SÀNG',
                    style: TextStyle(
                      color: _green,
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _vitalCards(),
      ],
    ),
  );

  Widget _badge(String label, Color foreground, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: .7,
      ),
    ),
  );

  Widget _vitalCards() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('rounds')
        .where('status', whereIn: const ['open', 'locked'])
        .snapshots(),
    builder: (context, snapshot) {
      final rounds = snapshot.data?.docs ?? const [];
      final bettors = rounds.fold<int>(
        0,
        (total, round) =>
            total + ((round.data()['betCount'] as num?)?.toInt() ?? 0),
      );
      final stake = rounds.fold<int>(0, (total, round) {
        final totals = round.data()['totals'];
        if (totals is! Map) return total;
        return total +
            totals.values.whereType<num>().fold<int>(
              0,
              (runningTotal, value) => runningTotal + value.toInt(),
            );
      });
      final hasError = snapshot.hasError;
      return Row(
        children: [
          _vitalCard(
            label: 'PHIÊN ĐANG CHẠY',
            value: hasError ? '—' : '${rounds.length}',
            color: _gold,
          ),
          const SizedBox(width: 7),
          _vitalCard(
            label: 'LƯỢT NGƯỜI CƯỢC',
            value: hasError ? '—' : _formatCount(bettors),
            color: _green,
          ),
          const SizedBox(width: 7),
          _vitalCard(
            label: 'TỔNG CƯỢC LIVE',
            value: hasError ? '—' : _formatCount(stake),
            color: const Color(0xffffb95f),
          ),
        ],
      );
    },
  );

  Widget _vitalCard({
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xff1d2026),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: .035)),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 6,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );

  String _formatCount(int value) => formatCurrencyAmount(value);

  Widget _bottomNavigationBar() => NavigationBar(
    height: 58,
    backgroundColor: const Color(0xff0b0e14),
    indicatorColor: const Color(0x33ffc174),
    selectedIndex: _bottomIndex,
    onDestinationSelected: _navigateBottom,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.view_carousel_outlined),
        label: 'Lobby',
      ),
      NavigationDestination(
        icon: Icon(Icons.play_circle_outline),
        label: 'Arena',
      ),
      NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        label: 'Cầu Road',
      ),
      NavigationDestination(
        icon: Icon(Icons.military_tech_outlined),
        label: 'VIP Vault',
      ),
      NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        label: 'Rank',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      toolbarHeight: 46,
      backgroundColor: const Color(0xff0b0e14),
      foregroundColor: const Color(0xffe1e2eb),
      title: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.casino_outlined, color: _gold, size: 18),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: _green, size: 6),
                  SizedBox(width: 4),
                  Text(
                    'LIVE TABLE',
                    style: TextStyle(
                      color: _green,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: .9,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                'Tiuxai Arena',
                style: TextStyle(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .doc('users/${widget.uid}')
              .snapshots(),
          builder: (context, snapshot) {
            final balance = snapshot.data?.data()?['balance'];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 9),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xff0b0e14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.toll, color: Color(0xfff59e0b), size: 15),
                  const SizedBox(width: 4),
                  Text(
                    balance is num ? _formatCount(balance.toInt()) : '—',
                    style: const TextStyle(
                      color: Color(0xffffddb8),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    'VNĐ',
                    style: TextStyle(
                      color: Color(0xfff59e0b),
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: _gold,
            child: const Icon(Icons.person, color: Color(0xff472a00), size: 18),
          ),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: _bottomNavigationBar(),
    body: FutureBuilder<void>(
      future: profileReady,
      builder: (context, profile) {
        if (profile.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không tải được hồ sơ quản trị: ${profile.error}'),
            ),
          );
        }
        if (profile.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xffffc174)),
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _adminHeader(),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0e14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _tabButton(
                        index: 0,
                        icon: Icons.sports_esports,
                        label: '1. Phiên',
                      ),
                      _tabButton(
                        index: 1,
                        icon: Icons.group,
                        label: '2. Người chơi',
                      ),
                      _tabButton(
                        index: 2,
                        icon: Icons.history_edu,
                        label: '3. Nhật ký',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _sessionPanel(),
                      PlayerManagementScreen(
                        adminUid: widget.uid,
                        invoke: widget.invoke,
                        embedded: true,
                      ),
                      const AuditLogScreen(embedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
