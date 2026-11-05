import 'package:tai_xiu_realtime/core/backend_functions.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../core/app_text.dart';

const _profileBg = Color(0xff10131a);
const _profileLow = Color(0xff191c22);
const _profileSurface = Color(0xff1d2026);
const _profileHigh = Color(0xff272a31);
const _profileGold = Color(0xffffc174);
const _profileAmber = Color(0xfff59e0b);
const _profileMint = Color(0xff56e5a9);
const _profileText = Color(0xffe1e2eb);
const _profileMuted = Color(0xffd8c3ad);
const _profileOutline = Color(0xffa08e7a);

class EditProfileScreen extends StatefulWidget {
  final User user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nickname;
  final _slogan = TextEditingController(
    text: 'Đánh là Thắng - Cầu bệt theo đến cùng',
  );
  late String _initialNickname;
  late String _initialSlogan;
  String _initialGender = 'male';
  String _initialFrame = 'dragon';
  String _gender = 'male';
  String _frame = 'dragon';
  bool _saving = false;

  static const _portraitUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuA0PqQoDL7LPubiCE6DFvvFmAOMp3422bFnLqbFbq17w123vE2KR_MCU_Gpqrkfm9h3638oG2lqJhpuvL_peoZ4azguux6r40dM_14zGc3Wehe6MR0u91I2BTlDYkx9B0ziW66b00F1vBTijIAiGMV7ue5VahJRffS1mSaGfPH0VvE4fm3i_hA7Y3Pjq5txtuEnbacuW6Zvm9QSko8LPmKfH27O6uAPQqTOpZTTGWHg';

  @override
  void initState() {
    super.initState();
    final userName = widget.user.email?.split('@').first ?? 'HoiVien';
    _initialNickname = userName.isEmpty ? 'Hội viên' : userName;
    _initialSlogan = _slogan.text;
    _nickname = TextEditingController(text: _initialNickname);
    _slogan.addListener(_refresh);
    unawaited(_loadProfile());
  }

