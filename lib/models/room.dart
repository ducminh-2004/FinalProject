import 'package:cloud_firestore/cloud_firestore.dart';

class Room {
  final String id;
  final String name;
  final String hostId;
  final String hostName;
  final String? hostPhotoUrl;
  final String roomKey;
  final bool isPublic;
  final bool isPlaying;
  final String? currentSongId;
  final int currentPositionMs;
  final bool isShuffle;
  final String repeatMode;
  final int playbackVersion;
  final DateTime? lastUpdatedAt;

  Room({
    required this.id,
    required this.name,
    required this.hostId,
    required this.hostName,
    this.hostPhotoUrl,
    required this.roomKey,
    required this.isPublic,
    required this.isPlaying,
    this.currentSongId,
    required this.currentPositionMs,
    required this.isShuffle,
    required this.repeatMode,
    required this.playbackVersion,
    this.lastUpdatedAt,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Room(
      id: doc.id,
      name: data['name'] ?? '',
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostPhotoUrl: data['hostPhotoUrl'],
      roomKey: data['roomKey'] ?? '',
      isPublic: data['isPublic'] ?? true,
      isPlaying: data['isPlaying'] ?? false,
      currentSongId: data['currentSongId'],
      currentPositionMs: data['currentPositionMs'] ?? 0,
      isShuffle: data['isShuffle'] ?? false,
      repeatMode: data['repeatMode'] ?? 'none',
      playbackVersion: data['playbackVersion'] ?? 0,
      lastUpdatedAt: (data['lastUpdatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class RoomMember {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isPremium;
  final bool isHost;
  final DateTime joinedAt;

  RoomMember({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.isPremium,
    required this.isHost,
    required this.joinedAt,
  });

  factory RoomMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomMember(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      isPremium: data['isPremium'] ?? false,
      isHost: data['isHost'] ?? false,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class RoomMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;

  RoomMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
  });

  factory RoomMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
