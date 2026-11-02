import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _bg = Color(0xff10131a);
const _surfaceLow = Color(0xff191c22);
const _surface = Color(0xff1d2026);
const _surfaceHigh = Color(0xff272a31);
const _surfaceHighest = Color(0xff32353c);
const _gold = Color(0xffffc174);
const _amber = Color(0xfff59e0b);
const _mint = Color(0xff56e5a9);
const _text = Color(0xffe1e2eb);
const _muted = Color(0xffd8c3ad);
const _outline = Color(0xffa08e7a);
const _error = Color(0xffffb4ab);

enum _RecoveryMethod { sms, email, support }

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _contact = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _otp = List.generate(6, (_) => TextEditingController());
  final _otpFocus = List.generate(6, (_) => FocusNode());
  _RecoveryMethod _method = _RecoveryMethod.sms;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _codeSent = false;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;

  static const _demoCode = '582000';

  int get _strength {
    final value = _password.text;
    return [
      value.length >= 8 && value.length <= 20,
      RegExp('[a-z]').hasMatch(value) && RegExp('[A-Z]').hasMatch(value),
      RegExp(r'\d').hasMatch(value),
      RegExp(r'[^A-Za-z0-9]').hasMatch(value),
    ].where((passed) => passed).length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _account.dispose();
    _contact.dispose();
    _password.dispose();
    _confirm.dispose();
    for (final controller in _otp) {
      controller.dispose();
    }
    for (final node in _otpFocus) {
      node.dispose();
    }
    super.dispose();
  }

  String get _methodLabel => switch (_method) {
    _RecoveryMethod.email => 'EMAIL ĐĂNG KÝ',
    _RecoveryMethod.sms => 'SỐ ĐIỆN THOẠI LIÊN KẾT',
    _RecoveryMethod.support => 'KÊNH HỖ TRỢ',
  };

  String get _contactHint => switch (_method) {
    _RecoveryMethod.email => 'Nhập email tài khoản',
    _RecoveryMethod.sms => 'Nhập số điện thoại',
    _RecoveryMethod.support => 'Kênh hỗ trợ chưa thiết lập',
  };

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startDemoOtp() {
    if (_method == _RecoveryMethod.support) {
      _showMessage('Kênh hỗ trợ chưa được cấu hình trong bản demo.');
      return;
    }
    if (_method == _RecoveryMethod.email &&
        !_contact.text.trim().contains('@')) {
      _showMessage('Nhập email hợp lệ để thử luồng demo.');
      return;
    }
    if (_method == _RecoveryMethod.sms && _contact.text.trim().length < 8) {
      _showMessage('Nhập số điện thoại để thử luồng demo.');
      return;
    }
    _timer?.cancel();
    setState(() {
      _codeSent = true;
      _seconds = 58;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
    _showMessage(
      'Mã OTP demo: $_demoCode. Mã này không được gửi qua SMS hoặc email.',
    );
  }

  Future<void> _sendFirebaseEmail() async {
    final email = _contact.text.trim();
    if (!email.contains('@')) {
      _showMessage('Nhập email hợp lệ để gửi liên kết khôi phục.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Firebase Auth đã yêu cầu gửi liên kết đặt lại đến $email.');
    } on FirebaseAuthException catch (error) {
      _showMessage(error.message ?? 'Không gửi được liên kết (${error.code}).');
    } catch (error) {
      _showMessage('Không kết nối được Firebase Auth: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6; i++) {
        _otp[i].text = i < digits.length ? digits[i] : '';
      }
      _otpFocus[(digits.length.clamp(1, 6)) - 1].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_method == _RecoveryMethod.support) {
      _showMessage('Kênh hỗ trợ chưa được cấu hình trong bản demo.');
      return;
    }
    if (!_codeSent) {
      _showMessage('Hãy gửi mã OTP demo trước.');
      return;
    }
    final code = _otp.map((controller) => controller.text).join();
    if (code != _demoCode) {
      _showMessage('Mã OTP demo không đúng.');
      return;
    }
    if (_password.text.length < 8 || _password.text.length > 20) {
      _showMessage('Mật khẩu cần từ 8 đến 20 ký tự.');
      return;
    }
    if (_password.text != _confirm.text) {
      _showMessage('Mật khẩu xác nhận chưa trùng khớp.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceHigh,
        icon: const Icon(Icons.check_circle, color: _mint, size: 42),
        title: const Text(
          'Kiểm tra demo thành công',
          style: TextStyle(color: _gold),
        ),
        content: const Text(
          'Mã và biểu mẫu hợp lệ. Mật khẩu tài khoản Firebase chưa được thay đổi trong luồng OTP demo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _text, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.85),
          radius: 1.2,
          colors: [Color(0x1cffc174), _bg],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _intro(),
                    const SizedBox(height: 16),
                    _methodSelector(),
                    const SizedBox(height: 14),
                    _accountField(),
                    const SizedBox(height: 12),
                    _contactField(),
                    const SizedBox(height: 10),
                    _sendCodeButton(),
                    if (_codeSent) ...[const SizedBox(height: 14), _otpField()],
                    const SizedBox(height: 16),
                    _passwordField(),
                    const SizedBox(height: 12),
                    _strengthMeter(),
                    const SizedBox(height: 14),
                    _confirmField(),
                    const SizedBox(height: 16),
                    _submitButton(),
                    if (_method == _RecoveryMethod.email) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _sendFirebaseEmail,
                        icon: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.mark_email_read_outlined),
                        label: const Text('GỬI LIÊN KẾT ĐẶT LẠI QUA FIREBASE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: BorderSide(color: _gold.withValues(alpha: .5)),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _securityNotice(),
                    const SizedBox(height: 14),
                    _supportCard(),
                    const SizedBox(height: 12),
                    _backToLogin(),
                    const SizedBox(height: 14),
                    _footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topBar(BuildContext context) => Container(
    color: const Color(0x660b0e14),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      children: [
        const Icon(Icons.verified_user, color: _gold, size: 19),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'KHÔI PHỤC TÀI KHOẢN',
            style: TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Hỗ trợ',
          onPressed: () =>
              _showMessage('Kênh hỗ trợ chưa được cấu hình trong bản demo.'),
          icon: const Icon(Icons.support_agent, color: _muted),
        ),
      ],
    ),
  );

  Widget _intro() => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
    decoration: BoxDecoration(
      color: _surfaceLow,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .32),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: _surfaceHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.lock_reset, color: _gold, size: 33),
        ),
        const SizedBox(height: 10),
        const Text(
          'KHÔI PHỤC MẬT KHẨU',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Nhập thông tin tài khoản để thử luồng khôi phục mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'OTP trong màn hình là mô phỏng, không gửi thật',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _methodSelector() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _surfaceLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        _methodButton(
          _RecoveryMethod.sms,
          Icons.sms_outlined,
          'SMS / Telegram',
        ),
        _methodButton(_RecoveryMethod.email, Icons.email_outlined, 'Email'),
        _methodButton(_RecoveryMethod.support, Icons.support_agent, 'Hỗ trợ'),
      ],
    ),
  );

  Widget _methodButton(_RecoveryMethod method, IconData icon, String label) {
    final selected = _method == method;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _method = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? _surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Icon(icon, size: 17, color: selected ? _gold : _outline),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _gold : _muted,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountField() => _labeledField(
    label: 'TÊN TÀI KHOẢN / NICKNAME',
    icon: Icons.account_circle_outlined,
    child: TextFormField(
      controller: _account,
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: _inputDecoration('Nhập tên tài khoản'),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Nhập tên tài khoản.' : null,
    ),
  );

  Widget _contactField() => _labeledField(
    label: _methodLabel,
    icon: _method == _RecoveryMethod.email
        ? Icons.alternate_email
        : Icons.phone_iphone,
    child: TextFormField(
      controller: _contact,
      keyboardType: _method == _RecoveryMethod.email
          ? TextInputType.emailAddress
          : TextInputType.phone,
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: _inputDecoration(_contactHint),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nhập thông tin liên hệ.';
        }
        if (_method == _RecoveryMethod.email && !value.contains('@')) {
          return 'Email chưa hợp lệ.';
        }
        return null;
      },
    ),
  );

  Widget _labeledField({
    required String label,
    required IconData icon,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .55,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xff0b0e14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _surfaceHigh),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _gold),
            const SizedBox(width: 9),
            Expanded(child: child),
          ],
        ),
      ),
    ],
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _outline.withValues(alpha: .75), fontSize: 12),
    border: InputBorder.none,
    errorStyle: const TextStyle(fontSize: 10),
    contentPadding: const EdgeInsets.symmetric(vertical: 13),
  );

  Widget _sendCodeButton() => SizedBox(
    height: 44,
    child: ElevatedButton.icon(
      onPressed: _seconds > 0 ? null : _startDemoOtp,
      icon: const Icon(Icons.send, size: 17),
      label: Text(
        _seconds > 0 ? 'GỬI LẠI MÃ (${_seconds}s)' : 'GỬI MÃ OTP DEMO',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: const Color(0xff2a1700),
        disabledBackgroundColor: _surfaceHigh,
        disabledForegroundColor: _muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
        ),
      ),
    ),
  );

  Widget _otpField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'MÃ OTP DEMO (6 CHỮ SỐ)',
              style: TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: .45,
              ),
            ),
          ),
          Text(
            'HẾT HẠN ${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(
              color: _gold,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: List.generate(
          6,
          (index) => Expanded(
            child: Container(
              height: 50,
              margin: EdgeInsets.only(right: index == 5 ? 0 : 6),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _otpFocus[index].hasFocus ? _gold : _surfaceHigh,
                ),
              ),
              child: TextField(
                controller: _otp[index],
                focusNode: _otpFocus[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: const TextStyle(
                  color: _gold,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                ),
                onChanged: (value) => _onOtpChanged(index, value),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _passwordField() => _labeledField(
    label: 'MẬT KHẨU MỚI (TỐI THIỂU 8 KÝ TỰ)',
    icon: Icons.lock_reset,
    child: TextFormField(
      controller: _password,
      maxLength: 20,
      obscureText: !_passwordVisible,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: _inputDecoration('Nhập mật khẩu mới').copyWith(
        counterText: '',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          icon: Icon(
            _passwordVisible ? Icons.visibility : Icons.visibility_off,
            color: _outline,
            size: 18,
          ),
        ),
      ),
      validator: (value) => value == null || value.length < 8
          ? 'Mật khẩu cần tối thiểu 8 ký tự.'
          : null,
    ),
  );

  Widget _strengthMeter() {
    final labels = ['Chưa bảo mật', 'Yếu', 'Trung bình', 'Khá mạnh', 'Mạnh'];
    final colors = [_outline, _error, const Color(0xffffb3ad), _amber, _mint];
    final score = _password.text.isEmpty ? 0 : _strength;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ĐỘ MẠNH MẬT KHẨU',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .5,
                  ),
                ),
              ),
              Text(
                labels[score].toUpperCase(),
                style: TextStyle(
                  color: colors[score],
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: i < score ? colors[score] : _surfaceHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Dùng chữ hoa, chữ thường, số và ký tự đặc biệt để tăng độ mạnh.',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _confirmField() => _labeledField(
    label: 'XÁC NHẬN MẬT KHẨU MỚI',
    icon: Icons.lock_outline,
    child: TextFormField(
      controller: _confirm,
      maxLength: 20,
      obscureText: !_confirmVisible,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: _text, fontSize: 13),
      decoration: _inputDecoration('Nhập lại mật khẩu mới').copyWith(
        counterText: '',
        suffixIcon: IconButton(
          onPressed: () => setState(() => _confirmVisible = !_confirmVisible),
          icon: Icon(
            _confirmVisible ? Icons.visibility : Icons.visibility_off,
            color: _outline,
            size: 18,
          ),
        ),
      ),
      validator: (value) =>
          value != _password.text ? 'Mật khẩu xác nhận chưa trùng khớp.' : null,
    ),
  );

  Widget _submitButton() => SizedBox(
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_amber, _gold, _amber]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.key, color: Color(0xff2a1700), size: 19),
        label: const Text(
          'XÁC NHẬN ĐỔI MẬT KHẨU',
          style: TextStyle(
            color: Color(0xff2a1700),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );

  Widget _securityNotice() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surfaceLow,
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.gpp_maybe, color: _error, size: 19),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Không chia sẻ mật khẩu hoặc mã xác minh. OTP tại màn hình này chỉ dùng để thử giao diện, không xác minh tài khoản thật.',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.45),
          ),
        ),
      ],
    ),
  );

  Widget _supportCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff0b0e14),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Gặp sự cố với thông tin liên hệ?',
                style: TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              'DEMO',
              style: TextStyle(
                color: _gold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'SMS, Telegram và hỗ trợ trực tiếp chưa được cấu hình trong project.',
          style: TextStyle(color: _muted, fontSize: 10, height: 1.4),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _supportButton(Icons.phone_in_talk, 'Hotline')),
            const SizedBox(width: 8),
            Expanded(child: _supportButton(Icons.send, 'Telegram')),
          ],
        ),
      ],
    ),
  );

  Widget _supportButton(IconData icon, String label) => OutlinedButton.icon(
    onPressed: () => _showMessage('$label chưa được cấu hình.'),
    icon: Icon(icon, color: _gold, size: 15),
    label: Text(label, style: const TextStyle(color: _text, fontSize: 10)),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: _surfaceHigh),
      padding: const EdgeInsets.symmetric(vertical: 8),
    ),
  );

  Widget _backToLogin() => Column(
    children: [
      const Text(
        'Bạn đã nhớ lại mật khẩu?',
        style: TextStyle(color: _muted, fontSize: 11),
      ),
      TextButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.chevron_right, size: 17),
        label: const Text(
          'Quay lại đăng nhập',
          style: TextStyle(
            color: _gold,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _footer() => const Center(
    child: Text(
      'Môi trường demo • Không có xác minh OTP qua SMS/Telegram',
      textAlign: TextAlign.center,
      style: TextStyle(color: _outline, fontSize: 9, height: 1.4),
    ),
  );
}
