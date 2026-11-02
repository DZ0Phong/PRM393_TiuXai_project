import 'package:flutter/material.dart';

const _bg = Color(0xff10131a);
const _surface = Color(0xff191c22);
const _gold = Color(0xffffc174);
const _goldContainer = Color(0xfff59e0b);
const _mint = Color(0xff56e5a9);
const _text = Color(0xffe1e2eb);
const _muted = Color(0xffd8c3ad);

class PasswordChangeSuccessScreen extends StatelessWidget {
  const PasswordChangeSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date = '${now.day}/${now.month}/${now.year}';

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.7),
            radius: 1.15,
            colors: [Color(0x1effc174), _bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(context),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          _successIcon(),
                          const SizedBox(height: 20),
                          const Text(
                            'Đổi Mật Khẩu Thành Công!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _gold,
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Firebase Auth đã xác nhận cập nhật mật khẩu cho tài khoản của bạn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _detailsCard(time: time, date: date),
                          const SizedBox(height: 14),
                          _sessionNotice(),
                          const SizedBox(height: 22),
                          _doneButton(context),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            onPressed: () => _showSupportNotice(context),
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: const Text('Cần trợ giúp?'),
                            style: TextButton.styleFrom(foregroundColor: _gold),
                          ),
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
    );
  }

  Widget _topBar(BuildContext context) => Container(
    color: const Color(0x660b0e14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: _gold, size: 19),
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'BẢO MẬT TÀI KHOẢN',
                style: TextStyle(
                  color: _gold,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Đổi Mật Khẩu Thành Công',
                style: TextStyle(
                  color: _text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Hỗ trợ',
          onPressed: () => _showSupportNotice(context),
          icon: const Icon(Icons.support_agent, color: _gold),
        ),
      ],
    ),
  );

  Widget _successIcon() => Container(
    width: 92,
    height: 92,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _mint.withValues(alpha: .12),
      border: Border.all(color: _mint.withValues(alpha: .45), width: 1.5),
      boxShadow: [
        BoxShadow(color: _mint.withValues(alpha: .12), blurRadius: 24),
      ],
    ),
    child: const Icon(Icons.check_circle, color: _mint, size: 54),
  );

  Widget _detailsCard({required String time, required String date}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xff534434).withValues(alpha: .5),
          ),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.security_update_good, color: _mint, size: 20),
                SizedBox(width: 8),
                Text(
                  'TRẠNG THÁI CẬP NHẬT',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .8,
                  ),
                ),
                Spacer(),
                Text(
                  'HOÀN TẤT',
                  style: TextStyle(
                    color: _mint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _detailRow(Icons.schedule, 'Thời gian', '$time · $date'),
            const SizedBox(height: 12),
            _detailRow(
              Icons.verified_user,
              'Xác nhận bởi',
              'Firebase Authentication',
            ),
            const SizedBox(height: 12),
            _detailRow(Icons.lock_outline, 'Mật khẩu', 'Đã cập nhật'),
          ],
        ),
      );

  Widget _detailRow(IconData icon, String title, String value) => Row(
    children: [
      Icon(icon, color: _gold, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(title, style: const TextStyle(color: _muted, fontSize: 12)),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: _text,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _sessionNotice() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _goldContainer.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _goldContainer.withValues(alpha: .25)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: _gold, size: 19),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Thay đổi mật khẩu không đảm bảo tự đăng xuất các phiên khác. Nếu bạn không thực hiện thao tác này, hãy đăng xuất và liên hệ quản trị viên dự án.',
            style: TextStyle(color: _text, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _doneButton(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton.icon(
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.check, size: 20),
      label: const Text(
        'HOÀN TẤT',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        foregroundColor: const Color(0xff2a1700),
        backgroundColor: _gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );

  static void _showSupportNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kênh hỗ trợ chưa được cấu hình trong bản demo.'),
      ),
    );
  }
}
