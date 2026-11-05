import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

const _termsBg = Color(0xff10131a);
const _termsLow = Color(0xff191c22);
const _termsSurface = Color(0xff1d2026);
const _termsHigh = Color(0xff272a31);
const _termsHighest = Color(0xff32353c);
const _termsGold = Color(0xffffc174);
const _termsAmber = Color(0xfff59e0b);
const _termsMint = Color(0xff56e5a9);
const _termsRed = Color(0xffffb3ad);
const _termsText = Color(0xffe1e2eb);
const _termsMuted = Color(0xffd8c3ad);
const _termsOutline = Color(0xffa08e7a);
const _termsLoungeImage =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuA2QZVzGmHhyBVoKAWqRIOhEoQ4fNsPyQEyqn2z4nNqTbyYzE1DX8H81WiLGllyufZu7oqfRuiGqFQWZDsAnaTihVoqDlQNloS4FsC-R_VSXK06WbnxT-p2_-VrQEXD2-7Zsm98xz2T9KAvZ0t6xJPuAB-CtMKOF2dvIMYmqUMon3nRapT9fWFGB_PSwey2uiSzDqWOUR_b5sn9O2vmXJnfnSO-LIvo3q2_wxiSboR4';

class TermsOfUseScreen extends StatefulWidget {
  const TermsOfUseScreen({super.key});

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> {
  final _sectionKeys = List.generate(5, (_) => GlobalKey());
  bool _hasRead = false;
  bool _acknowledged = false;

  void _jumpTo(int index) {
    final target = _sectionKeys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOut,
      alignment: .08,
    );
  }

