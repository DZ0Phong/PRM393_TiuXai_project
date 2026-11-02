import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

import 'password_change_success_screen.dart';

const _bg = Color(0xff10131a);
const _surfaceLow = Color(0xff191c22);
const _surface = Color(0xff1d2026);
const _surfaceHigh = Color(0xff272a31);
const _surfaceHighest = Color(0xff32353c);
const _gold = Color(0xffffc174);
const _goldContainer = Color(0xfff59e0b);
const _mint = Color(0xff56e5a9);
const _text = Color(0xffe1e2eb);
const _muted = Color(0xffd8c3ad);
const _outline = Color(0xffa08e7a);

class ChangePasswordScreen extends StatefulWidget {
  final User user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _lengthOk => _next.text.length >= 8;
  bool get _upperOk => RegExp(r'[A-Z]').hasMatch(_next.text);
  bool get _numberOk => RegExp(r'[0-9]').hasMatch(_next.text);
  bool get _specialOk => RegExp(r'[^A-Za-z0-9]').hasMatch(_next.text);
  int get _strength =>
      [_lengthOk, _upperOk, _numberOk, _specialOk].where((v) => v).length;

  Future<void> _forgotPassword() async {
    final email = widget.user.email;
    if (email == null || email.isEmpty) {
      _notice('Tài khoản này không có email khôi phục.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _notice('Đã gửi liên kết đặt lại mật khẩu đến $email.');
    } on FirebaseAuthException catch (e) {
      _notice(
        e.message ?? 'Không gửi được email đặt lại mật khẩu (${e.code}).',
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (_strength != 4) {
      _notice('Mật khẩu mới cần đủ 8 ký tự, chữ hoa, số và ký tự đặc biệt.');
      return;
    }
    setState(() => _busy = true);
    try {
      final email = widget.user.email;
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'Tài khoản không có email để xác minh lại.',
        );
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _current.text,
      );
      await widget.user.reauthenticateWithCredential(credential);
      await widget.user.updatePassword(_next.text);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const PasswordChangeSuccessScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _notice(
          e.code == 'wrong-password' || e.code == 'invalid-credential'
              ? 'Mật khẩu hiện tại không đúng.'
              : e.message ?? 'Không đổi được mật khẩu (${e.code}).',
        );
      }
    } catch (e) {
      if (mounted) _notice('Không đổi được mật khẩu: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xee0b0e14),
        foregroundColor: _text,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: .4),
        centerTitle: true,
        title: const Text(
          'Đổi Mật Khẩu',
          style: TextStyle(
            color: _gold,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: .3,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 21),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'CSKH 24/7',
            onPressed: () =>
                _notice('Kênh hỗ trợ chưa được cấu hình trong bản demo.'),
            icon: const Icon(Icons.support_agent, color: _gold),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.95),
            radius: 1.15,
            colors: [Color(0x14f59e0b), _bg],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
              children: [
                _buildHero(),
                const SizedBox(height: 16),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _passwordField(
                        label: 'Mật khẩu hiện tại',
                        hint: 'Nhập mật khẩu đang dùng',
                        controller: _current,
                        visible: _showCurrent,
                        onToggle: () =>
                            setState(() => _showCurrent = !_showCurrent),
                        icon: Icons.key,
                        trailing: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              color: _gold,
                              decoration: TextDecoration.underline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _passwordField(
                        label: 'Mật khẩu mới',
                        hint: 'Tối thiểu 8 ký tự hoàng gia',
                        controller: _next,
                        visible: _showNext,
                        onToggle: () => setState(() => _showNext = !_showNext),
                        icon: Icons.lock_reset,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _buildStrength(),
                      const SizedBox(height: 16),
                      _passwordField(
                        label: 'Xác nhận mật khẩu mới',
                        hint: 'Nhập lại mật khẩu mới vừa đặt',
                        controller: _confirm,
                        visible: _showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                        icon: Icons.verified_user,
                        validator: (v) => v != _next.text
                            ? 'Mật khẩu xác nhận chưa trùng khớp.'
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                _buildAdvisory(),
                const SizedBox(height: 18),
                _buildSubmit(),
                const SizedBox(height: 14),
                _buildBadges(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _surfaceHigh,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .7),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0x33ffc174), _surfaceHigh],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.enhanced_encryption,
                  size: 32,
                  color: _gold,
                ),
              ),
              Positioned(
                bottom: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xff0b0e14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'RSA-4096',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Text(
          'Bảo Vệ Két Sắt & Số Dư Hoàng Gia',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _gold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mã hóa cấp độ ngân hàng bảo vệ toàn diện tài sản và giao dịch Tài Xỉu của quý hội viên.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .45),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: child,
  );

  Widget _passwordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
    required IconData icon,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    Widget? trailing,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, color: _gold, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xff0b0e14),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .42),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          obscureText: !visible,
          onChanged: onChanged,
          validator:
              validator ??
              (value) => (value == null || value.isEmpty)
                  ? 'Vui lòng nhập $label.'
                  : null,
          style: const TextStyle(color: _text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xff534434), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Color(0xffffb4ab)),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible ? Icons.visibility_off : Icons.visibility,
                color: _outline,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildStrength() {
    final labels = ['Chưa nhập', 'Yếu', 'Trung bình', 'Khá', 'Cực mạnh'];
    final colors = [
      _outline,
      const Color(0xffffb4ab),
      _gold,
      _mint,
      const Color(0xff30c88f),
    ];
    final criteria = [
      (_lengthOk, 'Từ 8 ký tự'),
      (_upperOk, 'Chữ viết hoa (A-Z)'),
      (_numberOk, 'Ký tự số (0-9)'),
      (_specialOk, r'Ký tự đặc biệt (@#$)'),
    ];
    final score = _next.text.isEmpty ? 0 : _strength;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Độ an toàn mật khẩu',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                labels[score],
                style: TextStyle(
                  color: colors[score],
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i < _strength ? colors[_strength] : _surfaceHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: criteria.map((criterion) {
              final valid = criterion.$1;
              return SizedBox(
                width: (MediaQuery.sizeOf(context).width - 76) / 2,
                child: Row(
                  children: [
                    Icon(
                      valid ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: valid ? _mint : _muted,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        criterion.$2,
                        style: TextStyle(
                          color: valid ? _mint : _muted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisory() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surfaceLow,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.security_update_good, color: _gold, size: 19),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khuyến cáo an toàn Hoàng Gia',
                style: TextStyle(
                  color: _gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: _muted, fontSize: 11, height: 1.45),
                  children: [
                    TextSpan(
                      text:
                          'Nên định kỳ thay đổi mật khẩu mỗi 30 ngày. Chuyên viên CSKH Tài Xỉu Hoàng Gia ',
                    ),
                    TextSpan(
                      text: 'tuyệt đối không bao giờ',
                      style: TextStyle(
                        color: Color(0xffffb3ad),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' hỏi mật khẩu hay mã OTP của quý khách dưới bất kỳ hình thức nào.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSubmit() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(colors: [_gold, _goldContainer, _gold]),
      boxShadow: [
        BoxShadow(
          color: _goldContainer.withValues(alpha: .25),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : _changePassword,
        child: SizedBox(
          height: 54,
          child: Center(
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xff472a00),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_clock,
                        color: Color(0xff613b00),
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'CẬP NHẬT MẬT KHẨU MỚI',
                        style: TextStyle(
                          color: Color(0xff613b00),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBadges() => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.verified, color: _mint, size: 15),
      SizedBox(width: 4),
      Text(
        'Bảo chứng SSL 256-bit',
        style: TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      SizedBox(width: 12),
      CircleAvatar(radius: 2, backgroundColor: Color(0xff534434)),
      SizedBox(width: 12),
      Icon(Icons.military_tech, color: _gold, size: 15),
      SizedBox(width: 4),
      Text(
        'Tiêu chuẩn VIP Macao',
        style: TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
