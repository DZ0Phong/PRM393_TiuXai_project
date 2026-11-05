import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SignInScreen extends StatefulWidget {
  final bool initialRegisterTab;
  final bool showDemoAdmin;
  const SignInScreen({super.key, this.initialRegisterTab = false, this.showDemoAdmin = false});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late bool _isRegisterTab;

  // Controllers cho Đăng Nhập
  final _loginAccountController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;

  // Controllers cho Đăng Ký
  final _regNicknameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  bool _obscureRegPassword = true;
  bool _obscureRegConfirm = true;
  bool _regTermsAccepted = true;

  bool _busy = false;
  bool _resetBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isRegisterTab = widget.initialRegisterTab;

    _loginAccountController.addListener(() => setState(() {}));
    _regNicknameController.addListener(() => setState(() {}));
    _regPasswordController.addListener(() => setState(() {}));
    _regConfirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _loginAccountController.dispose();
    _loginPasswordController.dispose();
    _regNicknameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
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
    if (!widget.showDemoAdmin) return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(nick);
    return nick.length >= 4 && nick.length <= 20 && !nick.contains(' ') && !nick.contains('@');
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
      appScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đăng nhập thành công.')));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      const credentialErrors = {
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
        'invalid-email',
      };
      setState(
        () => _errorMessage = credentialErrors.contains(e.code)
            ? 'Email hoặc mật khẩu chưa chính xác.'
            : _getFriendlyAuthError(e.code, e.message),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Không thể kết nối máy chủ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_resetBusy) return;
    final email = _loginAccountController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      _showAuthNotice('Nhập email đã đăng ký để nhận liên kết đặt lại mật khẩu.');
      return;
    }
    if (email.toLowerCase().endsWith('@demo.test')) {
      _showAuthNotice('Email demo không nhận được thư khôi phục mật khẩu.');
      return;
    }

    setState(() => _resetBusy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _showAuthNotice('Nếu email đã đăng ký, liên kết đặt lại mật khẩu sẽ được gửi đến $email.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showAuthNotice(error.message ?? 'Không gửi được email đặt lại mật khẩu (${error.code}).');
      }
    } catch (error) {
      if (mounted) _showAuthNotice('Không thể gửi email đặt lại mật khẩu: $error');
    } finally {
      if (mounted) setState(() => _resetBusy = false);
    }
  }

  void _showAuthNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitRegister() async {
    if (_busy) return;
    final nick = _regNicknameController.text.trim();
    final pwd = _regPasswordController.text;
    final confirmPwd = _regConfirmPasswordController.text;

    if (!_isNicknameValid) {
      setState(() => _errorMessage = widget.showDemoAdmin
          ? 'Tên đăng nhập phải từ 4–20 ký tự, viết liền, không có @.'
          : 'Hãy dùng địa chỉ email thật để có thể khôi phục tài khoản.');
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
        email: widget.showDemoAdmin ? _formatEmail(nick) : nick,
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
        return 'Email này đã có người sử dụng. Vui lòng dùng email khác.';
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
                'TIU XAI • PRM393',
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
              if (widget.showDemoAdmin) InkWell(
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
              if (widget.showDemoAdmin) const SizedBox(width: 8),

              // CSKH 24/7
              IconButton(
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.support_agent, color: Color(0xffffc174)),
                tooltip: 'Thông tin dự án',
                onPressed: () => _showInfoDialog(
                  'Hỗ Trợ Khách Hàng',
                  'Dự án học tập PRM393: chỉ dùng điểm ảo. Liên hệ trực tiếp nhóm phát triển nếu cần hỗ trợ.',
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
              ? 'Tham gia dự án học tập • Chỉ dùng điểm ảo'
              : 'DỰ ÁN HỌC TẬP • ĐIỂM ẢO PRM393',
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                widget.showDemoAdmin ? 'TÊN ĐĂNG NHẬP (NICKNAME)' : 'EMAIL CỦA BẠN',
                style: const TextStyle(
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
                    _isNicknameValid ? 'Hợp lệ' : (widget.showDemoAdmin ? 'Từ 4–20 ký tự' : 'Email thật'),
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
                hintText: widget.showDemoAdmin ? 'Từ 4–20 ký tự viết liền' : 'ban@example.com',
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
                            'Ứng dụng phục vụ đồ án môn học PRM393. VNĐ hiển thị chỉ là điểm mô phỏng, không có nạp/rút tiền thật, không quy đổi hiện vật.',
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
                            'Quy tắc trò chơi',
                            'Kết quả và điểm ảo được máy chủ xử lý theo luật từng trò; ứng dụng không cam kết mọi phiên ngẫu nhiên độc lập.',
                          ),
                          child: const Text(
                            'Quy tắc trò chơi',
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
                            Icon(Icons.person_add, color: Color(0xff472a00), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'ĐĂNG KÝ TÀI KHOẢN',
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetBusy ? null : _sendPasswordReset,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xffffc174),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                _resetBusy ? 'Đang gửi...' : 'Quên mật khẩu?',
                style: const TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff690005).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffffb4ab)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xffffb4ab),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xffffdad6),
                        fontSize: 12,
                      ),
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
                _isRegisterTab ? 'Đã có tài khoản? ' : 'Chưa có tài khoản? ',
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

        const Text(
          'Dự án thực hành PRM393. Chỉ dùng điểm ảo, không tiền thật và không đổi thưởng.',
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
