import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения (ФТ-16). Хранятся на устройстве (shared_preferences).
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs)
      : themeMode = ThemeMode.values[(_prefs.getInt(_kTheme) ?? 0).clamp(0, ThemeMode.values.length - 1)],
        notificationsEnabled = _prefs.getBool(_kNotifications) ?? true,
        defaultReminder = _decode(_prefs.getInt(_kDefaultReminder) ?? 15);

  final SharedPreferences _prefs;

  static const _kTheme = 'theme_mode';
  static const _kNotifications = 'notifications_enabled';
  static const _kDefaultReminder = 'default_reminder';

  ThemeMode themeMode; // system / light / dark
  bool notificationsEnabled;
  int? defaultReminder; // минут до дедлайна, null — без напоминания

  // null нельзя сохранить в SharedPreferences как int, поэтому кодируем его как -1
  static int? _decode(int v) => v < 0 ? null : v;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs.setInt(_kTheme, mode.index);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kNotifications, value);
  }

  Future<void> setDefaultReminder(int? minutes) async {
    defaultReminder = minutes;
    notifyListeners();
    await _prefs.setInt(_kDefaultReminder, minutes ?? -1);
  }
}