  Future<void> _loadProfile() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .doc('users/${widget.user.uid}')
          .get();
      final profile = snapshot.data();
      if (!mounted || profile == null) return;
      setState(() {
        if (_nickname.text == _initialNickname &&
            profile['nickname'] is String) {
          _nickname.text = profile['nickname'] as String;
        }
        if (_slogan.text == _initialSlogan && profile['bio'] is String) {
          _slogan.text = profile['bio'] as String;
        }
        if (profile['gender'] is String) _gender = profile['gender'] as String;
        if (profile['avatarFrame'] is String) {
          _frame = profile['avatarFrame'] as String;
        }
        _initialNickname = _nickname.text;
        _initialSlogan = _slogan.text;
        _initialGender = _gender;
        _initialFrame = _frame;
      });
    } catch (_) {
      // The form remains usable if a profile has not been created yet.
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _slogan.removeListener(_refresh);
    _slogan.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  void _cancel() {
    _nickname.text = _initialNickname;
    _slogan.text = _initialSlogan;
    setState(() {
      _gender = _initialGender;
      _frame = _initialFrame;
    });
  }

  Future<void> _save() async {
    if (_nickname.text.trim().isEmpty) {
      _message('Biệt danh không được để trống.');
      return;
    }
    setState(() => _saving = true);
    try {
      final result =
          await FirebaseFunctions.instanceFor(
            region: 'asia-southeast1',
          ).gameCallable('updateMyProfile').call<Map<String, dynamic>>({
            'nickname': _nickname.text.trim(),
            'bio': _slogan.text.trim(),
            'gender': _gender,
            'avatarFrame': _frame,
          });
      if (!mounted) return;
      _initialNickname = _nickname.text.trim();
      _initialSlogan = _slogan.text.trim();
      _initialGender = _gender;
      _initialFrame = _frame;
      _message(
        result.data['ok'] == true
            ? 'Đã lưu hồ sơ lên Firebase.'
            : 'Không lưu được hồ sơ.',
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _message(error.message ?? 'Firebase Auth lỗi: ${error.code}.');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) _message(error.message ?? 'Lỗi lưu hồ sơ: ${error.code}.');
    } catch (error) {
      if (mounted) _message('Không lưu được hồ sơ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _profileBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _profileText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Chỉnh Sửa Hồ Sơ',
        style: TextStyle(
          color: _profileGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'CSKH 24/7',
          onPressed: () =>
              _message('Kênh hỗ trợ chưa được cấu hình trong bản demo.'),
          icon: const Icon(Icons.support_agent, color: _profileGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.25,
          colors: [Color(0x14f59e0b), _profileBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _buildMemberStrip(),
            const SizedBox(height: 12),
            _buildAvatarCard(),
            const SizedBox(height: 12),
            _buildDemoNotice(),
            const SizedBox(height: 16),
            _buildNickname(),
            const SizedBox(height: 16),
            _buildEmail(),
            const SizedBox(height: 16),
            _buildGender(),
            const SizedBox(height: 16),
            _buildSlogan(),
            const SizedBox(height: 12),
            _buildPreview(),
            const SizedBox(height: 20),
            _buildActions(),
          ],
        ),
      ),
    ),
  );

  Widget _buildMemberStrip() => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: _profileHigh,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _profileAmber,
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Icon(
            Icons.military_tech,
            color: Color(0xff472a00),
            size: 19,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CẤP BẬC HỘI VIÊN',
                style: TextStyle(
                  color: _profileGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
              Text(
                'Tài khoản điểm mô phỏng • ${widget.user.emailVerified ? 'Email đã xác thực' : 'Email chưa xác thực'}',
                style: const TextStyle(
                  color: _profileText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xff0b0e14),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.user.emailVerified
                    ? Icons.verified_user
                    : Icons.info_outline,
                color: widget.user.emailVerified ? _profileMint : _profileGold,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                widget.user.emailVerified ? 'XÁC THỰC' : 'DEMO',
                style: TextStyle(
                  color: widget.user.emailVerified
                      ? _profileMint
                      : _profileGold,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildAvatarCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _profileSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .3),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 116,
              height: 116,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: _frameColors),
                boxShadow: [
                  BoxShadow(
                    color: _frameColors.first.withValues(alpha: .2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  _portraitUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: const Color(0xff0b0e14),
                    child: const Icon(
                      Icons.person,
                      color: _profileGold,
                      size: 55,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          color: const Color(0xff0b0e14),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _profileGold,
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xff0b0e14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    color: _profileGold,
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: 0,
              child: Material(
                color: _profileGold,
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => _message(
                    'Tải ảnh đại diện chưa được cấu hình trong bản demo.',
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.photo_camera,
                    color: Color(0xff472a00),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _nickname.text.trim().isEmpty ? 'Hội viên' : _nickname.text.trim(),
          style: const TextStyle(
            color: _profileGold,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'ID: #${_shortUid(widget.user.uid)}',
          style: const TextStyle(color: _profileMuted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _buildFrameShelf(),
      ],
    ),
  );

  List<Color> get _frameColors => switch (_frame) {
    'phoenix' => const [_profileRed, Color(0xffa40217), _profileGold],
    'wealth' => const [_profileMint, _profileGold, Color(0xffffddb8)],
    _ => const [_profileGold, Color(0xffffddb8), _profileAmber],
  };

  static const _profileRed = Color(0xffffb3ad);

  String _shortUid(String uid) =>
      uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();

  Widget _buildFrameShelf() {
    final frames = [
      ('dragon', Icons.workspace_premium, _profileGold, 'Rồng Vàng'),
      ('phoenix', Icons.local_fire_department, _profileRed, 'Phượng Lửa'),
      ('wealth', Icons.monetization_on, const Color(0xffffddb8), 'Thần Tài'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _profileLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars, color: _profileGold, size: 14),
                  SizedBox(width: 5),
                  Text(
                    'KHUNG VIỀN VƯƠNG GIẢ VIP',
                    style: TextStyle(
                      color: _profileText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
              Text(
                '${frames.length} khung demo',
                style: const TextStyle(color: _profileGold, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: frames.map((frame) {
              final selected = _frame == frame.$1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: frame.$1 == 'wealth' ? 0 : 6),
                  child: Material(
                    color: selected ? _profileHigh : _profileSurface,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _frame = frame.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 3,
                        ),
                        child: Column(
                          children: [
                            Icon(frame.$2, color: frame.$3, size: 20),
                            const SizedBox(height: 3),
                            Text(
                              frame.$4,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? _profileGold : _profileText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected ? 'Đang chọn' : 'Kích hoạt',
                              style: TextStyle(
                                color: selected ? _profileMint : _profileMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoNotice() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _profileHigh,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Color(0x33a40217),
          child: Icon(Icons.lock_person, color: _profileRed, size: 18),
        ),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HỒ SƠ DÙNG TRONG BẢN DEMO',
                style: TextStyle(
                  color: _profileRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Số dư VNĐ trong ứng dụng chỉ là điểm mô phỏng. Không có nạp/rút, đối soát ngân hàng hoặc quà tặng bằng tiền thật.',
                style: TextStyle(
                  color: _profileMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(IconData icon, String label, {Widget? trailing}) => Row(
    children: [
      Icon(icon, color: _profileGold, size: 18),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(
            color: _profileText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _fieldBox({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 3,
    ),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xff0b0e14),
      borderRadius: BorderRadius.circular(9),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .35),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: appLocalizedText(hint),
    hintStyle: const TextStyle(color: _profileOutline, fontSize: 13),
    border: InputBorder.none,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 10),
  );

  Widget _buildNickname() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(
        Icons.badge,
        'Biệt Danh Bàn Cược',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _profileHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Hồ sơ demo',
            style: TextStyle(
              color: _profileGold,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      _fieldBox(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nickname,
                maxLength: 24,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: _profileText,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _inputDecoration(
                  'Nhập biệt danh',
                ).copyWith(counterText: ''),
              ),
            ),
            const Icon(Icons.edit, color: _profileGold, size: 20),
          ],
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Biệt danh chỉ được lưu trong phiên demo này.',
        style: TextStyle(color: _profileMuted, fontSize: 11),
      ),
    ],
  );

  Widget _buildEmail() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(Icons.mark_email_read, 'Email Tài Khoản'),
      const SizedBox(height: 7),
      _fieldBox(
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.user.email ?? 'Chưa có email',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _profileText, fontSize: 14),
              ),
            ),
            Icon(
              widget.user.emailVerified ? Icons.verified : Icons.lock_outline,
              color: widget.user.emailVerified ? _profileMint : _profileGold,
              size: 18,
            ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Email tài khoản chỉ xem, không thể chỉnh sửa tại đây.',
        style: TextStyle(color: _profileMuted, fontSize: 11),
      ),
    ],
  );

  Widget _buildGender() {
    final options = [
      ('male', Icons.male, 'Nam'),
      ('female', Icons.female, 'Nữ'),
      ('other', Icons.diversity_3, 'Khác'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(Icons.wc, 'Giới Tính'),
        const SizedBox(height: 7),
        Row(
          children: options.map((option) {
            final selected = _gender == option.$1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option.$1 == 'other' ? 0 : 8),
                child: Material(
                  color: selected ? _profileHigh : _profileSurface,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => setState(() => _gender = option.$1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            option.$2,
                            color: selected ? _profileGold : _profileMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            option.$3,
                            style: TextStyle(
                              color: selected ? _profileGold : _profileMuted,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSlogan() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionLabel(
        Icons.record_voice_over,
        'Chữ Ký Sảnh Cược / Slogan',
        trailing: Text(
          '${_slogan.text.length}/60',
          style: const TextStyle(color: _profileOutline, fontSize: 10),
        ),
      ),
      const SizedBox(height: 7),
      _fieldBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: TextField(
          controller: _slogan,
          maxLength: 60,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            color: _profileText,
            fontSize: 15,
            height: 1.4,
          ),
          decoration: _inputDecoration('Nhập slogan').copyWith(counterText: ''),
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Hiển thị bản xem trước tại bàn chơi. Chỉ là nội dung mẫu ở phiên bản hiện tại.',
        style: TextStyle(color: _profileMuted, fontSize: 11),
      ),
    ],
  );

  Widget _buildPreview() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _profileLow,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .28),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xff0b0e14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.casino, color: _profileGold, size: 27),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HIỂN THỊ THỰC TẾ TẠI BÀN',
                style: TextStyle(
                  color: _profileMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _slogan.text.isEmpty ? 'Chưa có slogan' : '“${_slogan.text}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _profileGold,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildActions() => Column(
    children: [
      Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [_profileGold, _profileAmber, _profileGold],
          ),
          boxShadow: [
            BoxShadow(
              color: _profileAmber.withValues(alpha: .22),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _saving ? null : _save,
            child: Center(
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xff472a00),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Color(0xff472a00), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'LƯU THAY ĐỔI',
                          style: TextStyle(
                            color: Color(0xff472a00),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: _cancel,
          style: FilledButton.styleFrom(
            backgroundColor: _profileHigh,
            foregroundColor: _profileText,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Hủy Bỏ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );
}
