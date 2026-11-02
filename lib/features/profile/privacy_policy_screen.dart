import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';

const _privacyBg = Color(0xff10131a);
const _privacyLow = Color(0xff191c22);
const _privacySurface = Color(0xff1d2026);
const _privacyHigh = Color(0xff272a31);
const _privacyHighest = Color(0xff32353c);
const _privacyGold = Color(0xffffc174);
const _privacyAmber = Color(0xfff59e0b);
const _privacyMint = Color(0xff56e5a9);
const _privacyRed = Color(0xffffb3ad);
const _privacyText = Color(0xffe1e2eb);
const _privacyMuted = Color(0xffd8c3ad);
const _privacyOutline = Color(0xffa08e7a);
const _privacyImageUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuAGcjLLvwvzLswifKCp9zXUkUzFTP5utEGbkr-uLyPNiw0w5jYdfBQBgIR8SoZsLonzy9uFaHs8YSBhlsFbMZfCYa6TBvxr6v5aPeyT0V0gQWoPQp21sFyWWeaiYutOOgSsKUnKyGU-cpave-HarHz_TYz6LAgSFwqcwIe0wUntp_BEyXyldYxCZhOP2J99X3al5hexB0p6Y2pu2z-eZ_ivjzeGU7nkaDh6vLEhQJWO';

class PrivacyPolicyScreen extends StatefulWidget {
  final User user;

