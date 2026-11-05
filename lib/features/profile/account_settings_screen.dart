import 'package:tai_xiu_realtime/core/backend_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

const _settingsBg = Color(0xff10131a);
const _settingsLow = Color(0xff191c22);
const _settingsSurface = Color(0xff1d2026);
const _settingsHigh = Color(0xff272a31);
const _settingsHighest = Color(0xff32353c);
const _settingsGold = Color(0xffffc174);
const _settingsAmber = Color(0xfff59e0b);
const _settingsMint = Color(0xff56e5a9);
const _settingsText = Color(0xffe1e2eb);
const _settingsMuted = Color(0xffd8c3ad);
const _settingsOutline = Color(0xffa08e7a);
const _settingsRed = Color(0xffffb3ad);

class AccountSettingsScreen extends StatefulWidget {
  final User user;
  const AccountSettingsScreen({super.key, required this.user});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCY2Df80ZIpzz0qMxVdo10dpE0v14GuiLqyaW7k5ADkO3Xq2mPeA9p173NCtVsSKRmnBt05g8ZRMhhU1fVSkQuGsyIMWyXPZv__iSo373ChbE8ylxc-Sm75Tzs4F0DmnKyvL6xWG_kE6tESvOlv5SNhqoG3DBe1DNvPgCzZpAGMneiTlGwYutvT_rmpIuAYIWAdogI8LpJD3oAjdFJWw2BcT-qQ7Wo3hRw_zZn5_Jpn';

  final Map<String, bool> _switches = {
    'twoFactor': false,
    'hideBalance': true,
    'hideLeaderboard': false,
    'blockInvites': false,
    'biometric': false,
    'unknownDevice': false,
  };

  @override
  void initState() {
    super.initState();
    _loadPrivacyPreferences();
  }

