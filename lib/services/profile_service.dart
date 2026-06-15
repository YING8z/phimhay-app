import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../services/api_client.dart';
import 'dart:io';

class ProfileService {
  final Dio _dio = ApiClient.dio;

  /// Get user profile + stats + tab data
  Future<Map<String, dynamic>> fetchProfile(String tab) async {
    final res = await _dio.get(
      '${AppConfig.apiUrl}/profile.php',
      queryParameters: {'tab': tab},
    );
    return res.data as Map<String, dynamic>;
  }

  /// Update email/avatar
  Future<Map<String, dynamic>> updateProfile({
    required String email,
    String avatar = '',
  }) async {
    final res = await _dio.post(
      '${AppConfig.apiUrl}/profile_update.php',
      data: FormData.fromMap({
        'action': 'update_profile',
        'email': email,
        'avatar': avatar,
      }),
    );
    return res.data as Map<String, dynamic>;
  }

  /// Upload avatar image file
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'action': 'upload_avatar',
        'avatar': await MultipartFile.fromFile(imageFile.path, filename: 'avatar.jpg'),
      });
      final res = await _dio.post(
        '${AppConfig.apiUrl}/profile_update.php',
        data: formData,
      );
      final data = res.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Change password
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _dio.post(
      '${AppConfig.apiUrl}/profile_update.php',
      data: FormData.fromMap({
        'action': 'change_password',
        'old_password': oldPassword,
        'new_password': newPassword,
        'new_password2': newPassword,
      }),
    );
    return res.data as Map<String, dynamic>;
  }
}
