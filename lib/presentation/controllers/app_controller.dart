import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hissab/core/security/security_service.dart';

class AppController extends ChangeNotifier {
  static const String _keyLocale = 'hissab_locale';
  static const String _keyThemeMode = 'hissab_theme_mode';
  static const String _keyActiveBookId = 'hissab_active_book_id';

  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;
  String? _activeBookId;
  bool _isUnlocked = true;
  bool _isPinProtected = false;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  String? get activeBookId => _activeBookId;
  bool get isUnlocked => _isUnlocked;
  bool get isPinProtected => _isPinProtected;

  bool get isRtl => _locale.languageCode == 'ar' || _locale.languageCode == 'ur';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load locale
    final savedLang = prefs.getString(_keyLocale);
    if (savedLang != null) {
      _locale = Locale(savedLang);
    }

    // Load theme mode
    final savedTheme = prefs.getString(_keyThemeMode);
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }

    // Load active book ID
    _activeBookId = prefs.getString(_keyActiveBookId);

    // Check PIN lock
    _isPinProtected = await SecurityService.isPinEnabled();
    if (_isPinProtected) {
      _isUnlocked = false;
    }

    notifyListeners();
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, languageCode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.dark) val = 'dark';
    if (mode == ThemeMode.light) val = 'light';
    await prefs.setString(_keyThemeMode, val);
    notifyListeners();
  }

  Future<void> setActiveBookId(String bookId) async {
    _activeBookId = bookId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyActiveBookId, bookId);
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final valid = await SecurityService.verifyPin(pin);
    if (valid) {
      _isUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockApp() {
    if (_isPinProtected) {
      _isUnlocked = false;
      notifyListeners();
    }
  }

  Future<void> refreshSecurityState() async {
    _isPinProtected = await SecurityService.isPinEnabled();
    notifyListeners();
  }
}
