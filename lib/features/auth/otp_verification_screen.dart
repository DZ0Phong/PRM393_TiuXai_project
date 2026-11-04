import 'package:tai_xiu_realtime/core/backend_functions.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

const _otpBg = Color(0xff10131a);
const _otpLow = Color(0xff191c22);
const _otpSurface = Color(0xff1d2026);
const _otpHigh = Color(0xff272a31);
const _otpHighest = Color(0xff32353c);
const _otpGold = Color(0xffffc174);
const _otpMint = Color(0xff56e5a9);
const _otpRed = Color(0xffffb3ad);
const _otpText = Color(0xffe1e2eb);
const _otpMuted = Color(0xffd8c3ad);

class OtpVerificationScreen extends StatefulWidget {
  final User user;

  const OtpVerificationScreen({super.key, required this.user});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _phone = TextEditingController();
  String _digits = '';
  String? _verificationId;
  int? _resendToken;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _busy = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.user.phoneNumber ?? '';
    _verified = widget.user.phoneNumber != null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  bool get _canResend => _remainingSeconds == 0 && !_busy;
  bool get _canVerify =>
      _verificationId != null && _digits.length == 6 && !_busy && !_verified;

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _enterDigit(String value) {
    if (_digits.length >= 6 || _verified) return;
    setState(() => _digits += value);
  }