  const PrivacyPolicyScreen({super.key, required this.user});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final List<bool> _expanded = [true, false, false, false, false, false];
  bool _acknowledged = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _privacyHighest,
        ),
      );
  }

  void _showUnavailable(String title, String detail) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _privacySurface,
        title: Text(title, style: const TextStyle(color: _privacyGold)),
        content: Text(
          detail,
          style: const TextStyle(color: _privacyText, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _acknowledge() {
    if (_acknowledged) return;
    setState(() => _acknowledged = true);
    _showMessage('Đã ghi nhận xác nhận trên màn hình này.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _privacyBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _privacyText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Chính Sách Bảo Mật',
        style: TextStyle(
          color: _privacyGold,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông tin liên hệ',
          onPressed: () => _showUnavailable(
            'Kênh liên hệ',
            'Ứng dụng demo chưa cấu hình email DPO, hotline hoặc kênh hỗ trợ bên ngoài.',
          ),
          icon: const Icon(Icons.support_agent, color: _privacyGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _privacyBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildHero(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildImageBanner(),
                      const SizedBox(height: 12),
                      ...List.generate(6, _buildAccordion),
                      const SizedBox(height: 14),
                      _buildContactCard(),
                      const SizedBox(height: 12),
                      _buildDataBadge(),
                      const SizedBox(height: 12),
                      _buildAcknowledgement(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildHero() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
    decoration: BoxDecoration(
      color: _privacyLow,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .2),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: -60,
          right: -45,
          child: _glow(_privacyAmber.withValues(alpha: .1), 190),
        ),
        Positioned(
          bottom: -70,
          left: -45,
          child: _glow(const Color(0x33930013), 145),
        ),
        Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _privacyHigh,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _privacyGold.withValues(alpha: .16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shield_outlined,
                  color: _privacyGold,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _privacySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: _privacyMint, size: 8),
                  SizedBox(width: 6),
                  Text(
                    'THÔNG TIN DỮ LIỆU • BẢN DEMO',
                    style: TextStyle(
                      color: _privacyMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bảo Mật & Dữ Liệu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _privacyText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Thông tin dành cho ứng dụng thực hành PRM393',
              textAlign: TextAlign.center,
              style: TextStyle(color: _privacyMuted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                Expanded(
                  child: _PrivacyFact(
                    icon: Icons.enhanced_encryption,
                    color: _privacyGold,
                    title: 'Firebase Auth',
                    subtitle: 'Đăng nhập',
                  ),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: _PrivacyFact(
                    icon: Icons.cloud_outlined,
                    color: _privacyMint,
                    title: 'Emulator',
                    subtitle: 'Môi trường demo',
                  ),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: _PrivacyFact(
                    icon: Icons.monetization_on_outlined,
                    color: _privacyRed,
                    title: 'Xu ảo',
                    subtitle: 'Không giao dịch',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _glow(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _buildImageBanner() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _privacyImageUrl,
            fit: BoxFit.cover,
            color: Colors.white.withValues(alpha: .4),
            colorBlendMode: BlendMode.saturation,
            errorBuilder: (context, error, stack) => Container(
              color: const Color(0xff0b0e14),
              child: const Icon(Icons.security, color: _privacyGold, size: 38),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xec0b0e14)],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHẠM VI CHÍNH SÁCH',
                  style: TextStyle(
                    color: _privacyGold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dữ liệu tài khoản và điểm trò chơi mô phỏng',
                  maxLines: 2,
                  style: TextStyle(
                    color: _privacyText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildAccordion(int index) {
    final definitions = <({IconData icon, String title, List<Widget> content})>[
      (
        icon: Icons.fingerprint,
        title: 'Dữ Liệu Ứng Dụng Sử Dụng',
        content: [
          const Text(
            'Ứng dụng dùng thông tin cần thiết để đăng nhập và vận hành trò chơi mô phỏng. Project không khai báo thu thập số điện thoại, IP hay Hardware ID để quảng cáo hoặc chống khuyến mãi.',
            style: TextStyle(color: _privacyMuted, fontSize: 12, height: 1.45),
          ),
          _detailTile(
            Icons.person_outline,
            'Tài khoản Firebase:',
            'UID và email đăng nhập; email xác minh nếu tài khoản đã xác minh.',
          ),
          _detailTile(
            Icons.account_balance_wallet_outlined,
            'Dữ liệu demo:',
            'Số dư xu ảo, hoạt động ví và dữ liệu phiên/cược cần thiết cho trò chơi.',
          ),
          _detailTile(
            Icons.badge_outlined,
            'Hồ sơ:',
            'Tên hiển thị và một số trường giao diện. Các trường đang lưu cục bộ trên màn hình chỉnh sửa chưa đồng bộ Firebase.',
          ),
        ],
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        title: 'Mục Đích Sử Dụng Dữ Liệu',
        content: [
          _purposeTile(
            Icons.login,
            _privacyGold,
            'Đăng nhập tài khoản',
            'Xác thực người dùng và tải hồ sơ tương ứng.',
          ),
          _purposeTile(
            Icons.casino_outlined,
            _privacyRed,
            'Vận hành trò chơi xu ảo',
            'Ghi nhận cược mô phỏng, số dư và lịch sử phiên.',
          ),
          _purposeTile(
            Icons.leaderboard_outlined,
            _privacyMint,
            'Hiển thị bảng xếp hạng',
            'Dùng biệt danh rút gọn và số dư điểm mô phỏng theo chức năng hiện có.',
          ),
        ],
      ),
      (
        icon: Icons.security,
        title: 'Lưu Trữ & Bảo Vệ Dữ Liệu',
        content: [
          const Text(
            'Ứng dụng sử dụng Firebase Authentication, Firestore và Cloud Functions theo cấu hình dự án. Firebase Security Rules giới hạn thao tác trực tiếp của client; các thao tác trò chơi được xử lý phía Functions.',
            style: TextStyle(color: _privacyMuted, fontSize: 12, height: 1.45),
          ),
          _detailTile(
            Icons.developer_mode,
            'Môi trường phát triển:',
            'README cấu hình Firebase Emulator cục bộ. Dữ liệu trên mỗi máy tách biệt và có thể bị xoá khi môi trường dừng.',
          ),
          _detailTile(
            Icons.phonelink_lock_outlined,
            'Lưu tạm trên thiết bị:',
            'SharedPreferences giữ một số thao tác đang chờ để hỗ trợ gửi lại an toàn; đây không phải bản sao lưu đám mây.',
          ),
          _detailTile(
            Icons.info_outline,
            'Giới hạn bảo mật:',
            'Project không công bố chứng nhận RSA 4096-bit, SSL 256-bit hay chứng nhận kiểm định độc lập.',
          ),
        ],
      ),
      (
        icon: Icons.gavel,
        title: 'Dịch Vụ Bên Ngoài & Chia Sẻ',
        content: [
          const Text(
            'Firebase là dịch vụ bên ngoài được ứng dụng sử dụng để xác thực và lưu dữ liệu. Chủ sở hữu Firebase project có thể quản trị dữ liệu theo cấu hình của project.',
            style: TextStyle(color: _privacyMuted, fontSize: 12, height: 1.45),
          ),
          _detailTile(
            Icons.block,
            'Tích hợp hiện có:',
            'Mã nguồn không tích hợp cổng thanh toán, ngân hàng, ví crypto hoặc mạng quảng cáo.',
          ),
          _detailTile(
            Icons.warning_amber_rounded,
            'Không nhập dữ liệu nhạy cảm:',
            'Không cung cấp thông tin thẻ, tài khoản ngân hàng, giấy tờ định danh hoặc mật khẩu dùng ở dịch vụ khác.',
          ),
        ],
      ),
      (
        icon: Icons.manage_accounts,
        title: 'Quyền Kiểm Soát Của Người Dùng',
        content: [
          const Text(
            'Một số thao tác có thể thực hiện ngay trong app; các quyền xuất hoặc xóa dữ liệu toàn bộ chưa được xây dựng thành chức năng.',
            style: TextStyle(color: _privacyMuted, fontSize: 12, height: 1.45),
          ),
          _controlAction(
            Icons.download,
            'Xuất dữ liệu',
            'Chưa có chức năng tải bản sao dữ liệu.',
            () => _showUnavailable(
              'Xuất dữ liệu',
              'Bản demo chưa có công cụ xuất toàn bộ dữ liệu tài khoản.',
            ),
          ),
          _controlAction(
            Icons.edit_note,
            'Chỉnh sửa hồ sơ',
            'Mở màn hình hồ sơ; thay đổi hiện tại có thể chỉ là giao diện demo.',
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EditProfileScreen(user: widget.user),
              ),
            ),
          ),
          _controlAction(
            Icons.delete_forever,
            'Xóa tài khoản / dữ liệu',
            'Chức năng xóa tài khoản Firebase chưa có trong app.',
            () => _showUnavailable(
              'Xóa tài khoản',
              'Ứng dụng chưa có luồng xóa tài khoản hoặc xóa dữ liệu. Đăng xuất không xóa dữ liệu Firebase.',
            ),
            color: _privacyRed,
          ),
        ],
      ),
      (
        icon: Icons.cookie_outlined,
        title: 'Phiên Đăng Nhập & Lưu Trữ Cục Bộ',
        content: [
          const Text(
            'Firebase Authentication quản lý trạng thái đăng nhập. Trên nền tảng web, Firebase và trình duyệt có thể dùng cơ chế lưu trữ phiên của nền tảng.',
            style: TextStyle(color: _privacyMuted, fontSize: 12, height: 1.45),
          ),
          _detailTile(
            Icons.phone_android,
            'Dữ liệu cục bộ:',
            'Một số request đang chờ và ý định tạo bàn được lưu bằng SharedPreferences để khôi phục thao tác.',
          ),
          _detailTile(
            Icons.key_off_outlined,
            'Mật khẩu:',
            'Ứng dụng không ghi mật khẩu tài khoản thành dữ liệu tuỳ ý trong SharedPreferences.',
          ),
          _detailTile(
            Icons.cleaning_services_outlined,
            'Xóa dữ liệu:',
            'Dừng hoặc xóa dữ liệu Firebase Emulator có thể làm mất dữ liệu thử nghiệm. App chưa có nút dọn toàn bộ dữ liệu.',
          ),
        ],
      ),
    ];

    final item = definitions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        decoration: BoxDecoration(
          color: _privacyLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    setState(() => _expanded[index] = !_expanded[index]),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      _iconBox(item.icon),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MỤC ${(index + 1).toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: _privacyGold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .6,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: _privacyText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded[index] ? .5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.expand_more,
                          color: _privacyMuted,
                          size: 23,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: item.content
                      .map(
                        (widget) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: widget,
                        ),
                      )
                      .toList(),
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: _expanded[index]
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 180),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: _privacyHigh,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: _privacyGold, size: 20),
  );

  Widget _detailTile(IconData icon, String title, String detail) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _privacySurface,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: _privacyGold, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: _privacyMuted,
                fontSize: 11,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(
                    color: _privacyText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _purposeTile(
    IconData icon,
    Color color,
    String title,
    String detail,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _privacySurface,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _privacyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: _privacyMuted,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _controlAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color color = _privacyGold,
  }) => Material(
    color: _privacySurface,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _privacyMuted,
                      fontSize: 10,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _privacyOutline, size: 20),
          ],
        ),
      ),
    ),
  );

  Widget _buildContactCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _privacySurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .25),
          blurRadius: 9,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _PrivacyRoundIcon(icon: Icons.admin_panel_settings_outlined),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liên Hệ & Hỗ Trợ Dữ Liệu',
                    style: TextStyle(
                      color: _privacyText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Kênh liên hệ chưa được cấu hình',
                    style: TextStyle(
                      color: _privacyGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        const Text(
          'Project hiện không khai báo DPO, email bảo mật hoặc hotline. Không gửi dữ liệu cá nhân tới địa chỉ liên hệ không có trong mã nguồn dự án.',
          style: TextStyle(color: _privacyMuted, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 10),
        _contactRow(
          icon: Icons.mail_outline,
          label: 'Email DPO / bảo mật',
          value: 'Chưa cấu hình',
        ),
        const SizedBox(height: 7),
        _contactRow(
          icon: Icons.phone_in_talk_outlined,
          label: 'Hotline hỗ trợ',
          value: 'Chưa cấu hình',
          color: _privacyRed,
        ),
      ],
    ),
  );

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    Color color = _privacyGold,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: _privacyHigh,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: _privacyMuted, fontSize: 9),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: _privacyText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showUnavailable(
            label,
            'Ứng dụng chưa có $label. Hãy liên hệ nhóm học tập qua kênh đã được nhóm cung cấp.',
          ),
          style: TextButton.styleFrom(
            foregroundColor: color,
            backgroundColor: _privacySurface,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('THÔNG TIN', style: TextStyle(fontSize: 8)),
        ),
      ],
    ),
  );

  Widget _buildDataBadge() => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: _privacyLow,
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Row(
      children: [
        _PrivacyRoundIcon(
          icon: Icons.verified_user_outlined,
          color: _privacyMint,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông Tin Bản Demo',
                style: TextStyle(
                  color: _privacyText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Không có chứng nhận bảo mật độc lập được khai báo.',
                style: TextStyle(color: _privacyMuted, fontSize: 9),
              ),
            ],
          ),
        ),
        Icon(Icons.info_outline, color: _privacyGold, size: 23),
      ],
    ),
  );

  Widget _buildAcknowledgement() => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _acknowledged ? null : _acknowledge,
          icon: Icon(
            _acknowledged ? Icons.verified : Icons.check_circle_outline,
            size: 21,
          ),
          label: Text(
            _acknowledged ? 'ĐÃ ĐỌC THÔNG TIN' : 'TÔI ĐÃ ĐỌC CHÍNH SÁCH',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _privacyGold,
            foregroundColor: const Color(0xff472a00),
            disabledBackgroundColor: _privacyMint,
            disabledForegroundColor: const Color(0xff003824),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Nút này chỉ ghi nhận trạng thái trên màn hình hiện tại; không bật thêm tính năng bảo mật.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _privacyMuted, fontSize: 9, height: 1.4),
      ),
    ],
  );
}

class _PrivacyFact extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _PrivacyFact({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
    decoration: BoxDecoration(
      color: _privacySurface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 4),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _privacyText,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _privacyMuted, fontSize: 8),
        ),
      ],
    ),
  );
}

class _PrivacyRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _PrivacyRoundIcon({required this.icon, this.color = _privacyGold});

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .15),
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 21),
  );
}
