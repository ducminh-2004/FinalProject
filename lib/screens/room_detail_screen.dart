import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/room_model.dart';
import '../models/song.dart';
import '../widgets/add_song_room_sheet.dart';
import '../services/room_service.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';

class RoomDetailScreen extends StatefulWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  StreamSubscription? _roomSubscription;
  Room? _room;
  bool _isHost = false;
  Song? _currentSong;
  List<Song> _playlistSongs = [];
  
  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _initRoom();
  }

  void _initRoom() async {
    final userId = context.read<UserProvider>().userId;
    // Tham gia phòng
    await RoomService.joinRoom(widget.roomId, userId!);

    _roomSubscription = RoomService.watchRoom(widget.roomId).listen((room) async {
      if (!mounted) return;
      
      // Kiểm tra nếu phòng đã đóng
      if (room.status == RoomStatus.closed) {
        _roomSubscription?.cancel();
        if (mounted) {
          final audio = context.read<AudioProvider>();
          await audio.stop();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phòng đã được đóng bởi host')),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
        return;
      }

      // Load bài hát nếu thay đổi
      if (_room?.currentSongId != room.currentSongId) {
        if (room.currentSongId != null) {
          final song = await FirestoreService.getSongById(room.currentSongId!);
          if (mounted) setState(() => _currentSong = song);
        } else {
          setState(() => _currentSong = null);
        }
      }

      // Load playlist nếu thay đổi
      if (_room == null || _room!.playlist.length != room.playlist.length) {
        if (room.playlist.isNotEmpty) {
          final songs = await FirestoreService.getSongsByIds(room.playlist);
          if (mounted) setState(() => _playlistSongs = songs);
        } else {
          setState(() => _playlistSongs = []);
        }
      }

      setState(() {
        _room = room;
        _isHost = room.hostId == userId;
      });

      if (!_isHost) {
        _syncMusicWithHost(room);
      }
    });

    // Nếu là Host, cập nhật vị trí nhạc lên Firestore định kỳ
    if (_isHost) {
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted || !_isHost || _room == null) {
          timer.cancel();
          return;
        }
        final audio = context.read<AudioProvider>();
        if (audio.hasSong) {
          RoomService.updatePlayback(
            roomId: widget.roomId,
            songId: audio.currentSong!.id,
            positionMs: audio.position.inMilliseconds,
            isPlaying: audio.isPlaying,
          );
        }
      });
    }
  }

  void _syncMusicWithHost(Room room) async {
    final audio = context.read<AudioProvider>();
    if (room.currentSongId == null) return;

    // Nếu bài hát trên Firestore khác bài hiện tại của guest
    if (audio.currentSong?.id != room.currentSongId) {
      if (_currentSong != null && _currentSong!.id == room.currentSongId) {
        // Tải bài hát và tua đến vị trí hiện tại của host
        await audio.playSong(_currentSong!);
        await audio.seek(Duration(milliseconds: room.currentPositionMs + 500)); // Bù đắp trễ mạng
        if (!room.isPlaying) await audio.pause();
      }
    } else {
      // Nếu cùng bài hát, kiểm tra độ lệch thời gian
      final diff = (audio.position.inMilliseconds - room.currentPositionMs).abs();
      if (diff > 2000) { // Nếu lệch hơn 2 giây thì đồng bộ lại
        await audio.seek(Duration(milliseconds: room.currentPositionMs + 300));
      }
      
      // Đồng bộ trạng thái Play/Pause
      if (room.isPlaying && !audio.isPlaying) await audio.play();
      if (!room.isPlaying && audio.isPlaying) await audio.pause();
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final user = context.read<UserProvider>();
    RoomService.sendMessage(widget.roomId, user.userId!, user.displayName ?? 'User', user.photoUrl, _messageController.text.trim());
    _messageController.clear();
  }

  void _nextSong() async {
    if (!_isHost || _room == null || _room!.playlist.isEmpty) return;
    final currentIndex = _room!.playlist.indexOf(_room!.currentSongId ?? '');
    if (currentIndex != -1 && currentIndex < _room!.playlist.length - 1) {
      final nextId = _room!.playlist[currentIndex + 1];
      await RoomService.updatePlayback(roomId: widget.roomId, songId: nextId, positionMs: 0, isPlaying: true);
    }
  }

  void _previousSong() async {
    if (!_isHost || _room == null || _room!.playlist.isEmpty) return;
    final currentIndex = _room!.playlist.indexOf(_room!.currentSongId ?? '');
    if (currentIndex > 0) {
      final prevId = _room!.playlist[currentIndex - 1];
      await RoomService.updatePlayback(roomId: widget.roomId, songId: prevId, positionMs: 0, isPlaying: true);
    }
  }

  void _togglePlayback() async {
    if (!_isHost || _room == null) return;
    await RoomService.updatePlayback(roomId: widget.roomId, isPlaying: !_room!.isPlaying);
  }

  void _stopPlayback() async {
    if (!_isHost || _room == null) return;
    await RoomService.updatePlayback(roomId: widget.roomId, isPlaying: false, positionMs: 0);
    context.read<AudioProvider>().stop();
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_room!.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Mã: ${_room!.joinKey} • ${_room!.participants.length} người', 
                style: const TextStyle(fontSize: 12, color: _mintGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _leaveRoom(),
            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCurrentPlaying(),
          const Divider(height: 1),
          Expanded(
            child: Row(
              children: [
                // Chỉ hiển thị Chat ở đây nếu là màn hình lớn
                if (isDesktop)
                  Expanded(flex: 3, child: _buildChatSection()),
                
                if (isDesktop)
                  Expanded(flex: 2, child: _buildPlaylistSection())
                else
                  // Trên Mobile, phần này sẽ chiếm hết không gian để chứa TabBarView
                  Expanded(child: _buildMobileTabs()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlaying() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _currentSong?.coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_currentSong!.coverUrl!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.music_note_rounded, size: 30, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_room!.isPlaying ? 'ĐANG PHÁT' : 'ĐANG TẠM DỪNG', 
                        style: const TextStyle(color: _mintGreen, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                    Text(_currentSong?.title ?? 'Đang chờ...', 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Host: ${_room!.hostName}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              if (_isHost)
                IconButton(
                  onPressed: _showAddSongs,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: _mintGreen, size: 28),
                ),
            ],
          ),
          if (_isHost) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: _previousSong, icon: const Icon(Icons.skip_previous_rounded, size: 32)),
                const SizedBox(width: 15),
                Container(
                  decoration: const BoxDecoration(color: _mintGreen, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: _togglePlayback, 
                    icon: Icon(_room!.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32)
                  ),
                ),
                const SizedBox(width: 15),
                IconButton(onPressed: _stopPlayback, icon: const Icon(Icons.stop_rounded, size: 32, color: Colors.redAccent)),
                const SizedBox(width: 15),
                IconButton(onPressed: _nextSong, icon: const Icon(Icons.skip_next_rounded, size: 32)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rooms')
                .doc(widget.roomId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              final messages = snapshot.data?.docs ?? [];
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final isMe = data['senderId'] == context.read<UserProvider>().userId;
                  return _buildChatItem(data, isMe);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildChatItem(Map<String, dynamic> data, bool isMe) {
    final photoUrl = data['senderPhotoUrl'] as String?;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(data['senderName'] ?? 'User', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isMe ? _mintGreen : Colors.grey)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? _mintGreen : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Text(data['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : _darkText)),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _mintGreen.withValues(alpha: 0.2),
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 20, color: _mintGreen) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Nhắn gì đó vui vẻ...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F0),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _mintGreen,
              child: IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistSection() {
    return Container(
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.white,
            child: const Text('DANH SÁCH CHỜ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
          ),
          Expanded(
            child: _playlistSongs.isEmpty
                ? const Center(child: Text('Trống', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _playlistSongs.length,
                    itemBuilder: (context, index) {
                      final song = _playlistSongs[index];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(song.coverUrl ?? '', width: 40, height: 40, fit: BoxFit.cover, 
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note)),
                        ),
                        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(song.artist, style: const TextStyle(fontSize: 12)),
                        trailing: _isHost ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => RoomService.removeFromPlaylist(widget.roomId, song.id),
                        ) : null,
                        onTap: _isHost ? () {
                          context.read<AudioProvider>().playSong(song);
                          RoomService.updatePlayback(roomId: widget.roomId, songId: song.id, positionMs: 0, isPlaying: true);
                        } : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TabBar(
            labelColor: _mintGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _mintGreen,
            tabs: [Tab(text: 'TRÒ CHUYỆN'), Tab(text: 'PLAYLIST')],
          ),
          Flexible( // Thay đổi từ SizedBox cố định sang Flexible để tránh Overflow
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: TabBarView(
                children: [
                  _buildChatSection(),
                  _buildPlaylistSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSongs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddSongRoomSheet(),
    ).then((selectedIds) {
      if (selectedIds != null && selectedIds is List<String> && selectedIds.isNotEmpty) {
        RoomService.addToPlaylist(widget.roomId, selectedIds);
      }
    });
  }

  void _leaveRoom() async {
    final userId = context.read<UserProvider>().userId;
    final audio = context.read<AudioProvider>();
    
    await audio.stop();

    if (mounted) {
      await RoomService.leaveRoom(widget.roomId, userId!);
      if (mounted) {
        // Trở về màn hình Home (Xóa sạch stack để tránh quay lại phòng)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}
