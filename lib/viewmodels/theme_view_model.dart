import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _preferenceKey = 'app_theme_mode';
  final SharedPreferencesAsync _preferences;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final savedMode = await _preferences.getString(_preferenceKey);
    _themeMode = savedMode == ThemeMode.dark.name ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggle() async {
    await setDarkMode(!isDarkMode);
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;
    _themeMode = nextMode;
    notifyListeners();
    await _preferences.setString(_preferenceKey, nextMode.name);
  }
}
