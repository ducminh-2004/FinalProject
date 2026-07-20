import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class RoomService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String generateJoinKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  static Future<String> createRoom({
    required String hostId,
    required String hostName,
    required String roomName,
    List<String> initialPlaylist = const [],
    bool isPrivate = false,
  }) async {
    final joinKey = generateJoinKey();
    final docRef = _db.collection('rooms').doc();
    
    final room = Room(
      id: docRef.id,
      hostId: hostId,
      hostName: hostName,
      roomName: roomName,
      joinKey: joinKey,
      playlist: initialPlaylist,
      currentSongId: initialPlaylist.isNotEmpty ? initialPlaylist.first : null,
      isPlaying: initialPlaylist.isNotEmpty,
      participants: [hostId],
      createdAt: DateTime.now(),
      isPrivate: isPrivate,
    );

    await docRef.set(room.toFirestore());
    return docRef.id;
  }

  static Future<String?> findRoomByKey(String key) async {
    final snapshot = await _db
        .collection('rooms')
        .where('joinKey', isEqualTo: key.toUpperCase())
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
  }

  static Stream<Room> watchRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((doc) => Room.fromFirestore(doc));
  }

  static Future<void> sendMessage(String roomId, String senderId, String senderName, String? senderPhotoUrl, String text) async {
    await _db.collection('rooms').doc(roomId).collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updatePlayback({
    required String roomId,
    String? songId,
    int? positionMs,
    bool? isPlaying,
    List<String>? playlist,
  }) async {
    final Map<String, dynamic> updates = {};
    if (songId != null) updates['currentSongId'] = songId;
    if (positionMs != null) updates['currentPositionMs'] = positionMs;
    if (isPlaying != null) updates['isPlaying'] = isPlaying;
    if (playlist != null) updates['playlist'] = playlist;

    await _db.collection('rooms').doc(roomId).update(updates);
  }

  static Future<void> addToPlaylist(String roomId, List<String> songIds) async {
    await _db.collection('rooms').doc(roomId).update({
      'playlist': FieldValue.arrayUnion(songIds),
    });
  }

  static Future<void> removeFromPlaylist(String roomId, String songId) async {
    await _db.collection('rooms').doc(roomId).update({
      'playlist': FieldValue.arrayRemove([songId]),
    });
  }

  static Future<void> updatePlaylist(String roomId, List<String> newPlaylist) async {
    await _db.collection('rooms').doc(roomId).update({
      'playlist': newPlaylist,
    });
  }

  static Future<void> joinRoom(String roomId, String userId) async {
    await _db.collection('rooms').doc(roomId).update({
      'participants': FieldValue.arrayUnion([userId]),
    });
  }

  static Future<void> leaveRoom(String roomId, String userId) async {
    final roomDoc = await _db.collection('rooms').doc(roomId).get();
    if (!roomDoc.exists) return;
    
    final room = Room.fromFirestore(roomDoc);
    
    // Nếu là Host rời phòng -> Đóng phòng luôn
    if (room.hostId == userId) {
      await _db.collection('rooms').doc(roomId).update({
        'status': RoomStatus.closed.name,
        'participants': FieldValue.arrayRemove([userId]),
      });
      return;
    }

    // Nếu là khách -> Chỉ xóa khỏi danh sách tham gia
    await _db.collection('rooms').doc(roomId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });
  }
}
