class AppLogger {
  static void info(String msg) {
    // ignore: avoid_print
    print("ℹ️ $msg");
  }

  static void success(String msg) {
    // ignore: avoid_print
    print("✅ $msg");
  }

  static void error(String msg) {
    // ignore: avoid_print
    print("❌ $msg");
  }
}