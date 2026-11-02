import 'dart:async';

import 'package:flutter/material.dart';

/// Branded loading transition into the lobby, rebuilt from the supplied HTML.
/// Progress is only a short visual transition; it does not claim a live server
/// ping, third-party certification, or an actual security audit.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _gold = Color(0xffffc174);
  static const _steps = <_LoadingStep>[
    _LoadingStep(78, 'Đang chuẩn bị dữ liệu sảnh...'),
    _LoadingStep(86, 'Đang mở danh sách trò chơi...'),
    _LoadingStep(94, 'Đang hoàn tất giao diện...'),
    _LoadingStep(100, 'Sẵn sàng vào sảnh game!'),
  ];

  late final AnimationController _progress;
  late final AnimationController _shine;
  Timer? _stepTimer;
  int _stepIndex = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: _steps.first.percent / 100,
    );
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      if (_stepIndex < _steps.length - 1) {
        setState(() => _stepIndex++);
        _progress.animateTo(
          _steps[_stepIndex].percent / 100,
          curve: Curves.easeOutCubic,
        );
      } else {
        _stepTimer?.cancel();
        if (_finished) return;
        _finished = true;
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _progress.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff10131a),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            const Positioned(
              top: -110,
              left: 0,
              right: 0,
              child: _SplashGlow(size: 300, opacity: .16),
            ),
            const Positioned(
              top: 250,
              left: -85,
              child: _SplashGlow(size: 270, opacity: .08),
            ),
            const Positioned(
              bottom: 20,
              right: -40,
              child: _SplashGlow(size: 230, opacity: .11),
            ),
            Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Column(
                    children: [
                      _topIdentity(),
                      const Spacer(flex: 2),
                      _brandMark(),
                      const SizedBox(height: 18),
                      _brandTitle(),
                      const SizedBox(height: 20),
                      _trustBadges(),
                      const Spacer(flex: 2),
                      _progressPanel(),
                      const SizedBox(height: 20),
                      _footer(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topIdentity() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xe6272a31),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
        ),
        child: const Row(
          children: [
            _PulseDot(),
            SizedBox(width: 7),
            Text(
              'ĐIỂM MÔ PHỎNG',
              style: TextStyle(
                color: _gold,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .9,
              ),
            ),
          ],
        ),
      ),
      const Row(
        children: [
          Icon(Icons.verified_outlined, color: Color(0xfff59e0b), size: 16),
          SizedBox(width: 5),
          Text(
            'TIUXAI ARENA',
            style: TextStyle(
              color: Color(0xffd8c3ad),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _brandMark() => SizedBox(
    width: 210,
    height: 170,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xfff59e0b).withValues(alpha: .20),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Positioned(
          top: 7,
          child: Icon(
            Icons.workspace_premium,
            size: 48,
            color: _gold,
            shadows: const [Shadow(color: Color(0xaaf59e0b), blurRadius: 20)],
          ),
        ),
        Positioned(
          top: 48,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffa40217),
              boxShadow: [BoxShadow(color: Color(0x99ffb3ad), blurRadius: 12)],
            ),
          ),
        ),
        Positioned(
          left: 14,
          top: 68,
          child: Transform.rotate(
            angle: -.20,
            child: const _DiceTile(size: 64, pips: 4),
          ),
        ),
        Positioned(
          right: 14,
          top: 68,
          child: Transform.rotate(
            angle: .20,
            child: const _DiceTile(size: 64, pips: 6),
          ),
        ),
        Positioned(
          top: 57,
          child: Transform.scale(
            scale: 1.08,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gold, Color(0xfff59e0b), Color(0xff0b0e14)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 19,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(19),
                  gradient: const LinearGradient(
                    colors: [Color(0xff32353c), Color(0xff0b0e14)],
                  ),
                ),
                child: const Center(child: _RubyMark()),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _brandTitle() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GoldRule(),
          const SizedBox(width: 8),
          const Text(
            'GRAND ROYALE',
            style: TextStyle(
              color: _gold,
              fontSize: 10,
              letterSpacing: 3.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          const _GoldRule(reverse: true),
        ],
      ),
      const SizedBox(height: 5),
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'TÀI XỈU HOÀNG GIA',
          style: TextStyle(
            color: Color(0xffffd48b),
            fontSize: 33,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: [Shadow(color: Color(0x99f59e0b), blurRadius: 16)],
          ),
        ),
      ),
      const SizedBox(height: 3),
      const Text(
        'Sảnh trò chơi • Điểm mô phỏng',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xffd8c3ad),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: .5,
        ),
      ),
      const SizedBox(height: 11),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xe6272a31),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino_outlined, size: 15, color: _gold),
            SizedBox(width: 6),
            Text(
              'PHIÊN 30 GIÂY',
              style: TextStyle(
                color: _gold,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _trustBadges() => const Row(
    children: [
      Expanded(
        child: _TrustBadge(
          icon: Icons.enhanced_encryption,
          title: 'DỮ LIỆU',
          subtitle: 'Phiên trong app',
          color: Color(0xfff59e0b),
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _TrustBadge(
          icon: Icons.verified_user_outlined,
          title: 'TÀI KHOẢN',
          subtitle: 'Đăng nhập bảo vệ',
          color: _gold,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _TrustBadge(
          icon: Icons.fact_check_outlined,
          title: 'LỊCH SỬ',
          subtitle: 'Xem lại kết quả',
          color: Color(0xff56e5a9),
        ),
      ),
    ],
  );

  Widget _progressPanel() => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) {
      final step = _steps[_stepIndex];
      return Column(
        children: [
          Row(
            children: [
              const _PulseDot(color: Color(0xfff59e0b)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xffd8c3ad),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_progress.value * 100).round()}%',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _shine,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 10,
                padding: const EdgeInsets.all(1),
                color: const Color(0xff32353c),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress.value,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ClipRect(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xfff59e0b),
                                      _gold,
                                      Color(0xffffddb8),
                                    ],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x99f59e0b),
                                      blurRadius: 9,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left:
                                  (constraints.maxWidth + 44) * _shine.value -
                                  44,
                              top: -8,
                              bottom: -8,
                              width: 32,
                              child: Transform.rotate(
                                angle: -.25,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0x99ffffff),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'ĐANG CHUẨN BỊ LOBBY',
                  style: TextStyle(
                    color: Color(0xffa08e7a),
                    fontSize: 8,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'ĐIỂM ẢO',
                style: TextStyle(
                  color: Color(0xff56e5a9),
                  fontSize: 8,
                  letterSpacing: .7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _footer() => const Column(
    children: [
      Text(
        'TIUXAI ARENA • PHIÊN BẢN THỬ NGHIỆM',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xffd8c3ad),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
        ),
      ),
      SizedBox(height: 4),
      Text(
        '© Tiuxai Arena • Chỉ sử dụng điểm mô phỏng',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xffa08e7a), fontSize: 9),
      ),
    ],
  );
}

class _LoadingStep {
  final int percent;
  final String label;
  const _LoadingStep(this.percent, this.label);
}

class _DiceTile extends StatelessWidget {
  final double size;
  final int pips;
  const _DiceTile({required this.size, required this.pips});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      gradient: const LinearGradient(
        colors: [Color(0xff32353c), Color(0xff0b0e14)],
      ),
      border: Border.all(color: const Color(0xff6e593a)),
      boxShadow: const [
        BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 7)),
      ],
    ),
    child: Center(
      child: Text(
        '⚄',
        style: TextStyle(color: _SplashScreenState._gold, fontSize: size * .48),
      ),
    ),
  );
}

class _RubyMark extends StatelessWidget {
  const _RubyMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [Color(0xffffb3ad), Color(0xffa40217), Color(0xff410004)],
      ),
      boxShadow: [BoxShadow(color: Color(0x99a40217), blurRadius: 12)],
    ),
    child: Center(
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x88ffdad7),
        ),
      ),
    ),
  );
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 65,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0x99272a31),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xffe1e2eb),
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xffa08e7a), fontSize: 7),
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
      shape: BoxShape.circle,
      color: color,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .65), blurRadius: 7),
      ],
    ),
  );
}

class _GoldRule extends StatelessWidget {
  final bool reverse;
  const _GoldRule({this.reverse = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
        end: reverse ? Alignment.centerLeft : Alignment.centerRight,
        colors: [Colors.transparent, _SplashScreenState._gold],
      ),
    ),
  );
}

class _SplashGlow extends StatelessWidget {
  final double size;
  final double opacity;
  const _SplashGlow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xfff59e0b).withValues(alpha: opacity),
            blurRadius: 100,
            spreadRadius: 28,
          ),
        ],
      ),
    ),
  );
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffffc174).withValues(alpha: .035);
    for (double y = 10; y < size.height; y += 24) {
      for (double x = 10; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
