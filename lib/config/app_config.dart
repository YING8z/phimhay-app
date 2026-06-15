class AppConfig {
  static const String baseUrl = 'https://xiaofilm.click';
  static const String apiUrl = 'https://xiaofilm.click/api';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  /// Convert HLS URL → proxy URL (cho web, tránh CORS)
  static String proxyHlsUrl(String url) {
    return '$apiUrl/hls_proxy.php?url=${Uri.encodeComponent(url)}';
  }

  /// Server health check endpoint
  static const String serverHealthUrl = '$apiUrl/server_health.php';
}