  void _confirmRead() {
    if (!_hasRead || _acknowledged) return;
    setState(() => _acknowledged = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Đã ghi nhận xác nhận trong phiên demo này.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _termsHighest,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _termsBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _termsText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Điều Khoản Sử Dụng',
        style: TextStyle(
          color: _termsGold,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông tin ứng dụng',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: _termsSurface,
              title: const Text(
                'Bản demo học tập',
                style: TextStyle(color: _termsGold),
              ),
              content: const Text(
                'Nội dung này mô tả ứng dụng PRM393 dùng điểm ảo, không phải hợp đồng hay tư vấn pháp lý.',
                style: TextStyle(color: _termsText, height: 1.45),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.info_outline, color: _termsGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _termsBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                _buildIntroCard(),
                const SizedBox(height: 10),
                _buildBanner(),
                const SizedBox(height: 14),
                _buildQuickLinks(),
                const SizedBox(height: 10),
                _TermsSection(
                  sectionKey: _sectionKeys[0],
                  number: '1',
                  title: 'Phạm vi sử dụng & đối tượng',
                  badge: 'BẢN DEMO',
                  badgeColor: _termsRed,
                  description:
                      'Ứng dụng được xây dựng phục vụ bài thực hành PRM393 và mô phỏng một số trò chơi bằng điểm ảo.',
                  children: const [
                    _TermsBullet(
                      icon: Icons.school_outlined,
                      title: 'Mục đích:',
                      detail:
                          'Chỉ dùng để học tập, kiểm thử giao diện và luồng chơi. Đây không phải cổng casino hay dịch vụ cá cược.',
                    ),
                    _TermsBullet(
                      icon: Icons.monetization_on_outlined,
                      title: 'Điểm ảo:',
                      detail:
                          'Số dư trong ứng dụng là dữ liệu mô phỏng; không có giá trị tiền tệ và không thể quy đổi.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TermsSection(
                  sectionKey: _sectionKeys[1],
                  number: '2',
                  title: 'Tài khoản & dữ liệu',
                  badge: 'TÀI KHOẢN DEMO',
                  badgeColor: _termsMuted,
                  description:
                      'Tài khoản được dùng để đăng nhập và lưu trạng thái chơi mô phỏng trong môi trường Firebase của ứng dụng.',
                  children: const [
                    _TermsBullet(
                      icon: Icons.password_outlined,
                      title: 'Bảo vệ thông tin đăng nhập:',
                      detail:
                          'Không chia sẻ mật khẩu hoặc mã xác thực. Không nhập thông tin ngân hàng, giấy tờ định danh hay dữ liệu nhạy cảm vào bản demo.',
                    ),
                    _TermsBullet(
                      icon: Icons.storage_outlined,
                      title: 'Dữ liệu thử nghiệm:',
                      detail:
                          'Theo cấu hình phát triển của dự án, Firebase Emulator chạy cục bộ; dữ liệu máy này không đồng bộ với máy khác và có thể bị xoá khi dừng môi trường.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TermsSection(
                  sectionKey: _sectionKeys[2],
                  number: '3',
                  title: 'Luật chơi & cách chốt phiên',
                  badge: 'ĐỌC KỸ',
                  badgeColor: _termsMint,
                  description:
                      'Luật từng trò được mô tả trong project. Kết quả phiên được xử lý bởi Cloud Functions; đây không phải hệ thống chứng minh tính ngẫu nhiên công bằng.',
                  children: const [
                    _TermsBullet(
                      icon: Icons.cloud_done_outlined,
                      title: 'Xử lý kết quả:',
                      detail:
                          'Máy chủ công bố kết quả hợp lệ và thanh toán điểm ảo theo luật của từng trò. Không cam kết mọi phiên được sinh ngẫu nhiên độc lập.',
                    ),
                    _TermsBullet(
                      icon: Icons.fact_check_outlined,
                      title: 'Không có chứng minh hash:',
                      detail:
                          'Ứng dụng không công bố cơ chế provably fair hoặc cho phép người chơi tự kiểm chứng bằng SHA-256.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TermsSection(
                  sectionKey: _sectionKeys[3],
                  number: '4',
                  title: 'Điểm ảo & giao dịch',
                  badge: 'KHÔNG TIỀN THẬT',
                  badgeColor: _termsGold,
                  description:
                      'Project không cung cấp chức năng nạp, rút, chuyển tiền, ví crypto hoặc trao đổi điểm lấy tài sản.',
                  children: const [
                    _TermsBullet(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Không giao dịch:',
                      detail:
                          'Không gửi tiền hoặc cung cấp thông tin thẻ/ngân hàng cho bất kỳ ai liên quan đến bản demo này.',
                    ),
                    _TermsBullet(
                      icon: Icons.currency_exchange,
                      title: 'Không quy đổi:',
                      detail:
                          'Điểm ảo không thể mua bán, chuyển nhượng, đổi thành tiền, quà tặng hoặc hiện vật.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TermsSection(
                  sectionKey: _sectionKeys[4],
                  number: '5',
                  title: 'Sử dụng có trách nhiệm',
                  badge: 'TRẢI NGHIỆM AN TOÀN',
                  badgeColor: _termsMint,
                  description:
                      'Hãy xem đây là mô phỏng học tập. Nếu trò chơi gây khó chịu hoặc áp lực, hãy dừng sử dụng.',
                  children: const [
                    _TermsBullet(
                      icon: Icons.timer_outlined,
                      title: 'Chủ động thời gian:',
                      detail:
                          'Nghỉ giải lao khi cần. Không dùng ứng dụng để đánh cược hoặc tìm cách kiếm tiền.',
                    ),
                    _TermsBullet(
                      icon: Icons.block_outlined,
                      title: 'Giới hạn chức năng:',
                      detail:
                          'Bản demo không có công cụ tự loại trừ hoặc giới hạn cược theo ngày/tuần như nội dung của một dịch vụ thực tế.',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCommitmentCard(),
                const SizedBox(height: 12),
                _buildAcknowledgement(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildIntroCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _termsHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .35),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -48,
          bottom: -54,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: _termsAmber.withValues(alpha: .09),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xff0b0e14),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.policy, color: _termsGold, size: 36),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _termsGold.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined, color: _termsGold, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'DỰ ÁN PRM393 • VNĐ MÔ PHỎNG',
                    style: TextStyle(
                      color: _termsGold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thông Tin Sử Dụng Demo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _termsGold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, color: _termsMint, size: 15),
                SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Thông tin dự án • cập nhật 2026',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _termsMuted, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBanner() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _termsLoungeImage,
            fit: BoxFit.cover,
            color: Colors.white.withValues(alpha: .45),
            colorBlendMode: BlendMode.saturation,
            errorBuilder: (context, error, stack) => Container(
              color: const Color(0xff0b0e14),
              child: const Icon(Icons.gavel, color: _termsGold, size: 40),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xee0b0e14),
                  Color(0xa60b0e14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: _termsGold, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'MINH BẠCH • MÔ PHỎNG • VNĐ',
                      style: TextStyle(
                        color: _termsGold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  'Đây không phải dịch vụ cá cược hay thanh toán.',
                  maxLines: 2,
                  style: TextStyle(
                    color: _termsText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildQuickLinks() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'MỤC LỤC ĐIỀU HƯỚNG',
                style: TextStyle(
                  color: _termsMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
            ),
            Icon(Icons.touch_app, color: _termsGold, size: 14),
            SizedBox(width: 3),
            Text(
              'Chạm để xem',
              style: TextStyle(color: _termsGold, fontSize: 9),
            ),
          ],
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _QuickLink(
              icon: Icons.school_outlined,
              label: 'Phạm vi demo',
              onTap: () => _jumpTo(0),
            ),
            _QuickLink(
              icon: Icons.person_outline,
              label: 'Tài khoản',
              onTap: () => _jumpTo(1),
            ),
            _QuickLink(
              icon: Icons.security,
              label: 'Luật chơi',
              onTap: () => _jumpTo(2),
            ),
            _QuickLink(
              icon: Icons.currency_exchange,
              label: 'Điểm ảo',
              onTap: () => _jumpTo(3),
            ),
            _QuickLink(
              icon: Icons.spa_outlined,
              label: 'Trách nhiệm',
              onTap: () => _jumpTo(4),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildCommitmentCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _termsHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .28),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: const Column(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Color(0x22ffc174),
          child: Icon(Icons.school_outlined, color: _termsGold, size: 27),
        ),
        SizedBox(height: 9),
        Text(
          'Lưu Ý Về Bản Demo',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _termsText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Đây là bản mô phỏng dùng điểm ảo. Kết quả hợp lệ được máy chủ xử lý; ứng dụng không cam kết hoặc chứng minh mọi phiên là ngẫu nhiên độc lập.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _termsMuted, fontSize: 11, height: 1.45),
        ),
      ],
    ),
  );

  Widget _buildAcknowledgement() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xff0b0e14),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .4),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _hasRead,
              onChanged: _acknowledged
                  ? null
                  : (value) => setState(() => _hasRead = value ?? false),
              activeColor: _termsAmber,
              checkColor: const Color(0xff472a00),
              side: const BorderSide(color: _termsOutline),
            ),
            const SizedBox(width: 5),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: _termsText,
                      fontSize: 11,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(text: 'Tôi xác nhận đã đọc và hiểu đây là '),
                      TextSpan(
                        text: 'ứng dụng demo dùng VNĐ mô phỏng',
                        style: TextStyle(
                          color: _termsGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            ', không có tiền thật, giao dịch, giải thưởng hoặc quy đổi.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _hasRead && !_acknowledged ? _confirmRead : null,
            icon: Icon(
              _acknowledged ? Icons.check_circle : Icons.thumb_up,
              size: 20,
            ),
            label: Text(
              _acknowledged ? 'ĐÃ XÁC NHẬN ĐỌC' : 'TÔI ĐÃ ĐỌC & HIỂU',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _termsAmber,
              foregroundColor: const Color(0xff472a00),
              disabledBackgroundColor: _termsHighest,
              disabledForegroundColor: _termsMuted,
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
        if (_acknowledged) ...[
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _termsMint.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt, color: _termsMint, size: 17),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Đã ghi nhận xác nhận trong phiên demo này.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _termsMint, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 5,
          children: [
            _FooterTag(icon: Icons.school_outlined, label: 'PRM393'),
            _FooterTag(icon: Icons.monetization_on_outlined, label: 'VNĐ MÔ PHỎNG'),
            _FooterTag(icon: Icons.info_outline, label: 'KHÔNG GIAO DỊCH'),
          ],
        ),
      ],
    ),
  );
}

class _TermsSection extends StatelessWidget {
  final GlobalKey sectionKey;
  final String number;
  final String title;
  final String badge;
  final Color badgeColor;
  final String description;
  final List<Widget> children;

  const _TermsSection({
    required this.sectionKey,
    required this.number,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.description,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: sectionKey,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _termsSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .28),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _termsHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(
                  color: _termsGold,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _termsGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              constraints: const BoxConstraints(maxWidth: 105),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                badge,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          description,
          style: const TextStyle(
            color: _termsMuted,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(top: 6), child: child),
        ),
      ],
    ),
  );
}

class _TermsBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _TermsBullet({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _termsLow,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, color: _termsGold, size: 19),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: _termsText,
                fontSize: 11,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: detail,
                  style: const TextStyle(color: _termsMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7, top: 2, bottom: 2),
    child: Material(
      color: _termsHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _termsGold, size: 15),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(color: _termsText, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FooterTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FooterTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _termsMuted, size: 13),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          color: _termsMuted,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .25,
        ),
      ),
    ],
  );
}
