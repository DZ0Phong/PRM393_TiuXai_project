import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences._();

  static const _vibrationKey = 'appSettings.vibration';
  static const _roadKey = 'appSettings.road';
  static const _languageKey = 'appSettings.language';
  static final ValueNotifier<Locale> locale = ValueNotifier<Locale>(
    const Locale('vi'),
  );

  static Future<void> loadLanguage() async {
    final preferences = await SharedPreferences.getInstance();
    final code = preferences.getString(_languageKey) ?? 'vi';
    locale.value = Locale(code);
  }

  static Future<void> setLanguage(String language) async {
    final code = switch (language) {
      'English' => 'en',
      '中文' => 'zh',
      _ => 'vi',
    };
    locale.value = Locale(code);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageKey, code);
  }

  static String get languageLabel => switch (locale.value.languageCode) {
    'en' => 'English',
    'zh' => '中文',
    _ => 'Tiếng Việt',
  };

  static Future<bool> vibrationEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_vibrationKey) ?? true;

  static Future<void> setVibrationEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_vibrationKey, enabled);
  }

  static Future<void> selectionFeedback() async {
    if (await vibrationEnabled()) await HapticFeedback.selectionClick();
  }

  static Future<String> roadStyle() async =>
      (await SharedPreferences.getInstance()).getString(_roadKey) ??
      'Cầu Bàn Cờ';

  static Future<void> setRoadStyle(String style) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_roadKey, style);
  }
}
