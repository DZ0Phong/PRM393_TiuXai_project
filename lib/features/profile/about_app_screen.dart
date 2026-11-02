import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';
import 'package:flutter/services.dart';

const _aboutBg = Color(0xff10131a);
const _aboutLow = Color(0xff191c22);
const _aboutSurface = Color(0xff1d2026);
const _aboutHigh = Color(0xff272a31);
const _aboutHighest = Color(0xff32353c);
const _aboutGold = Color(0xffffc174);
const _aboutAmber = Color(0xfff59e0b);
const _aboutMint = Color(0xff56e5a9);
const _aboutText = Color(0xffe1e2eb);
const _aboutMuted = Color(0xffd8c3ad);
const _aboutOutline = Color(0xffa08e7a);
const _diceImageUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuD4xkfAtfhqXXpqzuRb1R3Q6e2uZJmUPM8qSvsPCZBi3irWBSNhJL8lmKW9nfVcxQX0YHTfnY7vhRd_BLLCExYhnw1bJVOKHt_5anhcekT9FmBLoUz2Xf8IrGW-qjCqI6nEb_zqPe60e-7k5At22uBqX7rjwhEQTQ4pUAUJ-bNTm4-MokQ35oPFYGdB5THfAt-JxoQPj-9gWnPtxY7lGZqcnXvPdAahyFV5o_A7Cr7l';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _aboutHighest,
        ),
      );
  }

  Future<void> _share(BuildContext context) async {
    await Clipboard.setData(
      const ClipboardData(
        text: 'Tài Xỉu PRM393 — ứng dụng demo trò chơi bằng xu ảo.',
      ),
    );
    if (context.mounted) {
      _showMessage(context, 'Đã sao chép thông tin giới thiệu ứng dụng.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _aboutBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _aboutText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Giới Thiệu Ứng Dụng',
        style: TextStyle(
          color: _aboutGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông tin hỗ trợ',
          onPressed: () => _showMessage(
            context,
            'Ứng dụng demo PRM393 chưa cấu hình kênh hỗ trợ bên ngoài.',
          ),
          icon: const Icon(Icons.support_agent, color: _aboutGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _aboutBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                _buildBrandCard(),
                const SizedBox(height: 16),
                _buildMissionCard(),
                const SizedBox(height: 16),
                _buildFeatures(),
                const SizedBox(height: 16),
                _buildProjectInfo(),
                const SizedBox(height: 16),
                _buildChannels(context),
                const SizedBox(height: 16),
                _buildActions(context),
                const SizedBox(height: 14),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBrandCard() => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: _aboutSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .35),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          top: -55,
          right: -55,
          child: _glow(_aboutAmber.withValues(alpha: .12)),
        ),
        Positioned(
          bottom: -62,
          left: -55,
          child: _glow(const Color(0x33930013)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: _aboutAmber.withValues(alpha: .16),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _aboutAmber.withValues(alpha: .22),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _diceImageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 96,
                          height: 96,
                          color: _aboutHigh,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.casino,
                            color: _aboutGold,
                            size: 54,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _aboutAmber,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .25),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: const Text(
                          'BẢN DEMO',
                          style: TextStyle(
                            color: Color(0xff472a00),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _aboutHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: _aboutMint, size: 8),
                    SizedBox(width: 7),
                    Text(
                      'PRM393 • XU ẢO',
                      style: TextStyle(
                        color: _aboutMint,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'TÀI XỈU PRM393',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _aboutGold,
                  fontSize: 24,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'ỨNG DỤNG THỰC HÀNH FLUTTER',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _aboutMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                width: 64,
                height: 2,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _aboutGold,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              const Text(
                'Trải nghiệm trò chơi mô phỏng bằng xu ảo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffffddb8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _glow(Color color) => Container(
    width: 192,
    height: 192,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _buildMissionCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _aboutLow,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _AboutIconBox(icon: Icons.shield_rounded, color: _aboutGold),
            SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mục Tiêu & Phạm Vi',
                    style: TextStyle(
                      color: _aboutText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Môi trường thực hành và mô phỏng',
                    style: TextStyle(color: _aboutMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Ứng dụng phục vụ bài thực hành PRM393 với các trò chơi mô phỏng. Tài khoản sử dụng điểm ảo; không có giao dịch tiền thật, nạp/rút, giải thưởng hoặc quy đổi.',
          style: TextStyle(color: _aboutText, fontSize: 13, height: 1.55),
        ),
      ],
    ),
  );

  Widget _buildFeatures() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'TÍNH NĂNG CHÍNH',
          style: TextStyle(
            color: _aboutOutline,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const _FeatureTile(
        icon: Icons.casino,
        iconColor: _aboutGold,
        title: 'Nhiều trò chơi mô phỏng',
        badge: 'XU ẢO',
        description:
            'Tài Xỉu, Bầu Cua, Xóc Xóc, Poker và Ba Cây trong cùng ứng dụng.',
      ),
      const SizedBox(height: 7),
      const _FeatureTile(
        icon: Icons.account_balance_wallet_outlined,
        iconColor: _aboutMint,
        title: 'Ví điểm thực hành',
        badge: 'KHÔNG GIAO DỊCH',
        description:
            'Điểm dùng để trải nghiệm chức năng trong demo, không có nạp hoặc rút.',
      ),
      const SizedBox(height: 7),
      const _FeatureTile(
        icon: Icons.manage_accounts,
        iconColor: Color(0xffffb3ad),
        title: 'Tài khoản & hồ sơ',
        badge: 'FIREBASE AUTH',
        description:
            'Đăng nhập, hồ sơ người chơi và các màn cài đặt tài khoản.',
      ),
    ],
  );

  Widget _buildProjectInfo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'THÔNG TIN DỰ ÁN',
          style: TextStyle(
            color: _aboutOutline,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _aboutLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .24),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          children: [
            _ProjectInfoRow(
              icon: Icons.school_outlined,
              color: _aboutGold,
              title: 'Dự án học tập PRM393',
              detail: 'Phiên bản demo chạy trên Firebase Emulator',
            ),
            _AboutDivider(),
            _ProjectInfoRow(
              icon: Icons.cloud_outlined,
              color: _aboutMint,
              title: 'Xử lý trò chơi phía máy chủ',
              detail: 'Điểm và kết quả được quản lý bởi Cloud Functions',
            ),
            _AboutDivider(),
            _ProjectInfoRow(
              icon: Icons.info_outline,
              color: Color(0xffffb3ad),
              title: 'Giới hạn bản demo',
              detail: 'Không phải dịch vụ casino hoặc nền tảng thanh toán',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildChannels(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          'THÔNG TIN & HỖ TRỢ',
          style: TextStyle(
            color: _aboutOutline,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const SizedBox(height: 8),
      _ChannelTile(
        icon: Icons.menu_book_outlined,
        color: _aboutGold,
        title: 'Tài liệu dự án',
        subtitle: 'Hướng dẫn chạy và thông tin kỹ thuật',
        onTap: () => _showMessage(
          context,
          'Tài liệu nằm trong thư mục docs của mã nguồn dự án.',
        ),
      ),
      const SizedBox(height: 7),
      _ChannelTile(
        icon: Icons.support_agent,
        color: _aboutMint,
        title: 'Kênh hỗ trợ',
        subtitle: 'Chưa cấu hình kênh liên hệ bên ngoài',
        onTap: () => _showMessage(
          context,
          'Project demo chưa cấu hình fanpage, Telegram hoặc hotline.',
        ),
      ),
      const SizedBox(height: 7),
      _ChannelTile(
        icon: Icons.bug_report_outlined,
        color: const Color(0xffffb3ad),
        title: 'Báo lỗi ứng dụng',
        subtitle: 'Chức năng gửi báo lỗi chưa được kết nối',
        onTap: () => _showMessage(
          context,
          'Bạn có thể ghi nhận lỗi trong tài liệu/bảng công việc của nhóm.',
        ),
      ),
      const SizedBox(height: 7),
      _ChannelTile(
        icon: Icons.mail_outline,
        color: const Color(0xffffddb8),
        title: 'Liên hệ nhóm phát triển',
        subtitle: 'Không có email hỗ trợ được cấu hình trong app',
        onTap: () => _showMessage(
          context,
          'Ứng dụng chưa đăng ký địa chỉ email liên hệ.',
        ),
      ),
    ],
  );

  Widget _buildActions(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.share, size: 21),
          label: const Text('Chia Sẻ Thông Tin Ứng Dụng'),
          style: FilledButton.styleFrom(
            backgroundColor: _aboutGold,
            foregroundColor: const Color(0xff472a00),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
      const SizedBox(height: 9),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showMessage(
            context,
            'Cảm ơn bạn đã quan tâm đến ứng dụng demo PRM393.',
          ),
          icon: const Icon(Icons.star, size: 20),
          label: const Text('Đánh Giá Ứng Dụng'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _aboutGold,
            side: const BorderSide(color: Color(0x33ffc174)),
            backgroundColor: _aboutHigh,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildFooter() => const Column(
    children: [
      Text(
        '© 2026 • Dự án thực hành PRM393',
        textAlign: TextAlign.center,
        style: TextStyle(color: _aboutOutline, fontSize: 11),
      ),
      SizedBox(height: 4),
      Text(
        'Chỉ dùng xu ảo • Không giao dịch tiền thật',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xff786b60), fontSize: 9),
      ),
    ],
  );
}

class _AboutIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _AboutIconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: _aboutHigh,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 20),
  );
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String badge;
  final String description;

  const _FeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _aboutSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .16),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _aboutText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _aboutHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _aboutMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProjectInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  const _ProjectInfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AboutIconBox(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _aboutText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: _aboutMuted,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AboutDivider extends StatelessWidget {
  const _AboutDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 7),
    child: Divider(height: 1, color: Color(0x2232353c)),
  );
}

class _ChannelTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: _aboutSurface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _AboutIconBox(icon: icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _aboutText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _aboutMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right, color: _aboutOutline, size: 20),
          ],
        ),
      ),
    ),
  );
}
