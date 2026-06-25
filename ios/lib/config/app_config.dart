class AppConfig {
  static String get baseUrl => 'https://junyphoret.online';
  static String get apiUrl  => 'https://junyphoret.online/api';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  static String proxyHlsUrl(String url) {
    return '$apiUrl/hls_proxy.php?url=${Uri.encodeComponent(url)}';
  }

  static String get serverHealthUrl => '$apiUrl/server_health.php';
}
