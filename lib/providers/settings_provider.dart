import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyDir = 'default_working_dir';
  static const _keySkip = 'skip_permissions';
  static const _keyDark = 'is_dark_mode';

  String _defaultWorkingDirectory = '~';
  bool _skipPermissions = false;
  bool _isDarkMode = true;

  String get defaultWorkingDirectory => _defaultWorkingDirectory;
  bool get skipPermissions => _skipPermissions;
  bool get isDarkMode => _isDarkMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _defaultWorkingDirectory = prefs.getString(_keyDir) ?? '~';
    _skipPermissions = prefs.getBool(_keySkip) ?? false;
    _isDarkMode = prefs.getBool(_keyDark) ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDark, _isDarkMode);
    notifyListeners();
  }

  Future<void> setDefaultWorkingDirectory(String value) async {
    _defaultWorkingDirectory = value.trim().isEmpty ? '~' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDir, _defaultWorkingDirectory);
    notifyListeners();
  }

  Future<void> setSkipPermissions(bool value) async {
    _skipPermissions = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySkip, value);
    notifyListeners();
  }
}
