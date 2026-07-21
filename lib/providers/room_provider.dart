import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/song.dart';
import '../firebase/firestore_service.dart';
import 'audio_provider.dart';

class RoomProvider extends ChangeNotifier {
  final AudioProvider _audioProvider;
  
  Room? _currentRoom;
  List<RoomMember> _members = [];
  List<Song> _queue = [];
  List<String> _queueItemIds = [];
  List<RoomMessage> _messages = [];

  StreamSubscription? _roomSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _messagesSub;
  Timer? _syncTimer;

  int _localPlaybackVersion = -1;
  bool _isHost = false;
  bool _isLoading = false;
  bool _isTransitioning = false;
  bool _isSyncing = false;
  String? _userId;

  Room? get currentRoom => _currentRoom;
  List<RoomMember> get members => _members;
  List<Song> get queue => _queue;
  List<RoomMessage> get messages => _messages;
  bool get isHost => _isHost;
  bool get isLoading => _isLoading;
  bool get isInRoom => _currentRoom != null;

  RoomProvider(this._audioProvider) {
    _audioProvider.addListener(_onAudioProviderChanged);
  }

  void _onAudioProviderChanged() {
    if (_isHost && _audioProvider.songEnded && _queue.isNotEmpty && !_isTransitioning) {
      debugPrint('[ROOM_LOG] Song ended. Triggering next...');
      playNextInQueue();
    }
  }