  void _backspace() {
    if (_digits.isEmpty || _verified) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  void _clearAll() {
    if (_verified) return;
    setState(() => _digits = '');
  }

  Future<void> _verify() async {
    if (!_canVerify) {
      _message('Nhập đủ 6 chữ số trong SMS để xác minh.');
      return;
    }
    final verificationId = _verificationId;
    if (verificationId == null) {
      _message('Hãy yêu cầu mã SMS trước khi xác minh.');
      return;
    }
    if (_remainingSeconds == 0) {
      _message('Mã SMS đã hết hạn. Hãy yêu cầu gửi lại mã.');
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: _digits,
    );
    await _linkVerifiedPhone(credential);
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_busy || _verified) return;
    final phoneNumber = _phone.text.trim();
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phoneNumber)) {
      _message(
        'Nhập số điện thoại theo định dạng quốc tế, ví dụ +84901234567.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _verificationId = null;
      _digits = '';
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resend ? _resendToken : null,
        timeout: const Duration(seconds: 105),
        verificationCompleted: (credential) {
          _linkVerifiedPhone(credential);
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _busy = false);
          _message(
            error.message ??
                'Firebase Auth không gửi được SMS (${error.code}).',
          );
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _digits = '';
            _remainingSeconds = 105;
            _busy = false;
          });
          _startCountdown();
          _message('Firebase Auth đã gửi mã xác minh đến $phoneNumber.');
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(error.message ?? 'Lỗi Firebase Auth: ${error.code}.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message('Không thể gửi mã xác minh: $error');
    }
  }

  Future<void> _linkVerifiedPhone(PhoneAuthCredential credential) async {
    if (_busy && _verified) return;
    if (mounted) setState(() => _busy = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != widget.user.uid) {
        throw FirebaseAuthException(
          code: 'user-mismatch',
          message: 'Phiên đăng nhập đã thay đổi. Hãy đăng nhập lại.',
        );
      }
      final linked = await currentUser.linkWithCredential(credential);
      await linked.user?.getIdToken(true);
      try {
        await FirebaseFunctions.instanceFor(
          region: 'asia-southeast1',
        ).gameCallable('syncVerifiedPhoneNumber').call();
      } catch (error) {
        // Auth is the source of truth; a profile sync can be retried later.
        if (mounted) {
          _message(
            'Số điện thoại đã xác minh trong Firebase Auth. Hồ sơ chưa đồng bộ: $error',
          );
        }
      }
      if (!mounted) return;
      setState(() => _verified = true);
      _message('Số điện thoại đã được xác minh và liên kết với tài khoản.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = error.code == 'credential-already-in-use'
          ? 'Số điện thoại này đã liên kết với tài khoản khác.'
          : error.message ??
                'Không xác minh được số điện thoại (${error.code}).';
      _message(message);
    } catch (error) {
      if (mounted) _message('Không thể liên kết số điện thoại: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _otpHighest,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _otpBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee10131a),
      foregroundColor: _otpText,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
      title: const Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, color: _otpGold, size: 14),
              SizedBox(width: 5),
              Text(
                'XÁC MINH QUA FIREBASE AUTH',
                style: TextStyle(
                  color: _otpGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            'Xác Thực OTP',
            style: TextStyle(
              color: _otpText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Hỗ trợ',
          onPressed: () =>
              _message('Ứng dụng chưa cấu hình hỗ trợ trực tuyến.'),
          icon: const Icon(Icons.support_agent, color: _otpGold, size: 22),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: _otpGold,
            child: const Icon(Icons.person, color: Color(0xff472a00), size: 18),
          ),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.8),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _otpBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _buildSecurityEmblem(),
                _buildTargetInfo(),
                _buildOtpCells(),
                _buildTimerRow(),
                _buildVerifyButton(),
                _buildKeypad(),
                _buildSecurityNotice(),
                const SizedBox(height: 10),
                _buildHelpCard(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildSecurityEmblem() => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _otpHigh,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .4),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _otpSurface,
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_otpGold.withValues(alpha: .2), _otpSurface],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.shield_outlined,
                color: _otpGold,
                size: 32,
              ),
            ),
            Positioned(
              right: 1,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: _otpHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.verified, color: _otpMint, size: 15),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildTargetInfo() => Column(
    children: [
      const Text(
        'Xác Thực Số Điện Thoại',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _otpText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Firebase Auth gửi mã SMS để xác minh và liên kết số điện thoại với tài khoản đang đăng nhập.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _otpMuted, fontSize: 11, height: 1.45),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _phone,
        enabled: !_verified && !_busy,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: _otpText, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.phone_android, color: _otpGold),
          hintText: '+84901234567',
          hintStyle: TextStyle(color: _otpMuted.withValues(alpha: .65)),
          filled: true,
          fillColor: _otpLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _verified || _busy ? null : () => _sendCode(),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sms_outlined, size: 18),
          label: Text(
            _verified ? 'ĐÃ XÁC MINH' : 'GỬI MÃ SMS QUA FIREBASE AUTH',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _otpGold,
            foregroundColor: const Color(0xff472a00),
            disabledBackgroundColor: _otpHigh,
            disabledForegroundColor: _otpMuted,
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  Widget _buildOtpCells() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: List.generate(6, (index) {
        final isFilled = index < _digits.length;
        final isActive = index == _digits.length && !_verified;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 5 ? 0 : 7),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 56,
              decoration: BoxDecoration(
                color: isFilled
                    ? _otpHigh
                    : isActive
                    ? _otpSurface
                    : _otpLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isFilled ? .28 : .15),
                    blurRadius: isFilled ? 10 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: isActive
                    ? Border.all(color: _otpGold.withValues(alpha: .65))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isFilled
                        ? _digits[index]
                        : isActive
                        ? ''
                        : '•',
                    style: TextStyle(
                      color: isFilled
                          ? _otpGold
                          : _otpMuted.withValues(alpha: .4),
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 10,
                      height: 2,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: _otpGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _buildTimerRow() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 5, 4, 12),
    child: Row(
      children: [
        const Icon(Icons.hourglass_top, color: _otpGold, size: 16),
        const SizedBox(width: 5),
        const Text(
          'Mã có hiệu lực:',
          style: TextStyle(color: _otpMuted, fontSize: 11),
        ),
        const SizedBox(width: 5),
        Text(
          _formattedTime,
          style: TextStyle(
            color: _remainingSeconds == 0 ? _otpRed : _otpGold,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _canResend && _verificationId != null
              ? () => _sendCode(resend: true)
              : null,
          icon: const Icon(Icons.refresh, size: 15),
          label: const Text(
            'Gửi lại SMS',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
          ),
          style: TextButton.styleFrom(
            foregroundColor: _otpGold,
            disabledForegroundColor: _otpMuted.withValues(alpha: .5),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );

  Widget _buildVerifyButton() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: _busy || _verified ? null : _verify,
        icon: _busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xff472a00),
                ),
              )
            : Icon(_verified ? Icons.verified : Icons.arrow_forward, size: 20),
        label: Text(
          _verified ? 'MÃ DEMO ĐÃ ĐƯỢC KIỂM TRA' : 'XÁC THỰC NGAY',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .5,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _verified ? _otpMint : _otpGold,
          foregroundColor: const Color(0xff472a00),
          disabledBackgroundColor: _verified ? _otpMint : _otpHigh,
          disabledForegroundColor: _verified
              ? const Color(0xff003824)
              : _otpMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
        ),
      ),
    ),
  );

  Widget _buildKeypad() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _otpLow,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(5, 0, 5, 9),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: _otpMint, size: 14),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'BÀN PHÍM NHẬP MÃ DEMO',
                  style: TextStyle(
                    color: _otpMint,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                  ),
                ),
              ),
              Icon(Icons.dialpad, color: _otpMuted, size: 14),
              SizedBox(width: 4),
              Text('Cố định', style: TextStyle(color: _otpMuted, fontSize: 9)),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final key in keys)
                  SizedBox(
                    width: width,
                    height: 45,
                    child: _keyButton(
                      label: key,
                      onTap: () => _enterDigit(key),
                    ),
                  ),
                SizedBox(
                  width: width,
                  height: 45,
                  child: _keyButton(
                    label: 'Xóa hết',
                    secondary: true,
                    onTap: _clearAll,
                  ),
                ),
                SizedBox(
                  width: width,
                  height: 45,
                  child: _keyButton(label: '0', onTap: () => _enterDigit('0')),
                ),
                SizedBox(
                  width: width,
                  height: 45,
                  child: _keyButton(
                    icon: Icons.backspace_outlined,
                    secondary: true,
                    onTap: _backspace,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _keyButton({
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    bool secondary = false,
  }) => Material(
    color: secondary ? _otpHigh : _otpSurface,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: _verified || _busy ? null : onTap,
      borderRadius: BorderRadius.circular(11),
      child: Center(
        child: icon != null
            ? Icon(icon, color: _otpGold, size: 22)
            : Text(
                label ?? '',
                style: TextStyle(
                  color: secondary ? _otpMuted : _otpText,
                  fontSize: secondary ? 10 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    ),
  );

  Widget _buildSecurityNotice() => Container(
    margin: const EdgeInsets.only(top: 13),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff0b0e14),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .22),
          blurRadius: 7,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.gpp_maybe, color: _otpRed, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lưu ý bảo mật',
                style: TextStyle(
                  color: _otpRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Không chia sẻ mã xác thực cho người khác. Mã được gửi bởi Firebase Auth và dùng để liên kết số điện thoại với tài khoản hiện tại.',
                style: TextStyle(color: _otpMuted, fontSize: 10, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildHelpCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _otpHigh,
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
      children: [
        Row(
          children: [
            const Icon(Icons.headset_mic, color: _otpGold, size: 18),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Gặp sự cố khi xác minh số điện thoại?',
                style: TextStyle(
                  color: _otpText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _otpSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'HỖ TRỢ CHƯA CẤU HÌNH',
                style: TextStyle(
                  color: _otpMint,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _helpButton(
                Icons.send,
                'Telegram',
                () => _message('Project chưa cấu hình Telegram bot.'),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _helpButton(
                Icons.support_agent,
                'CSKH trực tuyến',
                () =>
                    _message('Project chưa cấu hình dịch vụ CSKH trực tuyến.'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _helpButton(IconData icon, String label, VoidCallback onTap) =>
      SizedBox(
        height: 36,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 15),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _otpText,
            backgroundColor: _otpSurface,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
}
