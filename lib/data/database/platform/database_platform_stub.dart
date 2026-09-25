abstract class DatabasePlatform {
  static Future<void> initialize() async {
    throw UnsupportedError('Cannot initialize database on unknown platform.');
  }

  static Future<String> getDatabasePath(String filename) async {
    throw UnsupportedError('Cannot determine database path on unknown platform.');
  }
}
