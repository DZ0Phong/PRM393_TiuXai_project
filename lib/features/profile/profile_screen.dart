import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final bool isAdmin;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.isAdmin,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isBalanceVisible = true;
  bool _copied = false;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  void _copyUserId() {
    final shortId = widget.user.uid.length > 8
        ? widget.user.uid.substring(0, 8).toUpperCase()
        : widget.user.uid.toUpperCase();
    Clipboard.setData(ClipboardData(text: widget.user.uid));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff1d2026),
        content: Text(
          'Đã sao chép ID #$shortId vào bộ nhớ tạm',
          style: const TextStyle(color: Color(0xffffc174)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showInfoDialog(String title, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff1d2026),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xffffc174), width: 1),
        ),
        title: Row(
          children: [
            const Icon(Icons.stars, color: Color(0xffffc174), size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xffffc174),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xfff59e0b),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLeaderboardSheet() {
    final ranking = _functions.httpsCallable('getLeaderboard').call();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff191c22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0x33ffc174)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.leaderboard, color: Color(0xffffc174), size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Bảng Xếp Hạng Đại Gia Xu Ảo',
                      style: TextStyle(
                        color: Color(0xffffc174),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Điểm mô phỏng PRM393 • Không có giá trị quy đổi',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: FutureBuilder<HttpsCallableResult<dynamic>>(
                    future: ranking,
                    builder: (context, result) {
                      if (result.hasError) {
                        return Center(
                          child: Text(
                            'Lỗi tải: ${result.error}',
                            style: const TextStyle(color: Color(0xffffb4ab)),
                          ),
                        );
                      }
                      if (!result.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xffffc174)),
                        );
                      }
                      final rows = result.data!.data;
                      if (rows is! List || rows.isEmpty) {
                        return const Center(
                          child: Text(
                            'Chưa có người chơi.',
                            style: TextStyle(color: Color(0xffe1e2eb)),
                          ),
                        );
                      }
                      return ListView(
                        shrinkWrap: true,
                        children: [
                          for (final row in rows.whereType<Map>())
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xff272a31),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: row['rank'] == 1
                                      ? const Color(0xffffc174)
                                      : const Color(0x1affffff),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: row['rank'] == 1
                                        ? const Color(0xffffc174)
                                        : (row['rank'] == 2
                                            ? const Color(0xffe1e2eb)
                                            : const Color(0xff32353c)),
                                    child: Text(
                                      '#${row['rank'] ?? '—'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: row['rank'] <= 2 ? Colors.black : Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${row['nickname'] ?? 'Người chơi'}',
                                      style: const TextStyle(
                                        color: Color(0xffe1e2eb),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${row['balance'] ?? '—'} xu',
                                    style: const TextStyle(
                                      color: Color(0xffffc174),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortUid = widget.user.uid.length > 8
        ? widget.user.uid.substring(0, 8).toUpperCase()
        : widget.user.uid.toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      body: Stack(
        children: [
          // Quầng sáng nền hổ phách sang trọng
          Positioned(
            top: -50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 360,
                height: 240,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x24f59e0b),
                      Color(0x0010131a),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Header Bar
                _buildTopBar(),

                // 2. Scrollable Body
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .doc('users/${widget.user.uid}')
                        .snapshots(),
                    builder: (context, userSnap) {
                      final userData = userSnap.data?.data();
                      final balance = userData?['balance'] ?? 0;
                      final isBlocked = userData?['blocked'] == true;

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users/${widget.user.uid}/operations')
                            .orderBy('at', descending: true)
                            .limit(30)
                            .snapshots(),
                        builder: (context, opsSnap) {
                          final ops = opsSnap.data?.docs.map((d) => d.data()).toList() ?? [];

                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                children: [
                                  // Profile Hero Card
                                  _buildProfileHeroCard(shortUid, isBlocked),
                                  const SizedBox(height: 14),

                                  // VIP Wallet Card (Thẻ Số Dư Hoàng Gia)
                                  _buildWalletCard(balance),
                                  const SizedBox(height: 14),

                                  // Operational Shortcuts (4 Essential Hub Icons)
                                  _buildOperationalShortcuts(),
                                  const SizedBox(height: 14),

                                  // Performance Bento (Chiến tích Tài Xỉu)
                                  _buildPerformanceBento(ops),
                                  const SizedBox(height: 14),

                                  // Lịch Sử Biến Động Ví Thực Tế (Wallet Ledger)
                                  _buildOperationsLedger(ops),
                                  const SizedBox(height: 14),

                                  // VIP Privilege Showcase Banner
                                  _buildPrivilegeBanner(),
                                  const SizedBox(height: 14),

                                  // Settings & Quick Links Menu
                                  _buildSettingsMenu(),
                                  const SizedBox(height: 16),

                                  // Logout Button
                                  _buildLogoutButton(),
                                  const SizedBox(height: 16),

                                  // App Version Footer
                                  _buildAppFooter(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xff0b0e14).withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: Color(0x1affffff))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xffe1e2eb), size: 20),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Quay lại',
          ),
          const Text(
            'HỒ SƠ CÁ NHÂN',
            style: TextStyle(
              color: Color(0xffffc174),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent, color: Color(0xffffc174), size: 22),
            onPressed: () => _showInfoDialog(
              'Hỗ Trợ Khách Hàng VIP',
              'Đội ngũ quản trị viên hỗ trợ giải đáp luật và xử lý điểm ảo: Hotline 1900 8888.',
            ),
            tooltip: 'CSKH 24/7',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeroCard(String shortUid, bool isBlocked) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1d2026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22ffc174)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // VIP Avatar Frame with Halo
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xffffc174), Color(0xfff59e0b), Color(0xffffb95f)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffffc174).withValues(alpha: 0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xff0b0e14),
                    ),
                    child: const Icon(Icons.person, color: Color(0xffffc174), size: 40),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xfff59e0b), Color(0xffffc174)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isAdmin ? Icons.admin_panel_settings : Icons.workspace_premium,
                            color: const Color(0xff472a00),
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.isAdmin ? 'ADMIN' : 'VIP 7',
                            style: const TextStyle(
                              color: Color(0xff472a00),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name & Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.user.email?.split('@').first.toUpperCase() ?? 'ĐẠI GIA MACAU',
                            style: const TextStyle(
                              color: Color(0xffffc174),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Color(0xffffc174), size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xff272a31),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.diamond, color: Color(0xffffb95f), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            widget.isAdmin ? 'Quản Trị Viên Hệ Thống' : 'Hội Viên Hoàng Gia Diamond',
                            style: const TextStyle(
                              color: Color(0xffffc174),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InkWell(
                          onTap: _copyUserId,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff0b0e14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#$shortUid',
                                  style: const TextStyle(
                                    color: Color(0xffe1e2eb),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _copied ? Icons.check : Icons.content_copy,
                                  color: const Color(0xffffc174),
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isBlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff93000a),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ĐANG KHÓA',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // VIP Progress Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff272a31).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.stars, color: Color(0xffffc174), size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Tiến độ lên VIP 8 (Hoàng Kim Vương)',
                          style: TextStyle(color: Color(0xffd8c3ad), fontSize: 11),
                        ),
                      ],
                    ),
                    Text(
                      '82.500 / 100.000 EXP',
                      style: TextStyle(color: Color(0xffffc174), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.825,
                    minHeight: 6,
                    backgroundColor: const Color(0xff0b0e14),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xffffc174)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard(int balance) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff272a31), Color(0xff1d2026), Color(0xff0b0e14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33ffc174)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.account_balance_wallet, color: Color(0xffffc174), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'SỐ DƯ KHẢ DỤNG',
                        style: TextStyle(
                          color: Color(0xffa08e7a),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _isBalanceVisible ? '$balance' : '••••••••••••',
                        style: const TextStyle(
                          color: Color(0xffffc174),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Xu Ảo',
                        style: TextStyle(
                          color: Color(0xffffddb8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        iconSize: 18,
                        padding: const EdgeInsets.only(left: 6),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xffa08e7a),
                        ),
                        onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.military_tech, color: Color(0xff56e5a9), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'VIP POINT',
                        style: TextStyle(
                          color: Color(0xffa08e7a),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xff0b0e14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '14.250 pts',
                      style: TextStyle(
                        color: Color(0xff56e5a9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Safe Box Sub-Card (Két Sắt Hoàng Gia)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xff0b0e14).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x1affffff)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock, color: Color(0xffffc174), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Két Sắt Hoàng Gia',
                        style: TextStyle(color: Color(0xffa08e7a), fontSize: 11),
                      ),
                      Text(
                        '500.000 Xu Ảo Khóa',
                        style: TextStyle(
                          color: Color(0xffe1e2eb),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xff272a31),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  onPressed: () => _showInfoDialog(
                    'Két Sắt Hoàng Gia',
                    'Tính năng gửi bảo lưu xu ảo an toàn khi không tham gia cược.',
                  ),
                  child: Row(
                    children: const [
                      Text('Mở Két', style: TextStyle(color: Color(0xffffc174), fontSize: 11)),
                      Icon(Icons.arrow_forward_ios, color: Color(0xffffc174), size: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2 Quick Actions (Được thiết kế chuẩn điểm ảo PRM393)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xfff59e0b),
                    foregroundColor: const Color(0xff472a00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _showInfoDialog(
                    'Nhận Điểm Tân Thủ',
                    'Tài khoản mới tự động nhận 10.000 xu ảo. Nếu hết điểm, hãy liên hệ Admin hoặc thực hiện nhiệm vụ.',
                  ),
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text(
                    'Nhận Xu Tân Thủ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffe1e2eb),
                    side: const BorderSide(color: Color(0x33ffffff)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _showInfoDialog(
                    'Rút Xu / Đổi Thưởng',
                    'Dự án PRM393 tuân thủ quy tắc giáo dục: Toàn bộ điểm số là xu ảo mô phỏng, không hỗ trợ nạp/rút tiền thật dưới mọi hình thức.',
                  ),
                  icon: const Icon(Icons.payments, size: 18),
                  label: const Text(
                    'Quy Tắc Điểm Ảo',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalShortcuts() {
    return Row(
      children: [
        _buildShortcutItem(
          icon: Icons.casino,
          iconBg: const Color(0xff410004),
          iconColor: const Color(0xffffb3ad),
          label: 'Lịch Sử Cược',
          onTap: () {
            // Cuộn xuống phần operations hoặc mở chi tiết
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Xem danh sách biến động ví & cược bên dưới.')),
            );
          },
        ),
        _buildShortcutItem(
          icon: Icons.lock,
          iconBg: const Color(0xff2a1700),
          iconColor: const Color(0xffffc174),
          label: 'Két Sắt VIP',
          onTap: () => _showInfoDialog('Két Sắt VIP', 'Két sắt bảo toàn số dư đang hoạt động.'),
        ),
        _buildShortcutItem(
          icon: Icons.leaderboard,
          iconBg: const Color(0xff003824),
          iconColor: const Color(0xff56e5a9),
          label: 'Bảng Xếp Hạng',
          onTap: _showLeaderboardSheet,
        ),
        _buildShortcutItem(
          icon: Icons.assignment_turned_in,
          iconBg: const Color(0xff32353c),
          iconColor: const Color(0xffffc174),
          label: 'Nhiệm Vụ VIP',
          badge: true,
          onTap: () => _showInfoDialog(
            'Nhiệm Vụ Tân Thủ',
            '• Đăng nhập hàng ngày: +1.000 Xu\n• Chơi 5 ván Tài Xỉu: +2.000 Xu\n• Tham gia bàn Poker: +3.000 Xu',
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    bool badge = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  if (badge)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xffffb4ab),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xff10131a), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffe1e2eb),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceBento(List<Map<String, dynamic>> ops) {
    // Thống kê thực tế từ danh sách operations
    int totalBets = 0;
    int winCount = 0;
    int maxWin = 0;

    for (final op in ops) {
      final kind = op['kind']?.toString() ?? '';
      final delta = (op['delta'] as num?)?.toInt() ?? 0;
      if (kind.startsWith('bet')) {
        totalBets++;
      } else if (kind == 'result' || kind == 'win') {
        if (delta > 0) {
          winCount++;
          if (delta > maxWin) maxWin = delta;
        }
      }
    }

    final winRate = totalBets > 0 ? ((winCount / totalBets) * 100).toStringAsFixed(1) : '68.4';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Row(
              children: [
                Icon(Icons.equalizer, color: Color(0xffffc174), size: 18),
                SizedBox(width: 6),
                Text(
                  'Chiến Tích Tài Xỉu',
                  style: TextStyle(
                    color: Color(0xffe1e2eb),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              'Thống Kê Gần Đây',
              style: TextStyle(color: Color(0xffa08e7a), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            // Tổng Ván Cược
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff1d2026),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1affffff)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Tổng Ván Cược', style: TextStyle(color: Color(0xffa08e7a), fontSize: 11)),
                        Icon(Icons.history_toggle_off, color: Color(0xffa08e7a), size: 16),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      totalBets > 0 ? '$totalBets' : '1.820',
                      style: const TextStyle(
                        color: Color(0xffe1e2eb),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Tài: 52% | Xỉu: 48%', style: TextStyle(color: Color(0xffa08e7a), fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Tỉ Lệ Thắng
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xff1d2026),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1affffff)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Text('Tỉ Lệ Thắng', style: TextStyle(color: Color(0xffa08e7a), fontSize: 11)),
                            SizedBox(width: 4),
                            Icon(Icons.trending_up, color: Color(0xff56e5a9), size: 14),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$winRate%',
                          style: const TextStyle(
                            color: Color(0xff56e5a9),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('Đẳng cấp VIP', style: TextStyle(color: Color(0xff56e5a9), fontSize: 10)),
                      ],
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xff56e5a9), width: 3),
                      ),
                      child: const Center(
                        child: Icon(Icons.stars, color: Color(0xff56e5a9), size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Biggest Jackpot Win
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff410004), Color(0xff272a31)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x33ffb3ad)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xffa40217),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department, color: Color(0xffffdad7), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          'HŨ NỔ LỚN NHẤT',
                          style: TextStyle(
                            color: Color(0xffffb3ad),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'TÀI BÃO',
                          style: TextStyle(
                            color: Color(0xffffc174),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      maxWin > 0 ? '$maxWin Xu' : '850.000 Xu',
                      style: const TextStyle(
                        color: Color(0xffffc174),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Kỷ lục VIP',
                style: TextStyle(color: Color(0xff56e5a9), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationsLedger(List<Map<String, dynamic>> ops) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1d2026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1affffff)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.receipt_long, color: Color(0xffffc174), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Biến Động Số Dư Gần Nhất',
                    style: TextStyle(
                      color: Color(0xffe1e2eb),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${ops.length} bản ghi',
                style: const TextStyle(color: Color(0xffa08e7a), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (ops.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Chưa có giao dịch nào được ghi nhận.',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 12),
                ),
              ),
            )
          else
            ...ops.take(8).map((op) {
              final kind = op['kind']?.toString() ?? 'Giao dịch';
              final delta = (op['delta'] as num?)?.toInt() ?? 0;
              final balanceAfter = op['balance'];
              final roundId = op['roundId'] ?? '';
              final isPositive = delta >= 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xff272a31).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isPositive ? const Color(0xff56e5a9) : const Color(0xffffb4ab),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatKind(kind),
                            style: const TextStyle(
                              color: Color(0xffe1e2eb),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (roundId.toString().isNotEmpty)
                            Text(
                              'Phiên: $roundId',
                              style: const TextStyle(color: Color(0xffa08e7a), fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}$delta xu',
                          style: TextStyle(
                            color: isPositive ? const Color(0xff56e5a9) : const Color(0xffffb4ab),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Dư: ${balanceAfter ?? '—'} xu',
                          style: const TextStyle(color: Color(0xffa08e7a), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatKind(String kind) {
    switch (kind) {
      case 'welcome':
        return 'Quà Tân Thủ Khởi Nghiệp';
      case 'bet':
        return 'Đặt cược phiên';
      case 'result':
        return 'Trả thưởng kết quả';
      case 'admin':
        return 'Điều chỉnh Quản trị';
      case 'table_join':
        return 'Mua vào bàn bài';
      case 'table_leave':
        return 'Hoàn trả rời bàn bài';
      default:
        return kind.toUpperCase();
    }
  }

  Widget _buildPrivilegeBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0xff2a1700), Color(0xff191c22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33ffc174)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.shield, color: Color(0xffffc174), size: 16),
              SizedBox(width: 6),
              Text(
                'ĐẶC QUYỀN HỘI VIÊN DIAMOND',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hoàn Cược Mỗi Ngày 1.8%',
            style: TextStyle(
              color: Color(0xffe1e2eb),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Tự động kết toán xu ảo mô phỏng vào 12:00 trưa hàng ngày.',
            style: TextStyle(color: Color(0xffa08e7a), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1d2026),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1affffff)),
      ),
      child: Column(
        children: [
          _buildMenuRow(
            icon: Icons.manage_accounts,
            title: 'Chỉnh Sửa Hồ Sơ',
            subtitle: 'Biệt danh, số điện thoại, avatar',
            onTap: () => _showInfoDialog(
              'Chỉnh Sửa Hồ Sơ',
              'Thông tin tài khoản được quản lý đồng bộ qua hệ thống Firebase Authentication.',
            ),
          ),
          const Divider(height: 1, color: Color(0x1affffff)),
          _buildMenuRow(
            icon: Icons.lock_reset,
            title: 'Đổi Mật Khẩu & Bảo Mật',
            subtitle: 'Bảo mật SSL 256-bit, quản lý phiên',
            onTap: () => _showInfoDialog(
              'Bảo Mật Tài Khoản',
              'Để đổi mật khẩu, vui lòng liên hệ Admin hoặc sử dụng email khôi phục.',
            ),
          ),
          const Divider(height: 1, color: Color(0x1affffff)),
          _buildMenuRow(
            icon: Icons.settings,
            title: 'Cài Đặt Bàn Cược',
            subtitle: 'Âm thanh xúc xắc, chế độ nặn 3D',
            onTap: () => _showInfoDialog(
              'Cài Đặt Bàn Cược',
              'Chế độ hiệu ứng âm thanh và đồ họa bàn cược đã kích hoạt ở mức cao nhất.',
            ),
          ),
          const Divider(height: 1, color: Color(0x1affffff)),
          _buildMenuRow(
            icon: Icons.support_agent,
            title: 'Quản Gia CSKH VIP 24/7',
            subtitle: 'Hỗ trợ riêng qua Hotline VIP & Telegram',
            trailingBadge: 'Trực tuyến',
            onTap: () => _showInfoDialog(
              'CSKH VIP 24/7',
              'Kênh hỗ trợ sinh viên PRM393 trực tuyến 24/7 qua Hotline 1900 8888.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    String? trailingBadge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xff272a31),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xffffc174), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xffe1e2eb),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (trailingBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xff003824),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            trailingBadge,
                            style: const TextStyle(
                              color: Color(0xff56e5a9),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xffa08e7a), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xffa08e7a), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xffffb4ab),
          side: const BorderSide(color: Color(0x44ffb4ab)),
          backgroundColor: const Color(0xff690005).withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () async {
          Navigator.of(context).pop();
          await FirebaseAuth.instance.signOut();
        },
        icon: const Icon(Icons.logout, size: 18),
        label: const Text(
          'ĐĂNG XUẤT TÀI KHOẢN',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
      ),
    );
  }

  Widget _buildAppFooter() {
    return Column(
      children: const [
        Text(
          'Tài Xỉu Hoàng Gia • Phiên bản VIP 3.8.2 (Macau Edition)',
          style: TextStyle(color: Color(0xff534434), fontSize: 11),
        ),
        SizedBox(height: 2),
        Text(
          'Dự án điểm ảo phục vụ học tập PRM393 • Nghiêm cấm mọi hành vi cờ bạc tiền thật',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xff534434), fontSize: 10),
        ),
      ],
    );
  }
}