  Future<void> _loadPrivacyPreferences() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .doc('users/${widget.user.uid}')
          .get();
      final preferences = snapshot.data()?['preferences'];
      if (!mounted || preferences is! Map) return;
      setState(() {
        for (final key in ['hideBalance', 'hideLeaderboard']) {
          final value = preferences[key];
          if (value is bool) _switches[key] = value;
        }
      });
    } catch (_) {
      // Keep safe defaults if the profile cannot be loaded.
    }
  }

  Future<void> _showNotConfigured(String feature) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _settingsSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: _settingsGold),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chưa khả dụng',
                style: TextStyle(color: _settingsGold),
              ),
            ),
          ],
        ),
        content: Text(
          '$feature chưa được kết nối trong phiên bản demo. Số dư VNĐ chỉ là điểm mô phỏng, không xử lý ngân hàng hoặc tiền điện tử.',
          style: const TextStyle(color: _settingsText, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _toggle(String key) async {
    if (key != 'hideBalance' && key != 'hideLeaderboard') {
      await _showNotConfigured('Tuỳ chọn này');
      return;
    }
    final previous = _switches[key] ?? false;
    final next = !previous;
    setState(() => _switches[key] = next);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).gameCallable('updateMyPrivacyPreferences').call({
        'preferences': {key: next},
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() => _switches[key] = previous);
      _message(error.message ?? 'Không lưu được tuỳ chọn (${error.code}).');
    } catch (error) {
      if (!mounted) return;
      setState(() => _switches[key] = previous);
      _message('Không lưu được tuỳ chọn: $error');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _settingsBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _settingsText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Cài Đặt Tài Khoản',
        style: TextStyle(
          color: _settingsGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'CSKH 24/7',
          onPressed: () => _showNotConfigured('Hỗ trợ trực tiếp'),
          icon: const Icon(Icons.support_agent, color: _settingsGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _settingsBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _buildAccountHeader(),
            const SizedBox(height: 18),
            _buildPaymentSection(),
            const SizedBox(height: 18),
            _buildSecuritySection(),
            const SizedBox(height: 18),
            _buildPrivacySection(),
            const SizedBox(height: 20),
            _buildDangerSection(),
            const SizedBox(height: 16),
            _buildDisclaimer(),
          ],
        ),
      ),
    ),
  );

  Widget _buildAccountHeader() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _settingsHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Stack(
          children: [
            ClipOval(
              child: Image.network(
                _avatarUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 56,
                  height: 56,
                  color: _settingsSurface,
                  child: const Icon(
                    Icons.person,
                    color: _settingsGold,
                    size: 30,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 17,
                height: 17,
                decoration: const BoxDecoration(
                  color: _settingsMint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.user.emailVerified ? Icons.verified : Icons.person,
                  color: const Color(0xff003824),
                  size: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _settingsText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _settingsAmber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'DEMO',
                      style: TextStyle(
                        color: Color(0xff472a00),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'ID: ${_shortUid(widget.user.uid)} • Tài khoản điểm mô phỏng VNĐ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _settingsMuted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'TRẠNG THÁI EMAIL',
              style: TextStyle(
                color: _settingsGold,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  widget.user.emailVerified
                      ? Icons.verified_user
                      : Icons.shield_outlined,
                  color: _settingsMint,
                  size: 17,
                ),
                const SizedBox(width: 3),
                Text(
                  widget.user.emailVerified ? 'ĐÃ XÁC THỰC' : 'BẢO VỆ',
                  style: const TextStyle(
                    color: _settingsMint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  String get _displayName {
    final email = widget.user.email;
    if (email == null || email.isEmpty) return 'Hội viên';
    final local = email.split('@').first;
    return local.isEmpty ? 'Hội viên' : local;
  }

  String _shortUid(String uid) =>
      uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();

  Widget _sectionTitle(IconData icon, String title, {Widget? badge}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      children: [
        Icon(icon, color: _settingsGold, size: 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _settingsGold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?badge,
      ],
    ),
  );

  Widget _buildPaymentSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(
        Icons.account_balance,
        'Ví Điểm & Thanh Toán',
        badge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _settingsHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'XU ẢO',
            style: TextStyle(
              color: _settingsMint,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
        ),
      ),
      const SizedBox(height: 9),
      _buildPaymentCard(
        Icons.account_balance_wallet,
        'Phương thức ngân hàng',
        'Không liên kết',
        'Ngân hàng không hỗ trợ',
        'Không có giao dịch tiền thật',
        isPrimary: true,
      ),
      const SizedBox(height: 9),
      _buildPaymentCard(
        Icons.credit_card,
        'Thẻ thanh toán',
        'Không liên kết',
        'Thanh toán không khả dụng',
        'Chỉ chơi bằng điểm VNĐ mô phỏng',
        isPrimary: false,
      ),
      const SizedBox(height: 9),
      _buildPaymentCard(
        Icons.account_balance,
        'Ví liên kết',
        'Không liên kết',
        'Không có ví thanh toán',
        'Không hỗ trợ nạp hoặc rút',
        isPrimary: false,
      ),
      const SizedBox(height: 9),
      _buildCryptoCard(),
      const SizedBox(height: 9),
      SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: () =>
              _showNotConfigured('Liên kết phương thức thanh toán'),
          icon: const Icon(Icons.add_circle_outline, size: 19),
          label: const Text('Thêm phương thức thanh toán'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _settingsGold,
            side: const BorderSide(color: Color(0x33ffc174)),
            backgroundColor: _settingsLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildPaymentCard(
    IconData icon,
    String name,
    String status,
    String line1,
    String line2, {
    required bool isPrimary,
  }) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _settingsSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .27),
          blurRadius: 9,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _settingsHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _settingsGold, size: 23),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _settingsText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isPrimary) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _settingsGold.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'MẪU',
                            style: TextStyle(
                              color: _settingsGold,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    status,
                    style: const TextStyle(color: _settingsMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (_) =>
                  _showNotConfigured('Quản lý phương thức thanh toán'),
              color: _settingsSurface,
              icon: const Icon(
                Icons.more_vert,
                color: _settingsMuted,
                size: 19,
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Tùy chọn')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.info_outline, color: _settingsMint, size: 14),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                line1,
                style: const TextStyle(
                  color: _settingsMint,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              line2,
              style: const TextStyle(color: _settingsMuted, fontSize: 9),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildCryptoCard() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _settingsHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _settingsAmber,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.currency_bitcoin,
                color: Color(0xff472a00),
                size: 23,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ví Crypto / USDT',
                    style: TextStyle(
                      color: _settingsText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Không hỗ trợ trong ứng dụng',
                    style: TextStyle(color: _settingsMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.enhanced_encryption,
              color: _settingsGold,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xff0b0e14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Địa chỉ ví mặc định',
                      style: TextStyle(color: _settingsMuted, fontSize: 10),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Không có địa chỉ ví',
                      style: TextStyle(
                        color: _settingsGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'DEMO',
                style: TextStyle(
                  color: _settingsOutline,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSecuritySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(Icons.security, 'Bảo Mật Nâng Cao'),
      const SizedBox(height: 9),
      Container(
        decoration: BoxDecoration(
          color: _settingsSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .27),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _settingsRow(
              icon: Icons.phonelink_lock,
              title: 'Xác thực 2 bước (2FA)',
              subtitle: 'Authenticator chưa được kết nối',
              switchKey: 'twoFactor',
            ),
            _separator(),
            _settingsRow(
              icon: Icons.lock,
              title: 'Khóa két sắt an toàn',
              subtitle: 'PIN riêng chưa được thiết lập',
              trailing: TextButton(
                onPressed: () =>
                    _showNotConfigured('Thiết lập hoặc đổi mã PIN'),
                style: TextButton.styleFrom(
                  backgroundColor: _settingsHighest,
                  foregroundColor: _settingsText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                ),
                child: const Text('Đổi PIN', style: TextStyle(fontSize: 10)),
              ),
            ),
            _separator(),
            _settingsRow(
              icon: Icons.fingerprint,
              title: 'Sinh trắc học',
              subtitle: 'Đăng nhập nhanh chưa được kết nối',
              switchKey: 'biometric',
            ),
            _separator(),
            _settingsRow(
              icon: Icons.send,
              title: 'Cảnh báo thiết bị lạ',
              subtitle: 'Telegram Bot chưa được kết nối',
              switchKey: 'unknownDevice',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildPrivacySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(Icons.visibility_off, 'Quyền Riêng Tư Sảnh Cược'),
      const SizedBox(height: 9),
      Container(
        decoration: BoxDecoration(
          color: _settingsSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .27),
              blurRadius: 9,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _settingsRow(
              icon: Icons.account_balance_wallet,
              title: 'Ẩn số dư trên bàn',
              subtitle: 'Tùy chọn giao diện • chưa đồng bộ',
              switchKey: 'hideBalance',
            ),
            _separator(),
            _settingsRow(
              icon: Icons.leaderboard,
              title: 'Ẩn trên bảng xếp hạng',
              subtitle: 'Cài đặt riêng tư chưa được kết nối',
              switchKey: 'hideLeaderboard',
              alternate: true,
            ),
            _separator(),
            _settingsRow(
              icon: Icons.do_not_disturb_on,
              title: 'Chặn lời mời phòng riêng',
              subtitle: 'Chức năng mời chưa có trong bản demo',
              switchKey: 'blockInvites',
            ),
          ],
        ),
      ),
    ],
  );

  Widget _settingsRow({
    required IconData icon,
    required String title,
    required String subtitle,
    String? switchKey,
    Widget? trailing,
    bool alternate = false,
  }) => Container(
    color: alternate
        ? _settingsSurface.withValues(alpha: .6)
        : Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _settingsHigh,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _settingsGold, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _settingsText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _settingsMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        if (switchKey != null) _buildSwitch(switchKey) else ?trailing,
      ],
    ),
  );

  Widget _buildSwitch(String key) {
    final enabled = _switches[key] ?? false;
    return Semantics(
      button: true,
      toggled: enabled,
      label: 'Bật hoặc tắt cài đặt demo',
      child: GestureDetector(
        onTap: () => _toggle(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: enabled ? _settingsGold : _settingsHighest,
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: enabled ? const Color(0xff472a00) : _settingsMuted,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .25),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _separator() =>
      const Divider(height: 1, thickness: 1, color: Color(0x1610131a));

  Widget _buildDangerSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(Icons.warning_amber_rounded, 'Vùng Nguy Hiểm'),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xff0b0e14),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .3),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tạm khóa tài khoản tự nguyện',
                        style: TextStyle(
                          color: _settingsText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tính năng khóa tài khoản demo chưa khả dụng',
                        style: TextStyle(color: _settingsMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showNotConfigured('Tạm khóa tài khoản'),
                  style: TextButton.styleFrom(
                    backgroundColor: _settingsHigh,
                    foregroundColor: _settingsRed,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Khóa tạm', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0x22ffffff)),
            ),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đăng xuất thiết bị khác',
                        style: TextStyle(
                          color: _settingsRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Không thể thu hồi phiên khác từ ứng dụng demo',
                        style: TextStyle(color: _settingsMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () =>
                      _showNotConfigured('Đăng xuất các thiết bị khác'),
                  icon: const Icon(Icons.logout, size: 15),
                  label: const Text(
                    'Đăng xuất',
                    style: TextStyle(fontSize: 10),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffa40217),
                    foregroundColor: const Color(0xffffdad7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildDisclaimer() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _settingsLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_user, color: _settingsGold, size: 27),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Tài Xỉu PRM393 chỉ dùng điểm VNĐ mô phỏng để thực hành. Các công tắc cài đặt chỉ lưu tạm trên màn hình này; không cấu hình 2FA, sinh trắc học hay dịch vụ thanh toán.',
            style: TextStyle(color: _settingsMuted, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    ),
  );
}
