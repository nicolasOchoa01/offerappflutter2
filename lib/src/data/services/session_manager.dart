import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _isDarkModeKey = 'isDarkMode';

  // StreamControllers to broadcast state changes, mimicking Kotlin's Flow.
  final _isLoggedInController = StreamController<bool>.broadcast();
  final _isDarkModeController = StreamController<bool?>.broadcast();

  Stream<bool> get isLoggedInFlow => _isLoggedInController.stream;
  Stream<bool?> get isDarkModeFlow => _isDarkModeController.stream;

  SessionManager() {
    _init();
  }

  // Initializes the streams with values from SharedPreferences.
  void _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedInController.add(prefs.getBool(_isLoggedInKey) ?? false);
    // We allow null for system theme preference
    _isDarkModeController.add(prefs.getBool(_isDarkModeKey));
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<bool?> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isDarkModeKey);
  }

  Future<void> saveSessionState(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, isLoggedIn);
    _isLoggedInController.add(isLoggedIn);
  }

  Future<void> clearSession() async {
    await saveSessionState(false);
  }

  Future<void> saveTheme(bool? isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDarkMode == null) {
      await prefs.remove(_isDarkModeKey);
    } else {
      await prefs.setBool(_isDarkModeKey, isDarkMode);
    }
    _isDarkModeController.add(isDarkMode);
  }

  void dispose() {
    _isLoggedInController.close();
    _isDarkModeController.close();
  }
}
