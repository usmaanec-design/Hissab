import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static const String _keyPinHash = 'hissab_security_pin_hash';
  static const String _keyPinEnabled = 'hissab_security_pin_enabled';
  static const String _salt = 'hissab_secure_salt_2026';

  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPinEnabled) ?? false;
  }

  static Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  static String _hashPin(String pin) {
    final bytes = utf8.encode('$pin:$_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await prefs.setString(_keyPinHash, hash);
    await prefs.setBool(_keyPinEnabled, true);
  }

  static Future<bool> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyPinHash);
    if (storedHash == null) return false;
    return storedHash == _hashPin(enteredPin);
  }

  static Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPinEnabled, false);
    await prefs.remove(_keyPinHash);
  }
}
