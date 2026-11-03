import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';
import '../cards/presentation/screens/card_table_screen.dart';
import '../game/game_specs.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';

class LobbyScreen extends StatefulWidget {
  final User user;
  final FirebaseFunctions functions;
  final bool emulator;
  final String Function(Object) readableError;
  final Widget Function(GameSpec, String, bool) roundBuilder;
  const LobbyScreen({
    super.key,
    required this.user,
    required this.functions,
    required this.emulator,
    required this.readableError,
    required this.roundBuilder,
  });
  @override
  State<LobbyScreen> createState() => _LobbyState();
}

class _LobbyState extends State<LobbyScreen> {
  late Future<bool> profile = _loadProfile();
  int selectedCategory = 0;
  int selectedNav = 0;
  bool showWinToast = true;
  Timer? toastTimer;
  int jackpot = 3482910450;
  Timer? jackpotTimer;
  Timer? roundTimer;
  bool ensuringRounds = false;

  @override
  void initState() {
    super.initState();
    toastTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() => showWinToast = false);
    });
    jackpotTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (mounted) {
        setState(() => jackpot += 120 + DateTime.now().millisecond % 850);
      }
    });
    roundTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _ensureAutomaticRounds(),
    );
  }

  @override
  void dispose() {
    toastTimer?.cancel();
    jackpotTimer?.cancel();
    roundTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureAutomaticRounds() async {
    if (ensuringRounds) return;
    ensuringRounds = true;
    try {
      await widget.functions.httpsCallable('ensureGameRounds').call();
    } catch (_) {
      // A later timer tick retries if the function or connection is unavailable.
    } finally {
      ensuringRounds = false;
    }
  }

  Future<bool> _loadProfile() async {
    final token = await widget.user.getIdTokenResult();
    await widget.functions.httpsCallable('ensureProfile').call();
    await widget.functions.httpsCallable('ensureGameRounds').call();
    return token.claims?['admin'] == true;
  }

  void _showLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaderboardScreen(functions: widget.functions),
      ),
    );
  }

  Future<void> _openProfile() async {
    final isAdmin = await profile;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(user: widget.user, isAdmin: isAdmin),
      ),
    );
  }

  void _openCategory(int category, bool isAdmin) {
    setState(() => selectedCategory = category);
    if (category == 0) return;
    const roundIds = {1: 'tai_xiu', 2: 'bau_cua', 3: 'xoc_xoc'};
    if (category <= 3) {
      final game = games.firstWhere((item) => item.id == roundIds[category]);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.roundBuilder(game, widget.user.uid, isAdmin),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardTableScreen(
          uid: widget.user.uid,
          isAdmin: isAdmin,
          game: category == 4 ? 'poker' : 'ba_cay',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff10131a),
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: const Color(0xffe1e2eb),
      title: const Text(
        'SẢNH GAME',
        style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
      actions: [
        IconButton(
          tooltip: 'Đăng xuất',
          icon: const Icon(Icons.logout),
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
      ],
    ),
    body: FutureBuilder<bool>(
      future: profile,
      builder: (context, state) {
        if (state.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Không tải được tài khoản: ${widget.readableError(state.error!)}',
                  ),
                  TextButton(
                    onPressed: () => setState(() => profile = _loadProfile()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final isAdmin = state.data!;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                // Profile and balance strip from the Stitch lobby.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0x33ffc174),
                        child: Icon(Icons.stars, color: Color(0xffffc174)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SỐ DƯ XU ẢO',
                              style: TextStyle(
                                color: Color(0xffd8c3ad),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .doc('users/${widget.user.uid}')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                final balance = snapshot.data
                                    ?.data()?['balance'];
                                return Text(
                                  '${balance ?? '…'} Xu',
                                  style: const TextStyle(
                                    color: Color(0xffffc174),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bảng xếp hạng',
                        onPressed: _showLeaderboard,
                        icon: const Icon(
                          Icons.leaderboard,
                          color: Color(0xffd8c3ad),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hồ sơ',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              user: widget.user,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                        icon: const Icon(
                          Icons.person,
                          color: Color(0xffd8c3ad),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff1d2026),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xff534434)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.military_tech, color: Color(0xffffc174)),
                          SizedBox(width: 8),
                          Text(
                            'HŨ TÀI XỈU HOÀNG GIA',
                            style: TextStyle(
                              color: Color(0xffffc174),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        jackpot.toString().replaceAllMapped(
                          RegExp(r'(?=(\d{3})+(?!\d))'),
                          (_) => '.',
                        ),
                        style: const TextStyle(
                          color: Color(0xffffc174),
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Xu ảo • điểm mô phỏng, không quy đổi',
                        style: TextStyle(
                          color: Color(0xffd8c3ad),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCpX6zhnMD36EwXDntDw0lb0IMlwraZMPVr26VJS6kP_x3ySAOIgvInyCD1ZS31Mz9Sc5vledwJdp5eGc7s2ApEHJt8_NMWItgV8M_YRc_9TugPMgQmzTLUTcL8a6_WIWxDJY_OFPIz9lgxbS2geVKhOR3tFrVTLv5ebiz_nIMSrZViTcz1PxcSyBCwxogn6giTK8P5BB4cywADVvNHfnQxLzMfwW1Z8mf-z1dv4sM',
                      ),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black54,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'ĐẠI TIỆC VIP',
                          style: TextStyle(
                            color: Color(0xffffc174),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Sự kiện mô phỏng • chơi bằng xu ảo',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SẢNH TRÒ CHƠI',
                    style: TextStyle(
                      color: Color(0xffffc174),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: List.generate(6, (i) {
                      const labels = [
                        'Tất cả',
                        'Tài Xỉu',
                        'Bầu Cua',
                        'Xóc Xóc',
                        'Poker',
                        'Ba Cây',
                      ];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(labels[i]),
                          selected: selectedCategory == i,
                          onSelected: (_) => _openCategory(i, isAdmin),
                          selectedColor: const Color(0xfff59e0b),
                          backgroundColor: const Color(0xff272a31),
                          labelStyle: TextStyle(
                            color: selectedCategory == i
                                ? const Color(0xff472a00)
                                : const Color(0xffd8c3ad),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _LobbyFeatureCard(
                  title: 'TÀI XỈU',
                  subtitle: 'PHIÊN XU ẢO',
                  image:
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDeMqYuqzSaqh4DvO1vsE5pglfE-DCLDv6gGhwi9BV0smraVE9sAqf-Migo9H0j73HAsLVL339cQ3Nh79tCezLQSQFw6V0Bl_a50DxMDeBgSstUkeCpOqndGAYbRtyT7V9ok8dnDv2dzzTaPqg4hCfWKxPJ6Dd5jshKLoPDaTCkm49ng275W8VIU2mKA6KHUn0yEn1wdCW41bj0knAwOYU2Bk_BOcc4Ch07WIlDj9k',
                  tag: 'HOT NHẤT',
                  onPlay: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => widget.roundBuilder(
                        games.first,
                        widget.user.uid,
                        isAdmin,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .87,
                  children: [
                    _LobbySmallCard(
                      title: 'Poker',
                      subtitle: 'Texas Hold’em • 2–6 ghế',
                      image: '',
                      icon: Icons.style,
                      onPlay: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CardTableScreen(
                            uid: widget.user.uid,
                            isAdmin: isAdmin,
                            game: 'poker',
                          ),
                        ),
                      ),
                    ),
                    _LobbySmallCard(
                      title: 'Ba Cây',
                      subtitle: 'Bài 36 lá • so điểm',
                      image: '',
                      icon: Icons.style_outlined,
                      onPlay: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CardTableScreen(
                            uid: widget.user.uid,
                            isAdmin: isAdmin,
                            game: 'ba_cay',
                          ),
                        ),
                      ),
                    ),
                    _LobbySmallCard(
                      title: 'Xóc Đĩa VIP',
                      subtitle: 'Tứ trắng tứ đỏ',
                      image:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuA0CW_kJSoKSYBXG1iBBOMgFSPbhU329oK-BplRbFrMNE8X3ZXnCPSB4P4BqUfi4LTgHT2ODcjHgLsM3daZaHiYWEp453AS5PILOhPhcS36xmP1O_HXldYDYTmE08do0S5zuowjSU5PaBTLYqtf9SNz8oTYnDfnsNBUkYcwptL2oI__zo_QNU9yAotdziC1aLJ3nW3oTPb4am3TnrSyiD7cQ2UThzeSYVfl_d2Q0UY',
                      onPlay: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => widget.roundBuilder(
                            games[2],
                            widget.user.uid,
                            isAdmin,
                          ),
                        ),
                      ),
                    ),
                    _LobbySmallCard(
                      title: 'Bầu Cua Tôm Cá',
                      subtitle: 'Truyền thống • ăn đậm x3',
                      image:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBTnxpGQM8p7kmPgQ076dBSNCmXchhLk7wxdLiK_-PR9vVlaP_UScsJpFEpE2V1eXwpOpblxHeJ_hQW72gxy7Z6Ey2r1wbLkV1up8ZY5dZnJg8f9yzXitEhs67CWhlmaOctfaIHQVvB8jTGfKgZ1VCXjQBOg6vFyOJbfVlnFdLf8QbYmqbzkt3BmFenN25au8HIOfI-y9lUxqHw3AKu73v6JUcyQ9vA2t2qQv3g6uM',
                      onPlay: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => widget.roundBuilder(
                            games[1],
                            widget.user.uid,
                            isAdmin,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showWinToast) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xff191c22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xffffc174),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x55f59e0b), blurRadius: 20),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Color(0xffffc174),
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CHIẾN THẮNG LỚN!',
                                style: TextStyle(
                                  color: Color(0xffe1e2eb),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Thông báo minh họa từ giao diện mẫu',
                                style: TextStyle(
                                  color: Color(0xffd8c3ad),
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '+36.800.000 Xu ảo',
                                style: TextStyle(
                                  color: Color(0xffffc174),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng thông báo',
                          onPressed: () => setState(() => showWinToast = false),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xffd8c3ad),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xff191c22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xff534434)),
                  ),
                  child: const Text(
                    'CHỈ XU ẢO • Không có tiền thật, nạp/rút hay giải thưởng. Kết quả phiên do máy chủ xử lý theo luật trò chơi.',
                    style: TextStyle(color: Color(0xffd8c3ad), fontSize: 12),
                  ),
                ),
                if (widget.emulator) const Text('Đang dùng Firebase Emulator'),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .doc('users/${widget.user.uid}')
                      .snapshots(),
                  builder: (context, user) {
                    if (user.hasError) {
                      return Text('Không tải được số xu: ${user.error}');
                    }
                    if (!user.hasData) return const LinearProgressIndicator();
                    final data = user.data!.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xff277767),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        title: Text(
                          '${data?['balance'] ?? '—'} xu ảo',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          data?['blocked'] == true
                              ? 'Tài khoản bị khóa: ${data?['blockReason'] ?? 'Liên hệ quản trị'}'
                              : '${widget.user.email ?? widget.user.uid} • ${isAdmin ? 'Admin' : 'Hội viên'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              user: widget.user,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showLeaderboard,
                        icon: const Icon(Icons.leaderboard_outlined),
                        label: const Text('Bảng xếp hạng'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ProfileScreen(
                              user: widget.user,
                              isAdmin: isAdmin,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Hồ sơ & Ví'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 20),
                Text(
                  'Hoạt động xu ảo của bạn',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users/${widget.user.uid}/operations')
                      .orderBy('at', descending: true)
                      .limit(20)
                      .snapshots(),
                  builder: (context, ops) {
                    if (ops.hasError) {
                      return Text('Không tải được hoạt động: ${ops.error}');
                    }
                    if (!ops.hasData) return const LinearProgressIndicator();
                    if (ops.data!.docs.isEmpty) {
                      return const Text('Chưa có hoạt động.');
                    }
                    return Column(
                      children: ops.data!.docs.map((doc) {
                        final op = doc.data();
                        return ListTile(
                          title: Text(
                            '${op['kind'] ?? 'Hoạt động'} • ${op['delta'] ?? 0} xu',
                          ),
                          subtitle: Text(
                            'Số dư sau: ${op['balance'] ?? '—'} • ${op['roundId'] ?? ''}',
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    ),
    bottomNavigationBar: NavigationBar(
      backgroundColor: const Color(0xff0b0e14),
      indicatorColor: const Color(0x33ffc174),
      selectedIndex: selectedNav,
      onDestinationSelected: (index) {
        setState(() => selectedNav = index);
        if (index == 4) _openProfile();
        if (index == 1 || index == 2 || index == 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mục này chưa có chức năng trong phiên bản xu ảo.'),
            ),
          );
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.casino), label: 'Sảnh Game'),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Nạp Rút',
        ),
        NavigationDestination(
          icon: Icon(Icons.card_giftcard),
          label: 'Sự Kiện',
        ),
        NavigationDestination(
          icon: Icon(Icons.workspace_premium),
          label: 'VIP Club',
        ),
        NavigationDestination(
          icon: Icon(Icons.manage_accounts),
          label: 'Cá Nhân',
        ),
      ],
    ),
  );
}

const _lobbyGold = Color(0xffffc174);
const _lobbySurface = Color(0xff272a31);

class _LobbyFeatureCard extends StatelessWidget {
  final String title, subtitle, image, tag;
  final VoidCallback onPlay;
  const _LobbyFeatureCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.tag,
    required this.onPlay,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _lobbySurface,
      borderRadius: BorderRadius.circular(18),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: _lobbySurface,
                  child: const Icon(Icons.casino, size: 52, color: _lobbyGold),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xee272a31)],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Chip(
                  label: Text(tag),
                  backgroundColor: const Color(0xffa40217),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _lobbyGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tổng cược phiên • xu ảo',
                  style: TextStyle(color: Color(0xffd8c3ad), fontSize: 12),
                ),
              ),
              FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('CHƠI NGAY'),
                style: FilledButton.styleFrom(
                  backgroundColor: _lobbyGold,
                  foregroundColor: const Color(0xff472a00),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LobbySmallCard extends StatelessWidget {
  final String title, subtitle, image;
  final VoidCallback onPlay;
  final IconData icon;
  const _LobbySmallCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.onPlay,
    this.icon = Icons.casino,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _lobbySurface,
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image.isEmpty)
                _CardGameArtwork(game: title, fallbackIcon: icon)
              else
                Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _CardGameArtwork(game: title, fallbackIcon: icon),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xee191c22)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 8,
                bottom: 9,
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Color(0xffe1e2eb),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffd8c3ad),
                    fontSize: 10,
                  ),
                ),
              ),
              IconButton(
                onPressed: onPlay,
                constraints: const BoxConstraints.tightFor(
                  width: 34,
                  height: 34,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.play_arrow, color: _lobbyGold),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CardGameArtwork extends StatelessWidget {
  final String game;
  final IconData fallbackIcon;
  const _CardGameArtwork({required this.game, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final poker = game == 'Poker';
    final cards = poker
        ? const [
            ('A', '♠', Color(0xff201c2c)),
            ('K', '♥', Color(0xff4c1f26)),
            ('Q', '♠', Color(0xff201c2c)),
          ]
        : const [
            ('7', '♦', Color(0xff4c1f26)),
            ('A', '♠', Color(0xff201c2c)),
            ('9', '♥', Color(0xff4c1f26)),
          ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.2),
          radius: 1.1,
          colors: [Color(0xff4a3923), Color(0xff171820)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -38,
            right: -24,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x55ffc174), width: 1.2),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < cards.length; i++)
                  Transform.rotate(
                    angle: (i - 1) * .14,
                    child: Transform.translate(
                      offset: Offset((i - 1) * -7, i == 1 ? -3 : 8),
                      child: _LobbyPlayingCard(
                        rank: cards[i].$1,
                        suit: cards[i].$2,
                        color: cards[i].$3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 10,
            top: 9,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: _lobbyGold),
                const SizedBox(width: 4),
                Text(
                  poker ? 'TEXAS HOLD’EM' : 'BA CÂY • 36 LÁ',
                  style: const TextStyle(
                    color: _lobbyGold,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 9,
            child: Icon(fallbackIcon, color: const Color(0x77ffc174), size: 19),
          ),
        ],
      ),
    );
  }
}

class _LobbyPlayingCard extends StatelessWidget {
  final String rank, suit;
  final Color color;
  const _LobbyPlayingCard({
    required this.rank,
    required this.suit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    height: 72,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: const Color(0xfff5efe4),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xffffd989), width: 1),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rank,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            height: 1,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            height: 1,
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              suit,
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
