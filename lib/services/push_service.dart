import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:phimhay_app/services/api_client.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  static Stream<RemoteMessage> get onMessage => _messageController.stream;

  static Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) print('Push permission status: ${settings.authorizationStatus}');

    // Fix hang on iOS: Wrap token getting in try-catch and wait for APNS on iOS
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          if (kDebugMode) print('APNS token not available yet, waiting...');
        }
      }

      final token = await _messaging.getToken();
      if (kDebugMode) print('FCM Token: $token');
    } catch (e) {
      if (kDebugMode) print('Error getting FCM token: $e');
    }

    _messaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) print('FCM Token refreshed: $newToken');
      _sendTokenToServer(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _messageController.add(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _messageController.add(message);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _messageController.add(initialMessage);
    }
  }

  /// Gửi FCM token lên server — thử retry 5 lần nếu chưa có token
  /// Trả về chuỗi kết quả (success hoặc chi tiết lỗi) để hiển thị lên UI
  static Future<String> sendTokenToServerAfterLogin() async {
    if (kDebugMode) print('[PushService] START');

    String? token;
    String getTokError = '';
    for (int i = 0; i < 5; i++) {
      try {
        token = await _messaging.getToken();
      } catch (e) {
        getTokError = e.toString();
        if (kDebugMode) print('[PushService] getToken attempt $i error: $e');
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      if (token != null && token.isNotEmpty) {
        if (kDebugMode) print('[PushService] Token obtained: ${token.substring(0, 15)}...');
        break;
      }
      if (kDebugMode) print('[PushService] getToken attempt $i empty, retry in 1s');
      await Future.delayed(const Duration(seconds: 1));
    }

    if (token == null || token.isEmpty) {
      return 'Không lấy được FCM token. Lỗi: $getTokError';
    }

    if (kDebugMode) print('[PushService] Sending token: ${token.substring(0, 20)}...');

    String sendError = '';
    for (int i = 0; i < 3; i++) {
      try {
        final res = await ApiClient.post(
          '/PushSubscription.php',
          data: {
            'action': 'save_fcm',
            'fcm_token': token,
          },
        );

        dynamic responseData = res.data;
        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (_) {}
        }

        if (responseData is Map) {
          if (responseData['success'] == true) {
            return 'SUCCESS';
          } else {
            sendError = responseData['error'] ?? 'Server trả về success=false';
          }
        } else {
          sendError = 'Response không phải JSON Map: $responseData';
        }
      } catch (e) {
        sendError = e.toString();
      }
      if (kDebugMode) print('[PushService] Send attempt $i failed: $sendError, retry in 1s');
      await Future.delayed(const Duration(seconds: 1));
    }
    return 'Lỗi gửi token: $sendError';
  }

  static Future<bool> _sendTokenToServer(String token) async {
    try {
      final res = await ApiClient.post(
        '/PushSubscription.php',
        data: {
          'action': 'save_fcm',
          'fcm_token': token,
        },
      );

      dynamic responseData = res.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } catch (_) {}
      }

      if (responseData is Map) {
        if (kDebugMode) print('[PushService] Response: $responseData');
        return responseData['success'] == true;
      }

      if (kDebugMode) print('[PushService] Response is not Map: $responseData');
      return false;
    } catch (e) {
      if (kDebugMode) print('[PushService] Error: $e');
      return false;
    }
  }

  static Future<void> subscribeToMovie(String movieSlug) async {
    try {
      final topic = 'movie_${movieSlug.replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      if (kDebugMode) print('Failed to subscribe: $e');
    }
  }

  static Future<void> unsubscribeFromMovie(String movieSlug) async {
    try {
      final topic = 'movie_${movieSlug.replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      if (kDebugMode) print('Failed to unsubscribe: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) print('[PushService] getToken error: $e');
      return null;
    }
  }
}