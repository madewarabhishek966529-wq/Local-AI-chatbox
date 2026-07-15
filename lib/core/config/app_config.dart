/// Central config. Every value here points at infrastructure that runs on
/// the local network — the Spring Boot backend and Ollama, both started via
/// `docker compose up` from the backend repo. There is no cloud fallback.
class AppConfig {
  AppConfig._();

  /// Default backend base URL when running the Docker Compose stack on the
  /// same machine as the Flutter app (desktop/web/emulator on host).
  ///
  /// - Android emulator talking to host machine: use 10.0.2.2 instead of
  ///   localhost.
  /// - Physical device on the same LAN: use the host machine's LAN IP,
  ///   e.g. http://192.168.1.20:8080
  /// This is intentionally overridable at runtime (see SettingsRepository)
  /// so the app can be pointed at whichever machine is running the stack.
  static const String defaultBaseUrl = 'http://localhost:8080/api';

  static const String defaultWsUrl = 'ws://localhost:8080/ws';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Hive box names
  static const String boxConversations = 'conversations';
  static const String boxMessages = 'messages';
  static const String boxSettings = 'settings';
  static const String boxAuth = 'auth';

  // Secure storage keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
}
