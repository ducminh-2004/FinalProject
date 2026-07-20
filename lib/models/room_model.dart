import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus { active, closed }

class Room {
  final String id;
  final String hostId;
  final String hostName;
  final String roomName;
  final String joinKey; // Unique key để vào phòng nhanh
  final String? currentSongId;
  final int currentPositionMs;
  final bool isPlaying;
  final List<String> playlist; // Danh sách ID bài hát
  final List<String> participants;
  final DateTime createdAt;
  final RoomStatus status;
  final bool isPrivate;

  Room({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.roomName,
    required this.joinKey,
    this.currentSongId,
    this.currentPositionMs = 0,
    this.isPlaying = false,
    required this.playlist,
    required this.participants,
    required this.createdAt,
    this.status = RoomStatus.active,
    this.isPrivate = false,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Xử lý an toàn cho createdAt
    DateTime time;
    if (data['createdAt'] is Timestamp) {
      time = (data['createdAt'] as Timestamp).toDate();
    } else {
      time = DateTime.now();
    }

    return Room(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? 'Host',
      roomName: data['roomName'] ?? 'Listening Party',
      joinKey: data['joinKey'] ?? '',
      currentSongId: data['currentSongId'],
      currentPositionMs: data['currentPositionMs'] ?? 0,
      isPlaying: data['isPlaying'] ?? false,
      playlist: List<String>.from(data['playlist'] ?? []),
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: time,
      status: RoomStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RoomStatus.active,
      ),
      isPrivate: data['isPrivate'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'roomName': roomName,
      'joinKey': joinKey,
      'currentSongId': currentSongId,
      'currentPositionMs': currentPositionMs,
      'isPlaying': isPlaying,
      'playlist': playlist,
      'participants': participants,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status.name,
      'isPrivate': isPrivate,
    };
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'User',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
