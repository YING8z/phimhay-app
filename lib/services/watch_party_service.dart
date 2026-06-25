import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/watch_room.dart';
import 'api_client.dart';

class WatchPartyService {
  /// Tạo room mới
  Future<Map<String, dynamic>> createRoom({
    required int movieId,
    required int episodeId,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'create_room',
          'movie_id': movieId,
          'episode_id': episodeId,
        }),
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': 'Lỗi kết nối'};
    }
  }

  /// Ping để lấy state hiện tại + members + messages
  Future<Map<String, dynamic>> ping({
    required String roomCode,
    int lastMsgId = 0,
    bool inVoice = false,
    bool isMuted = true,
    bool isSpeaking = false,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_room_sync.php',
        data: FormData.fromMap({
          'action': 'ping',
          'room_code': roomCode,
          'last_msg_id': lastMsgId,
          'in_voice': inVoice ? '1' : '0',
          'is_muted': isMuted ? '1' : '0',
          'is_speaking': isSpeaking ? '1' : '0',
        }),
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false};
    }
  }

  /// Cập nhật video state (chỉ host)
  Future<bool> updateState({
    required String roomCode,
    required double videoTime,
    required String videoState,
    double videoDuration = 0,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_room_sync.php',
        data: FormData.fromMap({
          'action': 'update_state',
          'room_code': roomCode,
          'video_time': videoTime,
          'video_state': videoState,
          'video_duration': videoDuration,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Gửi tin nhắn chat
  Future<bool> sendChat({
    required String roomCode,
    required String message,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_room_sync.php',
        data: FormData.fromMap({
          'action': 'send_chat',
          'room_code': roomCode,
          'message': message,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Kết thúc phòng (host only)
  Future<bool> endRoom(String roomCode) async {
    try {
      final res = await ApiClient.post(
        '/watch_room_sync.php',
        data: FormData.fromMap({
          'action': 'end_room',
          'room_code': roomCode,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Xóa phòng (host only)
  Future<bool> deleteRoom(int roomId) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'delete_room',
          'room_id': roomId,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Rời phòng
  Future<bool> leaveRoom(String roomCode) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'leave_room',
          'room_code': roomCode,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Chuyển tập (host only)
  Future<bool> switchEpisode({
    required String roomCode,
    required int episodeId,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'switch_episode',
          'room_code': roomCode,
          'episode_id': episodeId,
        }),
      );
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Xác thực mật khẩu phòng
  Future<Map<String, dynamic>> verifyPassword({
    required String roomCode,
    required String password,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'verify_password',
          'room_code': roomCode,
          'password': password,
        }),
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': 'Lỗi kết nối'};
    }
  }

  /// Cập nhật mật khẩu phòng (host only)
  Future<Map<String, dynamic>> updatePassword({
    required String roomCode,
    required String password,
  }) async {
    try {
      final res = await ApiClient.post(
        '/watch_party.php',
        data: FormData.fromMap({
          'action': 'update_password',
          'room_code': roomCode,
          'room_password': password,
        }),
      );
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'error': 'Lỗi kết nối'};
    }
  }
}