  String _generateRoomKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<void> createRoom({
    required String name,
    required bool isPublic,
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    bool isPremium = false,
    List<Song> initialQueue = const [],
  }) async {
    _isLoading = true;
    _userId = hostId;
    notifyListeners();

    try {
      final roomKey = _generateRoomKey();
      final rooms = await FirestoreService.getPublicRooms();
      if (rooms.any((r) => r['name'].toString().toLowerCase() == name.toLowerCase())) {
        throw Exception('Tên phòng đã tồn tại');
      }

      final roomId = await FirestoreService.createRoom({
        'name': name,
        'isPublic': isPublic,
        'roomKey': roomKey,
        'hostId': hostId,
        'hostName': hostName,
        'hostPhotoUrl': hostPhotoUrl,
        'isPlaying': true,
        'currentSongId': initialQueue.isNotEmpty ? initialQueue.first.id : null,
        'currentPositionMs': 0,
        'isShuffle': _audioProvider.isShuffle,
        'repeatMode': _audioProvider.repeatMode.name,
        'playbackVersion': 0,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

      for (int i = 0; i < initialQueue.length; i++) {
        await FirestoreService.addToRoomQueue(roomId, initialQueue[i].toFirestore(), i);
      }
      
      _isHost = true;
      await joinRoomById(roomId, hostId, hostName, hostPhotoUrl, isPremium, isHost: true);
      
      if (initialQueue.isNotEmpty) {
         final firstSong = initialQueue.first;
         await _audioProvider.playSong(firstSong);
         await _updatePlaybackState(forceVersion: true);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> joinRoomById(String roomId, String userId, String userName, String? photoUrl, bool isPremium, {bool isHost = false}) async {
    _isLoading = true;
    _userId = userId;
    _localPlaybackVersion = -1;
    _audioProvider.isRemoteControlled = true;
    notifyListeners();

    try {
      await FirestoreService.addRoomMember(roomId, userId, {
        'name': userName,
        'photoUrl': photoUrl,
        'isPremium': isPremium,
        'isHost': isHost,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      _isHost = isHost;
      _setupListeners(roomId);
      if (_isHost) _startHostSync();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> joinRoomByKey(String roomKey, String userId, String userName, String? photoUrl, bool isPremium) async {
    final roomData = await FirestoreService.getRoomByKey(roomKey);
    if (roomData == null) throw Exception('Phòng không tồn tại');
    await joinRoomById(roomData['id'], userId, userName, photoUrl, isPremium);
  }

  void _setupListeners(String roomId) {
    _cancelListeners();
    _roomSub = FirestoreService.watchRoom(roomId).listen((doc) async {
      if (!doc.exists) { _onRoomClosed(); return; }
      final newRoom = Room.fromFirestore(doc);
      final prevRoom = _currentRoom;
      _currentRoom = newRoom;
      
      if (!_isHost) {
        await _syncAsMember(prevRoom);
      } else if (_currentRoom!.hostId != _userId) {
        _isHost = false;
        _syncTimer?.cancel();
      }
      notifyListeners();
    });

    _membersSub = FirestoreService.watchRoomMembers(roomId).listen((snapshot) {
      _members = snapshot.docs.map((doc) => RoomMember.fromFirestore(doc)).toList();
      final myMember = _members.firstWhere((m) => m.id == _userId, orElse: () => _members.first);
      if (myMember.id == _userId) {
        if (myMember.isHost && !_isHost) { _isHost = true; _startHostSync(); }
        else if (!myMember.isHost && _isHost) { _isHost = false; _syncTimer?.cancel(); }
      }
      notifyListeners();
    });

    _queueSub = FirestoreService.watchRoomQueue(roomId).listen((snapshot) {
      _queueItemIds = snapshot.docs.map((doc) => doc.id).toList();
      _queue = snapshot.docs.map((doc) => Song.fromFirestoreMap(doc.data() as Map<String, dynamic>)).toList();
      notifyListeners();
    });

    _messagesSub = FirestoreService.watchRoomMessages(roomId).listen((snapshot) {
      _messages = snapshot.docs.map((doc) => RoomMessage.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  Future<void> _syncAsMember(Room? prevRoom) async {
    if (_currentRoom == null || _isHost || _isSyncing) return;

    if (_currentRoom!.playbackVersion < _localPlaybackVersion) return;

    _isSyncing = true;
    try {
      bool versionChanged = _currentRoom!.playbackVersion > _localPlaybackVersion;
      
      // CHỈ đồng bộ bài hát và Play/Pause nếu Version tăng (Host chủ động thao tác)
      if (versionChanged) {
        debugPrint('[SYNC_LOG] Version detected: $_localPlaybackVersion -> ${_currentRoom!.playbackVersion}');
        _localPlaybackVersion = _currentRoom!.playbackVersion;

        // 1. Song Sync
        if (_currentRoom!.currentSongId != _audioProvider.currentSong?.id) {
          final newSongId = _currentRoom!.currentSongId;
          if (newSongId != null && newSongId.isNotEmpty) {
            Song? songToPlay;
            final inQueueIndex = _queue.indexWhere((s) => s.id == newSongId);
            songToPlay = (inQueueIndex != -1) ? _queue[inQueueIndex] : await FirestoreService.getSongById(newSongId);

            if (songToPlay != null) {
              await _audioProvider.playSong(songToPlay);
              int retry = 0;
              while (_audioProvider.duration.inMilliseconds <= 0 && retry < 25) {
                await Future.delayed(const Duration(milliseconds: 200));
                retry++;
              }
            }
          } else { await _audioProvider.stop(); }
        }

        // 2. Play/Pause Sync
        if (_currentRoom!.isPlaying != _audioProvider.isPlaying) {
          _currentRoom!.isPlaying ? await _audioProvider.play() : await _audioProvider.pause();
        }

        // 3. Initial Position Sync for new action
        if (_currentRoom!.lastUpdatedAt != null) {
          int expectedPos = _currentRoom!.currentPositionMs;
          if (_currentRoom!.isPlaying) {
            expectedPos += DateTime.now().difference(_currentRoom!.lastUpdatedAt!).inMilliseconds;
          }
          await _audioProvider.seek(Duration(milliseconds: max(0, expectedPos)));
        }
        return;
      }

      // Drift correction (Chỉ chạy khi cùng 1 bài hát và cùng 1 version)
      if (_currentRoom!.isPlaying && _audioProvider.duration.inMilliseconds > 0 && _currentRoom!.lastUpdatedAt != null) {
        final expectedPos = max(0, _currentRoom!.currentPositionMs + DateTime.now().difference(_currentRoom!.lastUpdatedAt!).inMilliseconds);
        final drift = (expectedPos - _audioProvider.position.inMilliseconds).abs();
        if (drift > 1000) { 
          debugPrint('[SYNC_LOG] Drift corrected: ${drift}ms');
          await _audioProvider.seek(Duration(milliseconds: expectedPos));
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _updatePlaybackState({bool forceVersion = true}) async {
    if (_currentRoom == null || !_isHost) return;
    final songId = _audioProvider.currentSong?.id;
    if (forceVersion && (songId == null || songId.isEmpty)) return;

    final data = {
      'isPlaying': _audioProvider.isPlaying,
      'currentSongId': songId,
      'currentPositionMs': _audioProvider.position.inMilliseconds,
      'isShuffle': _audioProvider.isShuffle,
      'repeatMode': _audioProvider.repeatMode.name,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (forceVersion) {
      data['playbackVersion'] = FieldValue.increment(1);
      debugPrint('[HOST_LOG] Action: $songId, Version++');
    }
    await FirestoreService.updateRoom(_currentRoom!.id, data);
  }

  void _startHostSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isHost && _currentRoom != null && !_isTransitioning) _updatePlaybackState(forceVersion: false);
    });
  }

  void _onRoomClosed() { leaveRoom(); }

  Future<void> leaveRoom() async {
    if (_currentRoom != null && _userId != null) {
      if (_isHost) {
        final otherPremium = _members.where((m) => m.id != _userId && m.isPremium).toList();
        if (otherPremium.isNotEmpty) {
          final newHost = otherPremium.first;
          await FirestoreService.transferHost(_currentRoom!.id, _userId!, newHost.id, {'name': newHost.name, 'photoUrl': newHost.photoUrl});
        } else { await FirestoreService.deleteRoom(_currentRoom!.id); }
      } else { await FirestoreService.removeRoomMember(_currentRoom!.id, _userId!); }
    }
    _audioProvider.isRemoteControlled = false;
    _cancelListeners();
    _syncTimer?.cancel();
    _currentRoom = null;
    _members = []; _queue = []; _messages = []; _isHost = false;
    _audioProvider.stop();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (!_isHost) return;
    await _audioProvider.togglePlayPause();
    await _updatePlaybackState();
  }

  Future<void> seek(int positionMs) async {
    if (!_isHost) return;
    await _audioProvider.seek(Duration(milliseconds: positionMs));
    await _updatePlaybackState();
  }

  Future<void> playSongAt(int index) async {
    if (!_isHost || index < 0 || index >= _queue.length) return;
    _isTransitioning = true;
    try {
      await _audioProvider.playSong(_queue[index]);
      int retry = 0;
      while (_audioProvider.duration.inMilliseconds <= 0 && retry < 25) {
        await Future.delayed(const Duration(milliseconds: 200));
        retry++;
      }
      await _updatePlaybackState();
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      _isTransitioning = false;
    }
  }

  Future<void> playNextInQueue() async {
    if (!_isHost || _queue.isEmpty) return;
    _isTransitioning = true;
    try {
      int currentIndex = -1;
      if (_audioProvider.currentSong != null) {
        currentIndex = _queue.indexWhere((s) => s.id == _audioProvider.currentSong!.id);
      }
      final nextSong = _queue[(currentIndex + 1) % _queue.length];
      await _audioProvider.playSong(nextSong);
      int retry = 0;
      while (_audioProvider.duration.inMilliseconds <= 0 && retry < 25) {
        await Future.delayed(const Duration(milliseconds: 200));
        retry++;
      }
      await _updatePlaybackState();
    } finally {
      await Future.delayed(const Duration(milliseconds: 300));
      _isTransitioning = false;
    }
  }

  Future<void> skipPrevious() async {
    if (!_isHost) return;
    if (_audioProvider.position.inSeconds > 5) {
      await seek(0);
    } else if (_queue.isNotEmpty) {
      _isTransitioning = true;
      try {
        int currentIndex = _queue.indexWhere((s) => s.id == _audioProvider.currentSong?.id);
        final prevSong = _queue[(currentIndex - 1 + _queue.length) % _queue.length];
        await _audioProvider.playSong(prevSong);
        int retry = 0;
        while (_audioProvider.duration.inMilliseconds <= 0 && retry < 25) {
          await Future.delayed(const Duration(milliseconds: 200));
          retry++;
        }
        await _updatePlaybackState();
      } finally {
        await Future.delayed(const Duration(milliseconds: 300));
        _isTransitioning = false;
      }
    }
  }

  Future<void> toggleShuffle() async { if (!_isHost) return; _audioProvider.toggleShuffle(); await _updatePlaybackState(); }
  Future<void> toggleRepeat() async { if (!_isHost) return; _audioProvider.toggleRepeat(); await _updatePlaybackState(); }

  void sendMessage(String text, String senderId, String senderName, String? photoUrl) {
    if (_currentRoom == null) return;
    FirestoreService.sendRoomMessage(_currentRoom!.id, {'text': text, 'senderId': senderId, 'senderName': senderName, 'senderPhotoUrl': photoUrl});
  }

  Future<void> deleteMessage(String messageId) async {
    if (_currentRoom == null || !_isHost) return;
    await FirestoreService.deleteRoomMessage(_currentRoom!.id, messageId);
  }

  Future<void> addToQueue(Song song) async {
    if (_currentRoom == null || !_isHost) return;
    await FirestoreService.addToRoomQueue(_currentRoom!.id, song.toFirestore(), _queue.length);
    await _updatePlaybackState();
  }

  Future<void> removeFromQueue(int index) async {
     if (_currentRoom == null || !_isHost) return;
     await FirestoreService.removeFromRoomQueue(_currentRoom!.id, _queueItemIds[index]);
     await _updatePlaybackState();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (_currentRoom == null || !_isHost) return;
    await FirestoreService.updateQueueOrder(_currentRoom!.id, _queueItemIds[oldIndex], newIndex);
    await _updatePlaybackState();
  }

  Future<void> clearQueue() async {
     if (_currentRoom == null || !_isHost) return;
     await FirestoreService.clearRoomQueue(_currentRoom!.id);
     await _updatePlaybackState();
  }

  Future<void> kickMember(String userId) async {
    if (_currentRoom == null || !_isHost) return;
    await FirestoreService.kickMember(_currentRoom!.id, userId);
  }

  Future<void> transferHost(String newHostId) async {
    if (_currentRoom == null || !_isHost) return;
    final newHost = _members.firstWhere((m) => m.id == newHostId);
    await FirestoreService.transferHost(_currentRoom!.id, _userId!, newHostId, {'name': newHost.name, 'photoUrl': newHost.photoUrl});
  }

  void _cancelListeners() {
    _roomSub?.cancel(); _membersSub?.cancel(); _queueSub?.cancel(); _messagesSub?.cancel();
  }

  @override
  void dispose() {
    _audioProvider.removeListener(_onAudioProviderChanged);
    _cancelListeners();
    _syncTimer?.cancel();
    super.dispose();
  }
}
