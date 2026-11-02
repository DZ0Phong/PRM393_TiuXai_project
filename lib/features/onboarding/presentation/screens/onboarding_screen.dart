import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Three page onboarding translated from the supplied HTML landing screen.
/// The original HTML makes cash, licensing, VIP return, and security claims
/// that are not implemented/verified in this points-only app, so the visual
/// sections are retained while the copy describes real app behavior.
class OnboardingScreen extends StatefulWidget {
  final User user;
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const OnboardingScreen({
    super.key,
    required this.user,
    required this.onStart,
    required this.onSkip,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _gold = Color(0xffffc174);
  static const _green = Color(0xff56e5a9);
  static const _slides = <_SlideData>[
    _SlideData(
      icon: Icons.casino_outlined,
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAtphYWUuZqAm-yVzStpUPV2f0-d1Oj8Nod_4wd_ZHefxUBAOlWF-C1fDlk9ZpsT1BYA8R3rOfse4haIVNkFVFFYKCuJnhBJLE3SN_tQsrYi6SADTpcg5waoGeNYVh6hqF1i7wPA7xeRtmiHDXbI3PbX0OEoRfMstUCFdGnbdYZDra8YQzuufFwCT6pr7-5Sj0cz5YAixWQGLStz2kmQCRubUMKleck5Gbcvbg7A58',
      badgeIcon: Icons.verified_user_outlined,
      badge: 'KẾT QUẢ TỪ MÁY CHỦ',
      metricIcon: Icons.history,
      metricLabel: 'LỊCH SỬ PHIÊN',
      metricValue: 'Xem lại kết quả',
      kicker: 'THEO DÕI RÕ RÀNG',
      title: 'Từng phiên\nđều có lịch sử',
      description:
          'Theo dõi kết quả phiên và lịch sử cược trong ứng dụng. Điểm chơi là điểm mô phỏng, không quy đổi thành tiền.',
      accent: _gold,
      art: _ArtKind.dice,
    ),
    _SlideData(
      icon: Icons.bolt,
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBok2V3pxtGqfDrwvNlCo8pLl96w3nbZYmjnpxwM6-ZFQYVmbNTxtf1h8CEANO3BsKC5eycWjiWumVmyI_Y5SBk_VMw4wcuwRUutbCEsY7ffVtJ2qWtj_tYh10wVGWVzZf4dtsW9RQr9WRGFlF-17EHhoY_TxWiTEqFTM1KvcomIexY4PicXE7w0r4CFNdd9PrZBx4FX3i-F7rG8VHNlzNS1OJedjYu7-yfaCTINgg',
      badgeIcon: Icons.timer_outlined,
      badge: 'PHIÊN 30 GIÂY',
      metricIcon: Icons.speed,
      metricLabel: 'NHỊP CHƠI',
      metricValue: 'Vào ván nhanh',
      kicker: 'THAO TÁC ĐƠN GIẢN',
      title: 'Chọn cửa,\nđặt điểm, theo dõi',
      description:
          'Tham gia các phiên trò chơi ngắn, xem thời gian còn lại và trạng thái cược ngay trên bàn chơi.',
      accent: _green,
      art: _ArtKind.speed,
    ),
    _SlideData(
      icon: Icons.workspace_premium_outlined,
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAL8o-Br9WBKrvdyrQupNhuPsn6xB3HjIu3k-HGbW6Jqe2XuzCaIELXGOoH04p_H4FQOxl89K_x_SQvm5KH77--5OduJPQoTP5VGJgUxaZcpFvWRINWUeEuJyQ6eNWzsbaFiPh2NyvpLWXsOVt9aslSYs3UR2Tlqrin2963YGed2luh2qsvLrLGFecByqSa3D3mEBVSccD89jXgQkzVh8AMIis7tr-KGQ0NwEmYC2g',
      badgeIcon: Icons.sports_esports_outlined,
      badge: 'TIUXAI ARENA',
      metricIcon: Icons.grid_view_rounded,
      metricLabel: 'TRÒ CHƠI',
      metricValue: 'Nhiều bàn trong sảnh',
      kicker: 'SẢNH GIẢI TRÍ',
      title: 'Chọn trò chơi\nbạn yêu thích',
      description:
          'Khám phá Tài Xỉu, Bầu Cua, Xóc Xóc, Poker và Ba Cây trong cùng một sảnh.',
      accent: _gold,
      art: _ArtKind.lounge,
    ),
  ];

  static const _perks = <_PerkData>[
    _PerkData(
      Icons.swap_horizontal_circle_outlined,
      'Điểm chơi miễn phí',
      'Không nạp tiền • Không rút tiền',
      'ĐIỂM ẢO',
    ),
    _PerkData(
      Icons.shield_outlined,
      'Kết quả và lịch sử phiên',
      'Theo dõi dữ liệu phiên trong ứng dụng',
      'RÕ RÀNG',
    ),
    _PerkData(
      Icons.diamond_outlined,
      'Nhiều trò chơi trong sảnh',
      'Chuyển nhanh giữa các bàn chơi',
      'TIỆN LỢI',
    ),
  ];

  final PageController _pageController = PageController();
  Timer? _autoAdvance;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    _autoAdvance?.cancel();
    _autoAdvance = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff10131a),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Stack(
            children: [
              const Positioned(
                top: -90,
                left: 50,
                child: _AmbientGlow(size: 250),
              ),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                children: [
                  _topBar(),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 416,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _slides.length,
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      itemBuilder: (context, index) => _slide(_slides[index]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _stepper(),
                  const SizedBox(height: 12),
                  ..._perks.map(_perk),
                  const SizedBox(height: 16),
                  _startButton(),
                  const SizedBox(height: 12),
                  _footer(),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topBar() => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xff272a31).withValues(alpha: .92),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulseDot(color: _green),
            SizedBox(width: 7),
            Text(
              'VIP SALON LIVE',
              style: TextStyle(
                color: _green,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      const Spacer(),
      TextButton.icon(
        onPressed: widget.onSkip,
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right, size: 18),
        label: const Text('Bỏ qua'),
        style: TextButton.styleFrom(foregroundColor: const Color(0xffd8c3ad)),
      ),
    ],
  );

  Widget _slide(_SlideData data) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 320),
    child: Column(
      key: ValueKey(data.title),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _artCard(data),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 26,
              height: 5,
              decoration: BoxDecoration(
                color: data.accent,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              data.kicker,
              style: TextStyle(
                color: data.accent,
                fontSize: 9,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          data.title,
          style: const TextStyle(
            color: Color(0xffe1e2eb),
            fontSize: 24,
            height: 1.13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          data.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffd8c3ad),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    ),
  );

  Widget _artCard(_SlideData data) => Container(
    height: 216,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          data.accent.withValues(alpha: .24),
          const Color(0xff191c22),
          const Color(0xff0b0e14),
        ],
      ),
      border: Border.all(color: const Color(0xff534434)),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
      ],
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: _Artwork(kind: data.art, accent: data.accent),
        ),
        Positioned.fill(
          child: Image.network(
            data.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const SizedBox.shrink(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .08),
                  Colors.transparent,
                  const Color(0xff0b0e14).withValues(alpha: .94),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: _GlassBadge(
            icon: data.badgeIcon,
            label: data.badge,
            color: data.accent,
          ),
        ),
        Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xe6272a31),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(
              children: [
                Icon(data.metricIcon, color: data.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.metricLabel,
                    style: const TextStyle(
                      color: Color(0xffd8c3ad),
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  data.metricValue,
                  style: TextStyle(
                    color: data.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stepper() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(_slides.length, (index) {
      final active = index == _currentPage;
      return GestureDetector(
        onTap: () => _goToPage(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: active ? 25 : 9,
            height: 6,
            decoration: BoxDecoration(
              color: active ? _gold : const Color(0xff32353c),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      );
    }),
  );

  Widget _perk(_PerkData data) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xff191c22),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xff272a31)),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 7)],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xff32353c),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(data.icon, color: _gold, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xffe1e2eb),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 9),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: data.tagColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            data.tag,
            style: TextStyle(
              color: data.tagColor,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _startButton() => SizedBox(
    height: 54,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffffb95f), Color(0xfff59e0b), Color(0xffffc174)],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [BoxShadow(color: Color(0x55f59e0b), blurRadius: 18)],
      ),
      child: FilledButton.icon(
        onPressed: widget.onStart,
        icon: const Icon(Icons.arrow_forward, size: 22),
        label: const Text('BẮT ĐẦU NGAY'),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xff2a1700),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    ),
  );

  Widget _footer() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xffa08e7a), size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Đăng nhập: ${widget.user.displayName ?? widget.user.email ?? 'Người chơi'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xffa08e7a), fontSize: 9),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      const Text(
        'Điểm mô phỏng • Không nạp/rút • Không quy đổi',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xffa08e7a), fontSize: 9),
      ),
    ],
  );
}

