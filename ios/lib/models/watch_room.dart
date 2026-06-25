class WatchRoom {
  final String roomCode;
  final int movieId;
  final int episodeId;
  final int hostId;
  final String hostName;
  final String movieName;
  final String movieSlug;
  final String videoState; // 'playing' | 'paused'
  final double videoTime;
  final String status; // 'live' | 'waiting' | 'ended'

  WatchRoom({
    required this.roomCode,
    required this.movieId,
    required this.episodeId,
    required this.hostId,
    required this.hostName,
    required this.movieName,
    required this.movieSlug,
    this.videoState = 'paused',
    this.videoTime = 0,
    this.status = 'live',
  });

  factory WatchRoom.fromJson(Map<String, dynamic> json) {
    return WatchRoom(
      roomCode: json['room_code'] ?? '',
      movieId: json['movie_id'] ?? 0,
      episodeId: json['episode_id'] ?? 0,
      hostId: json['host_id'] ?? 0,
      hostName: json['host_name'] ?? '',
      movieName: json['movie_name'] ?? '',
      movieSlug: json['movie_slug'] ?? '',
      videoState: json['video_state'] ?? 'paused',
      videoTime: (json['video_time'] ?? 0).toDouble(),
      status: json['status'] ?? 'live',
    );
  }
}

class ChatMessage {
  final int id;
  final String author;
  final String avatar;
  final String message;
  final bool isHost;
  final String time;

  ChatMessage({
    required this.id,
    required this.author,
    required this.avatar,
    required this.message,
    required this.isHost,
    required this.time,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      author: json['author'] ?? '',
      avatar: json['avatar'] ?? '',
      message: json['message'] ?? '',
      isHost: json['is_host'] ?? false,
      time: json['time'] ?? '',
    );
  }
}

class VoiceParticipant {
  final String name;
  final String avatar;
  bool isMuted;
  bool isSpeaking;

  VoiceParticipant({
    required this.name,
    this.avatar = '',
    this.isMuted = true,
    this.isSpeaking = false,
  });

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    return VoiceParticipant(
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      isMuted: json['is_muted'] ?? true,
      isSpeaking: json['is_speaking'] ?? false,
    );
  }
}

class RoomMember {
  final String name;
  final String avatar;
  final bool isHost;
  final bool inVoice;

  RoomMember({
    required this.name,
    this.avatar = '',
    this.isHost = false,
    this.inVoice = false,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      isHost: json['is_host'] ?? false,
      inVoice: json['in_voice'] ?? false,
    );
  }
}
