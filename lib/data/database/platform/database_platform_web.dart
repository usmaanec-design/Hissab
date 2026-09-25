import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabasePlatform {
  static bool _initialized = false;

  /// Centralized database platform initializer for Flutter Web
  static Future<void> initialize() async {
    if (_initialized) return;

    // Use standard sqflite_common_ffi_web worker database factory
    databaseFactory = databaseFactoryFfiWeb;
    _initialized = true;
  }

  /// Resolves the database storage name for Web
  static Future<String> getDatabasePath(String filename) async {
    return filename;
  }
}
