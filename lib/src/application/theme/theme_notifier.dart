import 'package:flutter/material.dart';
import 'package:myapp/src/data/services/session_manager.dart';

class ThemeNotifier with ChangeNotifier {
  final SessionManager _sessionManager;

  bool? _isDarkMode;
  bool? get isDarkMode => _isDarkMode;

  ThemeNotifier(this._sessionManager) {
    _sessionManager.isDarkModeFlow.listen((isDark) {
      _isDarkMode = isDark;
      notifyListeners();
    });
  }

  ThemeMode get themeMode {
    if (_isDarkMode == null) return ThemeMode.system;
    return _isDarkMode! ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setTheme(bool? isDarkMode) async {
    await _sessionManager.saveTheme(isDarkMode);
  }
}
