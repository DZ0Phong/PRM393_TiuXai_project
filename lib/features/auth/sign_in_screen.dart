import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'password_recovery_screen.dart';

class SignInScreen extends StatefulWidget {
  final bool initialRegisterTab;
  const SignInScreen({super.key, this.initialRegisterTab = false});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool _isRegisterTab;

  // Controllers cho Đăng Nhập
  final _loginAccountController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _rememberMe = true;

  // Controllers cho Đăng Ký
  final _regNicknameController = TextEditingController(text: 'hoangtutaixiu99');
  final _regPasswordController = TextEditingController(text: 'HoangGiaVIP@2025');
  final _regConfirmPasswordController = TextEditingController(text: 'HoangGiaVIP@2025');
  final _regPhoneController = TextEditingController();
  final _regGiftcodeController = TextEditingController(text: 'VIPTAIXIU100K');
  bool _obscureRegPassword = true;
  bool _obscureRegConfirm = true;
  bool _regTermsAccepted = true;
  bool _giftcodeApplied = true;

  bool _busy = false;
  String? _errorMessage;
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
    _isRegisterTab = widget.initialRegisterTab;

    _loginAccountController.addListener(() => setState(() {}));
    _regNicknameController.addListener(() => setState(() {}));
    _regPasswordController.addListener(() => setState(() {}));
    _regConfirmPasswordController.addListener(() => setState(() {}));

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
    _loginAccountController.dispose();
    _loginPasswordController.dispose();
    _regNicknameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regPhoneController.dispose();
    _regGiftcodeController.dispose();
    super.dispose();
  }

  String _formatEmail(String raw) {
    final text = raw.trim();
    if (text.contains('@')) return text;
    return '$text@demo.test';
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1;
    final hasLetters = password.contains(RegExp(r'[a-zA-Z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    if (password.length >= 8 && hasLetters && (hasDigits || hasSpecial)) {
      return 3; // Mạnh
    }
    return 2; // Trung bình
  }

  bool get _isNicknameValid {
    final nick = _regNicknameController.text.trim();
    return nick.length >= 4 && nick.length <= 20 && !nick.contains(' ');
  }

  bool get _isPasswordMatch {
    return _regPasswordController.text.isNotEmpty &&
        _regPasswordController.text == _regConfirmPasswordController.text;
  }

  Future<void> _submitLogin() async {
    if (_busy) return;
    final accountText = _loginAccountController.text.trim();
    final passwordText = _loginPasswordController.text;

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
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _formatEmail(accountText),
        password: passwordText,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _getFriendlyAuthError(e.code, e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRegister() async {
    if (_busy) return;
    final nick = _regNicknameController.text.trim();
    final pwd = _regPasswordController.text;
    final confirmPwd = _regConfirmPasswordController.text;

    if (nick.isEmpty || nick.length < 4) {
      setState(() => _errorMessage = 'Tên đăng nhập phải từ 4 - 20 ký tự.');
      return;
    }
    if (pwd.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu phải có ít nhất 6 ký tự.');
      return;
    }
    if (pwd != confirmPwd) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    if (!_regTermsAccepted) {
      setState(() => _errorMessage = 'Bạn cần đồng ý với điều khoản dịch vụ để tiếp tục.');
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
          });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _formatEmail(nick),
        password: pwd,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _getFriendlyAuthError(e.code, e.message));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể kết nối máy chủ: $e');
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
        return 'Tên tài khoản này đã có người sử dụng. Hãy chọn tên khác.';
      case 'invalid-email':
        return 'Định dạng email hoặc tài khoản không hợp lệ.';
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
    _loginAccountController.text = 'admin@demo.test';
    _loginPasswordController.text = 'Demo123456!';
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
          // Quầng sáng nền vàng kim mờ ảo
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
                // Top Header Bar
                _buildTopBar(),

                // Scrollable Content
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        children: [
                          // Brand Presentation Section
                          _buildBrandHeader(),
                          const SizedBox(height: 16),

                          // Segmented Auth Tab Switcher
                          _buildTabSelector(),
                          const SizedBox(height: 14),

                          // Main Card: Đăng Ký hoặc Đăng Nhập
                          if (_isRegisterTab)
                            _buildRegisterCardForm()
                          else
                            _buildLoginCardForm(),

                          const SizedBox(height: 16),

                          // Exclusive VIP Benefits (Đặc quyền hội viên hoàng gia)
                          _buildVipBenefitsCard(),
                          const SizedBox(height: 16),

                          // Live Marquee Nổ Hũ
                          _buildMarqueeWinner(),
                          const SizedBox(height: 16),

                          // Bottom Navigation & Support
                          _buildBottomFooter(),
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
                  'Hệ thống game điểm ảo PRM393.\nHotline VIP: 1900 8888\nEmail: cskh@tiuxai.edu.vn',
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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffffc174).withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            Container(
              width: 72,
              height: 72,
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
                size: 38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Tag Code Tân thủ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xffa40217).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.stars, color: Color(0xffffc174), size: 14),
              SizedBox(width: 4),
              Text(
                'TẶNG CODE 100K CHO TÂN THỦ',
                style: TextStyle(
                  color: Color(0xffffdad7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Title
        Text(
          _isRegisterTab ? 'TẠO TÀI KHOẢN MỚI' : 'TÀI XỈU HOÀNG GIA',
          style: const TextStyle(
            color: Color(0xffffc174),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRegisterTab
              ? 'Gia nhập sảnh thượng lưu • Khởi nghiệp rực rỡ'
              : 'CỔNG GAME QUỐC TẾ • ĐIỂM ẢO PRM393',
          style: const TextStyle(
            color: Color(0xffa08e7a),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                  color: !_isRegisterTab ? const Color(0xffffc174) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isRegisterTab
                      ? [
                          BoxShadow(
                            color: const Color(0xffffc174).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login,
                        size: 16,
                        color: !_isRegisterTab ? const Color(0xff472a00) : const Color(0xffa08e7a),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đăng Nhập',
                        style: TextStyle(
                          color: !_isRegisterTab ? const Color(0xff472a00) : const Color(0xffa08e7a),
                          fontSize: 14,
                          fontWeight: !_isRegisterTab ? FontWeight.w800 : FontWeight.w500,
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
                  color: _isRegisterTab ? const Color(0xffffc174) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isRegisterTab
                      ? [
                          BoxShadow(
                            color: const Color(0xffffc174).withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.how_to_reg,
                        size: 16,
                        color: _isRegisterTab ? const Color(0xff472a00) : const Color(0xffa08e7a),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đăng Ký',
                        style: TextStyle(
                          color: _isRegisterTab ? const Color(0xff472a00) : const Color(0xffa08e7a),
                          fontSize: 14,
                          fontWeight: _isRegisterTab ? FontWeight.w800 : FontWeight.w500,
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

  // --- FORM ĐĂNG KÝ PHIÊN BẢN MỚI ---
  Widget _buildRegisterCardForm() {
    final pwdStrength = _calculatePasswordStrength(_regPasswordController.text);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff191c22).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x33ffc174)),
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
          // Field: Nickname
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TÊN ĐĂNG NHẬP (NICKNAME)',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  Icon(
                    _isNicknameValid ? Icons.check_circle : Icons.info_outline,
                    color: _isNicknameValid ? const Color(0xff56e5a9) : const Color(0xffa08e7a),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isNicknameValid ? 'Hợp lệ' : 'Từ 4–20 ký tự',
                    style: TextStyle(
                      color: _isNicknameValid ? const Color(0xff56e5a9) : const Color(0xffa08e7a),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
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
              controller: _regNicknameController,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Color(0xffa08e7a), size: 20),
                suffixIcon: _isNicknameValid
                    ? const Icon(Icons.verified, color: Color(0xff56e5a9), size: 20)
                    : null,
                hintText: 'Từ 6 - 16 ký tự viết liền',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Field: Mật khẩu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'MẬT KHẨU',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Tối thiểu 6 ký tự',
                style: TextStyle(color: Color(0xffa08e7a), fontSize: 11),
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
              controller: _regPasswordController,
              obscureText: _obscureRegPassword,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock, color: Color(0xffa08e7a), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureRegPassword ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xffa08e7a),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureRegPassword = !_obscureRegPassword),
                ),
                hintText: 'Nhập mật khẩu an toàn',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Password Strength Meter (Bộ đo độ mạnh mật khẩu)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: pwdStrength >= 1
                        ? (pwdStrength == 1
                            ? const Color(0xffffb4ab)
                            : (pwdStrength == 2 ? const Color(0xfff59e0b) : const Color(0xff56e5a9)))
                        : const Color(0xff32353c),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: pwdStrength >= 2
                        ? (pwdStrength == 2 ? const Color(0xfff59e0b) : const Color(0xff56e5a9))
                        : const Color(0xff32353c),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: pwdStrength >= 3 ? const Color(0xff56e5a9) : const Color(0xff32353c),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pwdStrength == 0
                    ? ''
                    : (pwdStrength == 1 ? 'Yếu' : (pwdStrength == 2 ? 'Vừa' : 'Mạnh')),
                style: TextStyle(
                  color: pwdStrength == 1
                      ? const Color(0xffffb4ab)
                      : (pwdStrength == 2 ? const Color(0xfff59e0b) : const Color(0xff56e5a9)),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Field: Xác nhận mật khẩu
          const Text(
            'XÁC NHẬN MẬT KHẨU',
            style: TextStyle(
              color: Color(0xffffc174),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xff0b0e14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x33ffffff)),
            ),
            child: TextField(
              controller: _regConfirmPasswordController,
              obscureText: _obscureRegConfirm,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_reset, color: Color(0xffa08e7a), size: 20),
                suffixIcon: _isPasswordMatch
                    ? const Icon(Icons.task_alt, color: Color(0xff56e5a9), size: 20)
                    : IconButton(
                        icon: Icon(
                          _obscureRegConfirm ? Icons.visibility : Icons.visibility_off,
                          color: const Color(0xffa08e7a),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscureRegConfirm = !_obscureRegConfirm),
                      ),
                hintText: 'Nhập lại mật khẩu',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Field: Số điện thoại / Zalo (Tùy chọn)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'SỐ ĐIỆN THOẠI / ZALO',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.shield, color: Color(0xff4edea3), size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Bảo mật tài khoản',
                    style: TextStyle(color: Color(0xff4edea3), fontSize: 11),
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
              controller: _regPhoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14, letterSpacing: 1.0),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_iphone, color: Color(0xffa08e7a), size: 20),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xff272a31),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'OTP SMS',
                    style: TextStyle(color: Color(0xffffc174), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                hintText: 'Nhập số nhận OTP kích hoạt (tùy chọn)',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Field: Mã giới thiệu / Giftcode
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'MÃ GIỚI THIỆU / GIFTCODE',
                style: TextStyle(
                  color: Color(0xffa08e7a),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '+100.000 XU',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0e14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x33ffffff)),
                  ),
                  child: TextField(
                    controller: _regGiftcodeController,
                    style: const TextStyle(
                      color: Color(0xffffc174),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.card_giftcard, color: Color(0xffa08e7a), size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _giftcodeApplied ? const Color(0xff30c88f) : const Color(0xfff59e0b),
                  foregroundColor: const Color(0xff003824),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                onPressed: () {
                  setState(() => _giftcodeApplied = true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã kích hoạt Giftcode +100.000 Xu tân thủ!')),
                  );
                },
                icon: Icon(
                  _giftcodeApplied ? Icons.check : Icons.redeem,
                  size: 16,
                  color: const Color(0xff003824),
                ),
                label: Text(
                  _giftcodeApplied ? 'Đã Áp Dụng' : 'Áp Dụng',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Policy Acceptance Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _regTermsAccepted,
                  activeColor: const Color(0xffffc174),
                  checkColor: const Color(0xff472a00),
                  onChanged: (v) => setState(() => _regTermsAccepted = v ?? true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Color(0xffd8c3ad), fontSize: 11, height: 1.4),
                    children: [
                      const TextSpan(text: 'Tôi xác nhận đủ '),
                      const TextSpan(
                        text: '18 tuổi',
                        style: TextStyle(color: Color(0xffffc174), fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' và hoàn toàn đồng ý với '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => _showInfoDialog(
                            'Điều Khoản Dịch Vụ',
                            'Ứng dụng phục vụ đồ án môn học PRM393. Toàn bộ điểm số là xu ảo mô phỏng, không có nạp/rút tiền thật, không quy đổi hiện vật.',
                          ),
                          child: const Text(
                            'Điều khoản dịch vụ',
                            style: TextStyle(
                              color: Color(0xffffc174),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' & '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => _showInfoDialog(
                            'Quy Tắc Cược Công Bằng',
                            'Mọi kết quả được xử lý an toàn tại Cloud Functions và lưu trữ minh bạch trên Firestore.',
                          ),
                          child: const Text(
                            'Quy tắc cược công bằng',
                            style: TextStyle(
                              color: Color(0xffffc174),
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Error banner
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 16),

          // Primary Action Button (CTA)
          Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [
                  Color(0xffffc174),
                  Color(0xfff59e0b),
                  Color(0xffffc174),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xfff59e0b).withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _busy ? null : _submitRegister,
                child: Center(
                  child: _busy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xff472a00),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.redeem, color: Color(0xff472a00), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'ĐĂNG KÝ NHẬN THƯỞNG 100K',
                              style: TextStyle(
                                color: Color(0xff472a00),
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, color: Color(0xff472a00), size: 18),
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

  // --- FORM ĐĂNG NHẬP ---
  Widget _buildLoginCardForm() {
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
              controller: _loginAccountController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.account_circle, color: Color(0xffffc174), size: 20),
                suffixIcon: _loginAccountController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Color(0xffa08e7a), size: 18),
                        onPressed: () => _loginAccountController.clear(),
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
              controller: _loginPasswordController,
              obscureText: _obscureLoginPassword,
              style: const TextStyle(color: Color(0xffe1e2eb), fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock, color: Color(0xffffc174), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xffd8c3ad),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
                ),
                hintText: '••••••••••••',
                hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 8),

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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PasswordRecoveryScreen(),
                  ),
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
          const SizedBox(height: 16),

          // CTA Nút Đăng Nhập
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
                onTap: _busy ? null : _submitLogin,
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
                          children: const [
                            Icon(Icons.bolt, color: Color(0xff472a00), size: 22),
                            SizedBox(width: 6),
                            Text(
                              'ĐĂNG NHẬP NGAY',
                              style: TextStyle(
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

          // Hoặc kết nối nhanh
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

  // --- EXCLUSIVE VIP BENEFITS CARD ---
  Widget _buildVipBenefitsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff191c22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1affffff)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.military_tech, color: Color(0xffffc174), size: 20),
              SizedBox(width: 8),
              Text(
                'ĐẶC QUYỀN HỘI VIÊN HOÀNG GIA',
                style: TextStyle(
                  color: Color(0xffffc174),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Benefit 1
          _buildBenefitRow(
            icon: Icons.bolt,
            iconColor: const Color(0xffffc174),
            title: 'Khởi Nghiệp 100K Xu Ảo',
            desc: 'Khớp lệnh tự động 30 giây mô phỏng trải nghiệm thực tế',
          ),
          const SizedBox(height: 8),

          // Benefit 2
          _buildBenefitRow(
            icon: Icons.enhanced_encryption,
            iconColor: const Color(0xff56e5a9),
            title: 'Bảo Mật OTP Chuẩn PRM393',
            desc: 'Mã hóa Firebase Auth & Cloud Functions chống gian lận',
          ),
          const SizedBox(height: 8),

          // Benefit 3
          _buildBenefitRow(
            icon: Icons.casino,
            iconColor: const Color(0xffffb3ad),
            title: 'Minh Bạch Thuật Toán & Audit Log',
            desc: 'Chống trùng lặp giao dịch, ghi nhận minh bạch trên sổ cái',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff272a31).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xff32353c),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xffe1e2eb),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Color(0xffa08e7a),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildBottomFooter() {
    return Column(
      children: [
        // Chuyển nhanh giữa 2 tab
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isRegisterTab ? 'Đã có tài khoản VIP? ' : 'Chưa có tài khoản? ',
                style: const TextStyle(color: Color(0xffa08e7a), fontSize: 13),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isRegisterTab = !_isRegisterTab;
                    _errorMessage = null;
                  });
                },
                child: Row(
                  children: [
                    Text(
                      _isRegisterTab ? 'Đăng nhập ngay' : 'Đăng ký ngay',
                      style: const TextStyle(
                        color: Color(0xffffc174),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xffffc174), size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Support and Trust Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Row(
              children: [
                Icon(Icons.support_agent, color: Color(0xff56e5a9), size: 14),
                SizedBox(width: 4),
                Text(
                  'HỖ TRỢ CSKH 24/7',
                  style: TextStyle(color: Color(0xffa08e7a), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(width: 12),
            Text('•', style: TextStyle(color: Color(0xff534434))),
            SizedBox(width: 12),
            Row(
              children: [
                Icon(Icons.verified_user, color: Color(0xffffc174), size: 14),
                SizedBox(width: 4),
                Text(
                  'SSL 256-BIT',
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
