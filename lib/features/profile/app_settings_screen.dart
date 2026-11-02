import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_text.dart';
import '../../core/app_preferences.dart';

const _appSettingsBg = Color(0xff10131a);
const _appSettingsLow = Color(0xff191c22);
const _appSettingsSurface = Color(0xff1d2026);
const _appSettingsHigh = Color(0xff272a31);
const _appSettingsHighest = Color(0xff32353c);
const _appSettingsGold = Color(0xffffc174);
const _appSettingsAmber = Color(0xfff59e0b);
const _appSettingsMint = Color(0xff56e5a9);
const _appSettingsText = Color(0xffe1e2eb);
const _appSettingsMuted = Color(0xffd8c3ad);

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final Map<String, bool> _switches = {
    'music': true,
    'dice': true,
    'vibration': true,
    'eventNotice': true,
    'pointNotice': true,
    'appNotice': true,
  };

  double _musicVolume = 75;
  double _diceVolume = 90;
  String _dealer = 'MC Miền Nam';
  String _fps = '60 FPS';
  String _road = 'Cầu Bàn Cờ';
  String _language = 'Tiếng Việt';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final key in _switches.keys) {
        _switches[key] = prefs.getBool('appSettings.$key') ?? _switches[key]!;
      }
      _musicVolume = prefs.getDouble('appSettings.musicVolume') ?? _musicVolume;
      _diceVolume = prefs.getDouble('appSettings.diceVolume') ?? _diceVolume;
      _dealer = prefs.getString('appSettings.dealer') ?? _dealer;
      _fps = prefs.getString('appSettings.fps') ?? _fps;
      _road = prefs.getString('appSettings.road') ?? _road;
      _language = AppPreferences.languageLabel;
    });
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _switches.entries) {
      await prefs.setBool('appSettings.${entry.key}', entry.value);
    }
    await prefs.setDouble('appSettings.musicVolume', _musicVolume);
    await prefs.setDouble('appSettings.diceVolume', _diceVolume);
    await prefs.setString('appSettings.dealer', _dealer);
    await prefs.setString('appSettings.fps', _fps);
    await prefs.setString('appSettings.road', _road);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _appSettingsHighest,
        ),
      );
  }

  void _showUnavailable(String feature) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _appSettingsSurface,
        title: const Text(
          'Chưa khả dụng',
          style: TextStyle(color: _appSettingsGold),
        ),
        content: Text(
          '$feature chưa được tích hợp. Rung phản hồi, kiểu bảng cầu và ngôn ngữ ứng dụng hiện đang hoạt động.',
          style: const TextStyle(color: _appSettingsText, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _appSettingsBg,
    appBar: AppBar(
      backgroundColor: const Color(0xee0b0e14),
      foregroundColor: _appSettingsText,
      centerTitle: true,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .4),
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_ios_new, size: 21),
      ),
      title: const Text(
        'Cài Đặt Ứng Dụng',
        style: TextStyle(
          color: _appSettingsGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Thông tin cài đặt',
          onPressed: () => _showUnavailable('Các tuỳ chọn'),
          icon: const Icon(Icons.support_agent, color: _appSettingsGold),
        ),
      ],
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.9),
          radius: 1.2,
          colors: [Color(0x14f59e0b), _appSettingsBg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              children: [
                _buildTopBanner(),
                const SizedBox(height: 14),
                _buildAudioSection(),
                const SizedBox(height: 14),
                _buildDisplaySection(),
                const SizedBox(height: 14),
                _buildNotificationSection(),
                const SizedBox(height: 14),
                _buildSystemSection(),
                const SizedBox(height: 18),
                const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune, color: _appSettingsGold, size: 17),
                        SizedBox(width: 7),
                        Text(
                          'CÀI ĐẶT ỨNG DỤNG',
                          style: TextStyle(
                            color: _appSettingsGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Rung, kiểu bảng cầu và ngôn ngữ được áp dụng. Âm thanh, FPS và thông báo chưa được tích hợp.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _appSettingsMuted,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildTopBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _appSettingsSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -40,
          top: -50,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: _appSettingsAmber.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _appSettingsHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .2),
                    blurRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.tune, color: _appSettingsGold, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 7,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Tuỳ Chỉnh Trải Nghiệm',
                        style: TextStyle(
                          color: _appSettingsGold,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _appSettingsAmber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'CÀI ĐẶT',
                          style: TextStyle(
                            color: Color(0xff472a00),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tuỳ chỉnh phản hồi, bảng cầu và ngôn ngữ ứng dụng.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _appSettingsMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _sectionHeader(IconData icon, String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      children: [
        Icon(icon, color: _appSettingsGold, size: 20),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: _appSettingsGold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .75,
          ),
        ),
      ],
    ),
  );

  Widget _sectionCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _appSettingsSurface,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .25),
          blurRadius: 9,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _buildAudioSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader(Icons.volume_up, 'Âm Thanh & Phản Hồi'),
      const SizedBox(height: 8),
      _sectionCard([
        _switchRow(
          keyName: 'music',
          icon: Icons.music_note,
          title: 'Nhạc Nền',
          subtitle: 'Tuỳ chọn giao diện • chưa có âm thanh nền',
          onChanged: () => _showUnavailable('Nhạc nền'),
        ),
        _sliderRow(
          icon: Icons.volume_mute,
          value: _musicVolume,
          onChanged: null,
        ),
        const SizedBox(height: 10),
        _switchRow(
          keyName: 'dice',
          icon: Icons.casino,
          title: 'Hiệu Ứng Xúc Xắc',
          subtitle: 'Âm thanh lắc chưa được tích hợp',
          onChanged: () => _showUnavailable('Hiệu ứng xúc xắc'),
        ),
        _sliderRow(
          icon: Icons.volume_down,
          value: _diceVolume,
          onChanged: null,
        ),
        const SizedBox(height: 10),
        _switchRow(
          keyName: 'vibration',
          icon: Icons.vibration,
          title: 'Rung Phản Hồi',
          subtitle: 'Rung nhẹ khi chọn cược và tuỳ chọn',
        ),
        const SizedBox(height: 14),
        _settingLabel(Icons.record_voice_over, 'Giọng Đọc'),
        const SizedBox(height: 7),
        _choiceGrid(
          options: const ['MC Miền Nam', 'MC Miền Bắc'],
          selected: _dealer,
          onSelected: (_) => _showUnavailable('Giọng đọc MC'),
          columns: 2,
        ),
      ]),
    ],
  );

  Widget _buildDisplaySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader(Icons.display_settings, 'Đồ Hoạ & Bàn Chơi'),
      const SizedBox(height: 8),
      _sectionCard([
        _settingLabel(Icons.casino_outlined, 'Chất Lượng Hiển Thị'),
        const SizedBox(height: 7),
        _choiceGrid(
          options: const ['60 FPS', '120 FPS'],
          selected: _fps,
          onSelected: (_) => _showUnavailable('Tuỳ chọn FPS'),
          columns: 2,
          descriptions: const [
            'Tuỳ chọn tiết kiệm pin',
            'Tuỳ chọn hiển thị cao',
          ],
        ),
        const SizedBox(height: 14),
        _settingLabel(Icons.analytics_outlined, 'Kiểu Hiển Thị Bảng Cầu'),
        const SizedBox(height: 7),
        _choiceGrid(
          options: const ['Cầu Bàn Cờ', 'Cầu Tóm Tắt', 'Cầu Giọt Nước'],
          selected: _road,
          onSelected: (value) {
            setState(() => _road = value);
            unawaited(AppPreferences.setRoadStyle(value));
            unawaited(AppPreferences.selectionFeedback());
            _showMessage('Đã lưu kiểu hiển thị $value.');
          },
          columns: 3,
          icons: const [Icons.grid_view, Icons.analytics, Icons.water_drop],
        ),
        const SizedBox(height: 14),
        _settingLabel(Icons.language, 'Ngôn Ngữ Ứng Dụng'),
        const SizedBox(height: 7),
        _choiceGrid(
          options: const ['Tiếng Việt', 'English', '中文'],
          selected: _language,
          onSelected: (value) {
            setState(() => _language = value);
            unawaited(AppPreferences.setLanguage(value));
            _showMessage('Đã chuyển ngôn ngữ sang $value.');
          },
          columns: 3,
        ),
      ]),
    ],
  );

  Widget _buildNotificationSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeader(Icons.notifications_active, 'Thông Báo'),
      const SizedBox(height: 8),
      _sectionCard([
        _switchRow(
          keyName: 'eventNotice',
          icon: Icons.emoji_events,
          iconBackground: const Color(0xffa40217),
          iconForeground: const Color(0xffffaea8),
          title: 'Thông Báo Sự Kiện',
          subtitle: 'Thông báo đẩy chưa được cấu hình',
          onChanged: () => _showUnavailable('Thông báo sự kiện'),
        ),
        const SizedBox(height: 12),
        _switchRow(
          keyName: 'pointNotice',
          icon: Icons.payments,
          iconBackground: const Color(0xff30c88f),
          iconForeground: const Color(0xff003824),
          title: 'Biến Động Điểm Ảo',
          subtitle: 'Không có thông báo nạp/rút tiền thật',
          onChanged: () => _showUnavailable('Thông báo điểm ảo'),
        ),
        const SizedBox(height: 12),
        _switchRow(
          keyName: 'appNotice',
          icon: Icons.campaign,
          iconBackground: _appSettingsAmber,
          iconForeground: const Color(0xff472a00),
          title: 'Cập Nhật Ứng Dụng',
          subtitle: 'Không có khuyến mãi hoặc lì xì trong demo',
          onChanged: () => _showUnavailable('Thông báo ứng dụng'),
        ),
      ]),
    ],
  );

  Widget _buildSystemSection() => _sectionCard([
    Row(
      children: [
        _iconBox(Icons.cleaning_services, color: _appSettingsGold),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dọn Bộ Nhớ Đệm',
                style: TextStyle(
                  color: _appSettingsText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Chức năng dọn cache chưa khả dụng',
                style: TextStyle(color: _appSettingsMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _showUnavailable('Dọn bộ nhớ đệm'),
          style: TextButton.styleFrom(
            foregroundColor: _appSettingsGold,
            backgroundColor: _appSettingsHighest,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          ),
          child: const Text('Xóa Ngay', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
    const SizedBox(height: 14),
    Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _appSettingsLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: _appSettingsMint, size: 18),
          const SizedBox(width: 7),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version 1.0.0+1',
                  style: TextStyle(
                    color: _appSettingsText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bản demo Flutter • chưa có cập nhật trực tuyến',
                  style: TextStyle(color: _appSettingsMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showMessage(
              'Ứng dụng demo chưa kết nối dịch vụ kiểm tra cập nhật.',
            ),
            icon: const Icon(Icons.sync, size: 15),
            label: const Text('Kiểm Tra', style: TextStyle(fontSize: 10)),
            style: TextButton.styleFrom(foregroundColor: _appSettingsText),
          ),
        ],
      ),
    ),
  ]);

  Widget _settingLabel(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: _appSettingsGold, size: 19),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _appSettingsText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );

  Widget _switchRow({
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconBackground,
    Color? iconForeground,
    VoidCallback? onChanged,
  }) => Row(
    children: [
      _iconBox(
        icon,
        background: iconBackground,
        color: iconForeground ?? _appSettingsGold,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _appSettingsText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _appSettingsMuted,
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      _GoldSwitch(
        value: _switches[keyName] ?? false,
        onChanged: (value) {
          if (onChanged != null) {
            onChanged();
            return;
          }
          setState(() => _switches[keyName] = value);
          unawaited(_persistPreferences());
          if (keyName == 'vibration') {
            unawaited(AppPreferences.setVibrationEnabled(value));
            if (value) unawaited(AppPreferences.selectionFeedback());
          }
          onChanged?.call();
        },
      ),
    ],
  );

  Widget _iconBox(
    IconData icon, {
    Color? background,
    Color color = _appSettingsGold,
  }) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: background ?? _appSettingsHigh,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Icon(icon, color: color, size: 21),
  );

  Widget _sliderRow({
    required IconData icon,
    required double value,
    required ValueChanged<double>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(left: 42, right: 3, top: 3),
    child: Row(
      children: [
        Icon(icon, color: _appSettingsMuted, size: 16),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _appSettingsGold,
              inactiveTrackColor: _appSettingsHigh,
              thumbColor: _appSettingsGold,
              overlayColor: _appSettingsGold.withValues(alpha: .15),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              min: 0,
              max: 100,
              divisions: 100,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _appSettingsGold,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _choiceGrid({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required int columns,
    List<String>? descriptions,
    List<IconData>? icons,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 7.0;
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var i = 0; i < options.length; i++)
            SizedBox(
              width: itemWidth,
              child: _ChoiceTile(
                title: options[i],
                subtitle: descriptions != null && i < descriptions.length
                    ? descriptions[i]
                    : null,
                icon: icons != null && i < icons.length ? icons[i] : null,
                selected: options[i] == selected,
                onTap: () => onSelected(options[i]),
              ),
            ),
        ],
      );
    },
  );
}

class _GoldSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GoldSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? _appSettingsGold : _appSettingsHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: value ? const Color(0xff613b00) : _appSettingsMuted,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
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

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _appSettingsGold : _appSettingsHigh,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: selected ? const Color(0xff472a00) : _appSettingsText,
              ),
              const SizedBox(height: 3),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? const Color(0xff472a00) : _appSettingsText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? const Color(0xff613b00) : _appSettingsMuted,
                  fontSize: 9,
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
