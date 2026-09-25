import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabasePlatform {
  static bool _initialized = false;

  /// Centralized database platform initializer for Native Mobile and Desktop
  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Desktop SQLite FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android and iOS automatically use the standard sqflite native method channel
    _initialized = true;
  }

  /// Resolves the database storage location deterministically
  static Future<String> getDatabasePath(String filename) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docDir = await getApplicationDocumentsDirectory();
      final hissabDir = Directory(p.join(docDir.path, 'Hissab'));
      if (!hissabDir.existsSync()) {
        hissabDir.createSync(recursive: true);
      }
      return p.join(hissabDir.path, filename);
    } else {
      // Android / iOS
      final dbFolder = await getDatabasesPath();
      return p.join(dbFolder, filename);
    }
  }
}