class _SlideData {
  final IconData icon;
  final String imageUrl;
  final IconData badgeIcon;
  final String badge;
  final IconData metricIcon;
  final String metricLabel;
  final String metricValue;
  final String kicker;
  final String title;
  final String description;
  final Color accent;
  final _ArtKind art;

  const _SlideData({
    required this.icon,
    required this.imageUrl,
    required this.badgeIcon,
    required this.badge,
    required this.metricIcon,
    required this.metricLabel,
    required this.metricValue,
    required this.kicker,
    required this.title,
    required this.description,
    required this.accent,
    required this.art,
  });
}

enum _ArtKind { dice, speed, lounge }

class _Artwork extends StatelessWidget {
  final _ArtKind kind;
  final Color accent;
  const _Artwork({required this.kind, required this.accent});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ArtworkPainter(kind: kind, accent: accent),
    child: Center(
      child: Icon(
        switch (kind) {
          _ArtKind.dice => Icons.casino,
          _ArtKind.speed => Icons.bolt,
          _ArtKind.lounge => Icons.diamond,
        },
        size: 102,
        color: accent.withValues(alpha: .78),
        shadows: const [Shadow(color: Colors.black87, blurRadius: 22)],
      ),
    ),
  );
}

class _ArtworkPainter extends CustomPainter {
  final _ArtKind kind;
  final Color accent;
  const _ArtworkPainter({required this.kind, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = accent.withValues(alpha: .17);
    canvas.drawCircle(
      Offset(size.width * .52, size.height * .38),
      size.height * .46,
      glow,
    );
    final line = Paint()
      ..color = accent.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, size.height * .42),
          width: size.width * (.42 + i * .16),
          height: size.height * (.32 + i * .13),
        ),
        line,
      );
    }
    if (kind == _ArtKind.dice || kind == _ArtKind.lounge) {
      for (var i = 0; i < 24; i++) {
        final x = (i * 67.0 + 19) % size.width;
        final y = (i * 37.0 + 11) % size.height;
        canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.5 : .8, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArtworkPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.accent != accent;
}

class _PerkData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  const _PerkData(this.icon, this.title, this.subtitle, this.tag);

  Color get tagColor =>
      tag == 'RÕ RÀNG' ? const Color(0xff56e5a9) : const Color(0xffffc174);
}

class _GlassBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _GlassBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xe632353c),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
      ],
    ),
  );
}

class _PulseDot extends StatelessWidget {
  final Color color;
  const _PulseDot({this.color = const Color(0xff56e5a9)});

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .65), blurRadius: 7),
      ],
    ),
  );
}

class _AmbientGlow extends StatelessWidget {
  final double size;
  const _AmbientGlow({required this.size});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xffffc174).withValues(alpha: .08),
            blurRadius: 65,
            spreadRadius: 24,
          ),
        ],
      ),
    ),
  );
}
