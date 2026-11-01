import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterTab = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _busy = false;
  String? _errorMessage;
  String? _successMessage;
  bool _soundEnabled = true;

  // Marquee simulated winners
  int _winnerIndex = 0;
  Timer? _winnerTimer;
  final List<String> _simulatedWinners = const [
    'User vip_88*** vừa nổ hũ +145.000 Xu (Bão Tam 6)',
    'User dai_gia*** vừa ăn Tài +98.000 Xu phiên #8821',
    'User poker_pro*** vừa thắng Pot +260.000 Xu bàn VIP',
    'Tân thủ hoang_gia*** vừa nhận +10.000 Xu khởi nghiệp',
    'User thantai_*** vừa thắng Bầu Cua 3 Cua +120.000 Xu',
  ];

  @override
  void initState() {
    super.initState();
    _accountController.addListener(() {
      setState(() {});
    });
    _winnerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _winnerIndex = (_winnerIndex + 1) % _simulatedWinners.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _winnerTimer?.cancel();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _formatEmail(String raw) {
    final text = raw.trim();
    if (text.contains('@')) return text;
    // Tự động thêm đuôi @demo.test nếu người dùng chỉ nhập username để thuận tiện trên Emulator
    return '$text@demo.test';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final accountText = _accountController.text.trim();
    final passwordText = _passwordController.text;

    if (accountText.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tài khoản hoặc email.');
      return;
    }
    if (passwordText.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final emailToUse = _formatEmail(accountText);

    try {
      if (_isRegisterTab) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailToUse,
          password: passwordText,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailToUse,
          password: passwordText,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _getFriendlyAuthError(e.code, e.message);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể kết nối máy chủ: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _getFriendlyAuthError(String code, String? defaultMsg) {
    switch (code) {
      case 'user-not-found':
        return 'Tài khoản không tồn tại. Vui lòng bấm tab "Đăng Ký".';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Sai mật khẩu hoặc tài khoản. Vui lòng kiểm tra lại.';
      case 'email-already-in-use':
        return 'Tài khoản này đã tồn tại. Vui lòng bấm "Đăng Nhập".';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ (ví dụ: user@demo.test).';
      case 'weak-password':
        return 'Mật khẩu quá yếu (cần tối thiểu 6 ký tự).';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa bởi Quản trị viên.';
      default:
        return defaultMsg ?? 'Lỗi xác thực ($code). Vui lòng thử lại.';
    }
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
          style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
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

  void _fillQuickAdmin() {
    _accountController.text = 'admin@demo.test';
    _passwordController.text = 'Demo123456!';
    setState(() {
      _isRegisterTab = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff10131a),
      body: Stack(
        children: [
          // Ambient Golden Glow Background
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 380,
                height: 280,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x2effc174),
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
                // 1. Top Header Bar (VIP Macau Salon)
                _buildTopBar(),

                // Scrollable Content
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        children: [
                          // 2. Brand Identity Header (Logo + Titles)
                          _buildBrandHeader(),
                          const SizedBox(height: 16),

                          // 3. Mini Banner Quà Khởi Nghiệp
                          _buildWelcomeGiftBanner(),
                          const SizedBox(height: 16),

                          // 4. Dual Tab: Đăng Nhập / Đăng Ký
                          _buildTabSelector(),
                          const SizedBox(height: 14),

                          // 5. Main Card Form
                          _buildAuthFormCard(),
                          const SizedBox(height: 16),

                          // 6. Live Marquee Nổ Hũ / Người Thắng
                          _buildMarqueeWinner(),
                          const SizedBox(height: 16),

                          // 7. Footer CSKH & Chứng nhận an toàn
                          _buildFooter(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
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
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xff0b0e14).withValues(alpha: 0.6),
        border: const Border(
          bottom: BorderSide(color: Color(0x1affffff)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.verified, color: Color(0xffffc174), size: 18),
              SizedBox(width: 6),
              Text(
                'VIP MACAU SALON',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Nút Demo Admin tiện lợi
              InkWell(
                onTap: _fillQuickAdmin,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x33ffc174)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.admin_panel_settings, color: Color(0xffffc174), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Demo Admin',
                        style: TextStyle(
                          color: Color(0xffffc174),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sound Toggle
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  _soundEnabled ? Icons.volume_up : Icons.volume_off,
                  color: const Color(0xffd8c3ad),
                ),
                tooltip: 'Âm thanh',
                onPressed: () {
                  setState(() => _soundEnabled = !_soundEnabled);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text(_soundEnabled ? 'Đã bật âm thanh' : 'Đã tắt âm thanh'),
                    ),
                  );
                },
              ),

              // CSKH 24/7
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.support_agent, color: Color(0xffffc174)),
                tooltip: 'CSKH 24/7',
                onPressed: () => _showInfoDialog(
                  'Hỗ Trợ Khách Hàng',
                  'Hệ thống phòng game phục vụ học tập PRM393.\nHotline VIP: 1900 8888\nEmail: cskh@tiuxai.edu.vn',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Glowing Logo Badge
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0x66ffc174),
                    Color(0x00ffc174),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffffc174).withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xff2a1700), Color(0xff191c22)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xffffc174), width: 2),
              ),
              child: const Icon(
                Icons.casino,
                color: Color(0xffffc174),
                size: 42,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffa40217),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.stars, color: Color(0xffffc174), size: 11),
                    SizedBox(width: 4),
                    Text(
                      'VIP MACAU',
                      style: TextStyle(
                        color: Color(0xffffdad7),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Title
        const Text(
          'TÀI XỈU HOÀNG GIA',
          style: TextStyle(
            color: Color(0xffffc174),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'CỔNG GAME QUỐC TẾ • ĐIỂM ẢO PRM393',
          style: TextStyle(
            color: Color(0xffa08e7a),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),

        // Live status chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xff272a31).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x22ffffff)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 3.5,
                backgroundColor: Color(0xff56e5a9),
              ),
              SizedBox(width: 6),
              Text(
                'Đẳng Cấp Thượng Lưu • Xu Ảo Mô Phỏng',
                style: TextStyle(
                  color: Color(0xff56e5a9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeGiftBanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xff410004),
            Color(0xff272a31),
            Color(0xff1d2026),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x33ffb3ad)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xffffc174).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.redeem, color: Color(0xffffc174), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'QUÀ KHỞI NGHIỆP',
                      style: TextStyle(
                        color: Color(0xffffc174),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xff30c88f),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '+10.000 XU',
                        style: TextStyle(
                          color: Color(0xff003824),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Đăng ký tạo tài khoản nhận ngay 10.000 Xu tân thủ!',
                  style: TextStyle(
                    color: Color(0xffe1e2eb),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffffc174),
              foregroundColor: const Color(0xff472a00),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(54, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _isRegisterTab = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vui lòng tạo tài khoản mới để nhận 10.000 Xu khởi nghiệp!'),
                ),
              );
            },
            child: const Text(
              'NHẬN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xff0b0e14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22ffffff)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_busy) return;
                setState(() {
                  _isRegisterTab = false;
                  _errorMessage = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !_isRegisterTab ? const Color(0xff272a31) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isRegisterTab
                      ? const [BoxShadow(color: Colors.black45, blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_open,
                        size: 16,
                        color: !_isRegisterTab ? const Color(0xffffc174) : const Color(0xffa08e7a),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đăng Nhập',
                        style: TextStyle(
                          color: !_isRegisterTab ? const Color(0xffffc174) : const Color(0xffa08e7a),
                          fontSize: 14,
                          fontWeight: !_isRegisterTab ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_busy) return;
                setState(() {
                  _isRegisterTab = true;
                  _errorMessage = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _isRegisterTab ? const Color(0xff272a31) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isRegisterTab
                      ? const [BoxShadow(color: Colors.black45, blurRadius: 4)]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.how_to_reg,
                        size: 16,
                        color: _isRegisterTab ? const Color(0xffffc174) : const Color(0xffa08e7a),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đăng Ký',
                        style: TextStyle(
                          color: _isRegisterTab ? const Color(0xffffc174) : const Color(0xffa08e7a),
                          fontSize: 14,
                          fontWeight: _isRegisterTab ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff191c22).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22ffc174)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input: Tài khoản / Email
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'TÀI KHOẢN / EMAIL',
                style: TextStyle(
                  color: Color(0xffd8c3ad),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'yêu cầu VIP ID',
                style: TextStyle(color: Color(0xffffc174), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xff0b0e14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33ffffff)),
            ),
            child: TextField(
              controller: _accountController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_circle, color: Color(0xffffc174), size: 20),
                suffixIcon: _accountController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xffa08e7a), size: 18),
                        onPressed: () => _accountController.clear(),
                      )
                    : null,
                hintText: 'Nhập tên tài khoản hoặc email...',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Input: Mật khẩu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'MẬT KHẨU BẢO MẬT',
                style: TextStyle(
                  color: Color(0xffd8c3ad),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.verified_user, color: Color(0xff56e5a9), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'SSL 256-BIT',
                    style: TextStyle(color: Color(0xff56e5a9), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xff0b0e14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33ffffff)),
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock, color: Color(0xffffc174), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xffd8c3ad),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                hintText: '••••••••••••',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Options: Remember me & Forgot Password
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: const Color(0xffffc174),
                      checkColor: const Color(0xff472a00),
                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ghi nhớ phiên đăng nhập',
                    style: TextStyle(color: Color(0xffe1e2eb), fontSize: 12),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showInfoDialog(
                  'Quên Mật Khẩu',
                  'Trong môi trường demo PRM393, bạn có thể tạo tài khoản mới ngay lập tức hoặc đăng nhập bằng tài khoản Quản trị demo (admin@demo.test / Demo123456!).',
                ),
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    color: Color(0xffffc174),
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),

          // Error / Success Banner
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff690005).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffffb4ab)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xffffb4ab), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xffffdad6), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_successMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff003824).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xff56e5a9)),
              ),
              child: Text(
                _successMessage!,
                style: const TextStyle(color: Color(0xff6ffbbe), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // 4. CTA Nút bấm Đăng Nhập / Đăng Ký Chính (Golden Amber Gradient)
          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Color(0xfff59e0b),
                  Color(0xffffc174),
                  Color(0xfff59e0b),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xfff59e0b).withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy ? null : _submit,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xff472a00),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bolt, color: Color(0xff472a00), size: 22),
                            const SizedBox(width: 6),
                            Text(
                              _isRegisterTab ? 'TẠO TÀI KHOẢN NGAY' : 'ĐĂNG NHẬP NGAY',
                              style: const TextStyle(
                                color: Color(0xff472a00),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Fast Social Authentication Section
          Row(
            children: const [
              Expanded(child: Divider(color: Color(0x33ffffff))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'HOẶC KẾT NỐI SIÊU TỐC',
                  style: TextStyle(
                    color: Color(0xffa08e7a),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Color(0x33ffffff))),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildSocialButton(
                label: 'Facebook',
                icon: Icons.facebook,
                color: const Color(0xffffc174),
                onTap: () => _showInfoDialog(
                  'Kết nối Facebook',
                  'Chức năng liên kết mạng xã hội đang cấu hình trong phiên bản thử nghiệm.',
                ),
              ),
              const SizedBox(width: 8),
              _buildSocialButton(
                label: 'Telegram',
                icon: Icons.send,
                color: const Color(0xff56e5a9),
                onTap: () => _showInfoDialog(
                  'Telegram VIP Bot',
                  'Bot hỗ trợ thông báo phiên và tặng xu ảo Telegram đang phát triển.',
                ),
              ),
              const SizedBox(width: 8),
              _buildSocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata,
                color: const Color(0xffffb4ab),
                onTap: () => _showInfoDialog(
                  'Đăng nhập Google',
                  'Vui lòng dùng Email/Mật khẩu hoặc tài khoản demo để đăng nhập trực tiếp.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xff272a31),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x1affffff)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 4),
              Text(
                label,
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

  Widget _buildMarqueeWinner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xff0b0e14).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x22ffc174)),
      ),
      child: Row(
        children: [
          Row(
            children: const [
              Icon(Icons.military_tech, color: Color(0xffffc174), size: 18),
              SizedBox(width: 4),
              Text(
                'Nổ Hũ:',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _simulatedWinners[_winnerIndex],
                key: ValueKey(_winnerIndex),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xff56e5a9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Fast Support Bar
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showInfoDialog(
                  'Hotline VIP',
                  'Tổng đài hỗ trợ 24/7 cho sinh viên PRM393: 1900 8888 (Miễn phí cước).',
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.phone_in_talk, color: Color(0xffffc174), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Hotline 24/7 VIP',
                        style: TextStyle(color: Color(0xffe1e2eb), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _showInfoDialog(
                  'CSKH Live Chat',
                  'Kênh chat hỗ trợ trực tuyến: Phục vụ giải đáp luật chơi, tài khoản điểm ảo.',
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.forum, color: Color(0xff56e5a9), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'CSKH Live Chat',
                        style: TextStyle(color: Color(0xffe1e2eb), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Security badges
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: const [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Color(0xff56e5a9), size: 12),
                SizedBox(width: 3),
                Text(
                  'MÃ HÓA SSL 256-BIT',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text('•', style: TextStyle(color: Color(0xff534434))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Color(0xffffc174), size: 12),
                SizedBox(width: 3),
                Text(
                  'CHỨNG NHẬN PRM393',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text('•', style: TextStyle(color: Color(0xff534434))),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, color: Color(0xffffb3ad), size: 12),
                SizedBox(width: 3),
                Text(
                  'BẢO MẬT 100%',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        const Text(
          'Bản quyền © 2026 Tài Xỉu Hoàng Gia VIP Salon • Dự án thực hành PRM393.\nChỉ dùng xu ảo, không tiền thật và không đổi thưởng.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xff534434),
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
