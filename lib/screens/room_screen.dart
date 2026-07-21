import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/user_provider.dart';
import '../models/song.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../firebase/firestore_service.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    roomProvider.sendMessage(
      _messageController.text.trim(),
      userProvider.userId!,
      userProvider.displayName ?? 'User',
      userProvider.photoUrl,
    );
    _messageController.clear();
  }

  void _showQueue() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QueueSheet(),
    );
  }

  void _showAddMusic() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMusicSheet(),
    );
  }

  void _showParticipants() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ParticipantsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final audioProvider = Provider.of<AudioProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    
    if (roomProvider.currentRoom == null) {
      return Scaffold(
        backgroundColor: context.bg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.mint)),
      );
    }

    final room = roomProvider.currentRoom!;
    final currentSong = audioProvider.currentSong;

    // Check if sync is needed (for browser auto-play issues)
    bool needsManualSync = !roomProvider.isHost && 
                          room.isPlaying && 
                          !audioProvider.isPlaying && 
                          currentSong != null;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32), onPressed: () => Navigator.pop(context)),
        title: Column(
          children: [
            Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Key: ${room.roomKey}', style: TextStyle(fontSize: 11, color: context.textSecondary, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.people_outline_rounded), onPressed: _showParticipants),
          IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), onPressed: () {
             roomProvider.leaveRoom();
             Navigator.pop(context);
          }),
        ],
      ),
      body: Column(
        children: [
          // Player Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: context.surface2,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: currentSong?.coverUrl != null && currentSong!.coverUrl!.isNotEmpty
                          ? Image.network(currentSong.coverUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.music_note, size: 60))
                          : const Icon(Icons.music_note, size: 60, color: Colors.grey),
                      ),
                    ),
                    if (needsManualSync)
                      GestureDetector(
                        onTap: () => audioProvider.play(),
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sync, color: Colors.white, size: 40),
                              SizedBox(height: 8),
                              Text('Chạm để đồng bộ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(currentSong?.title ?? 'Đang chờ...', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(currentSong?.artist ?? '---', style: TextStyle(fontSize: 14, color: context.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                // Progress
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: AppColors.mint,
                    thumbColor: AppColors.mint,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: audioProvider.position.inMilliseconds.toDouble().clamp(0, audioProvider.duration.inMilliseconds.toDouble()),
                    max: audioProvider.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: roomProvider.isHost ? (val) => roomProvider.seek(val.toInt()) : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(audioProvider.position), style: TextStyle(fontSize: 10, color: context.textSecondary)),
                      Text(_formatDuration(audioProvider.duration), style: TextStyle(fontSize: 10, color: context.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildMembersRow(context, roomProvider),
              ],
            ),
          ),
          
          // Chat Section - Expanded
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _buildChat(context, roomProvider, userProvider),
            ),
          ),
          
          _buildBottomControls(context, roomProvider, audioProvider),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildMembersRow(BuildContext context, RoomProvider roomProvider) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: roomProvider.members.length,
        itemBuilder: (context, index) {
          final m = roomProvider.members[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: context.divider,
              backgroundImage: (m.photoUrl != null && m.photoUrl!.isNotEmpty) ? NetworkImage(m.photoUrl!) : null,
              child: (m.photoUrl == null || m.photoUrl!.isEmpty) ? const Icon(Icons.person, size: 14) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildChat(BuildContext context, RoomProvider roomProvider, UserProvider userProvider) {
    final messages = roomProvider.messages;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(12),
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg.senderId == userProvider.userId;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe) 
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(msg.senderName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.textSecondary)),
                      ),
                    Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 12, 
                              backgroundImage: (msg.senderPhotoUrl != null && msg.senderPhotoUrl!.isNotEmpty) ? NetworkImage(msg.senderPhotoUrl!) : null,
                              child: (msg.senderPhotoUrl == null || msg.senderPhotoUrl!.isEmpty) ? const Icon(Icons.person, size: 10) : null,
                            ),
                          ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.mint : context.surface,
                              borderRadius: BorderRadius.circular(18).copyWith(
                                bottomLeft: isMe ? null : Radius.zero,
                                bottomRight: isMe ? Radius.zero : null,
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
                            ),
                            child: Text(msg.text, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : context.textPrimary)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Nhắn gì đó...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    fillColor: context.surface,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), onPressed: _sendMessage),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(BuildContext context, RoomProvider roomProvider, AudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.playlist_play_rounded, size: 28), onPressed: _showQueue),
          if (roomProvider.isHost) ...[
            IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 40), onPressed: roomProvider.skipPrevious),
            GestureDetector(
              onTap: roomProvider.togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
                child: Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
            ),
            IconButton(icon: const Icon(Icons.skip_next_rounded, size: 40), onPressed: roomProvider.playNextInQueue),
          ] else
            const Text('Đang nghe đồng bộ 🎧', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.mint)),
          IconButton(icon: const Icon(Icons.add_box_outlined, size: 28), onPressed: roomProvider.isHost ? _showAddMusic : null),
        ],
      ),
    );
  }
}

class _ParticipantsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final isHost = roomProvider.isHost;

    return Container(
      decoration: BoxDecoration(color: context.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text('Người tham gia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: roomProvider.members.length,
              itemBuilder: (context, index) {
                final m = roomProvider.members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (m.photoUrl != null && m.photoUrl!.isNotEmpty) ? NetworkImage(m.photoUrl!) : null,
                    child: (m.photoUrl == null || m.photoUrl!.isEmpty) ? const Icon(Icons.person) : null,
                  ),
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(m.isHost ? 'Host' : (m.isPremium ? 'Premium' : 'Member')),
                  trailing: (isHost && m.id != userProvider.userId) 
                    ? PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'kick') roomProvider.kickMember(m.id);
                          if (val == 'host') roomProvider.transferHost(m.id);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'host', child: Text('Chuyển quyền Host')),
                          const PopupMenuItem(value: 'kick', child: Text('Kích khỏi phòng', style: TextStyle(color: Colors.redAccent))),
                        ],
                      )
                    : null,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final room = Provider.of<RoomProvider>(context);
    final audio = Provider.of<AudioProvider>(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: context.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Hàng đợi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (room.isHost)
                  TextButton(onPressed: room.clearQueue, child: const Text('Xóa hết', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ),
          Expanded(
            child: room.queue.isEmpty 
              ? const Center(child: Text('Hàng đợi trống'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: room.queue.length,
                  onReorder: room.reorderQueue,
                  itemBuilder: (context, index) {
                    final song = room.queue[index];
                    final isCurrent = audio.currentSong?.id == song.id;
                    return ListTile(
                      key: ValueKey(song.id + index.toString()),
                      onTap: room.isHost ? () => room.playSongAt(index) : null,
                      leading: Stack(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(song.coverUrl ?? '', width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.music_note))),
                          if (isCurrent)
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.equalizer, color: Colors.white, size: 24),
                            ),
                          if (room.isHost && !isCurrent)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                              ),
                            ),
                        ],
                      ),
                      title: Text(song.title, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600, color: isCurrent ? AppColors.mint : null)),
                      subtitle: Text(song.artist),
                      trailing: room.isHost ? IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => room.removeFromQueue(index)) : const Icon(Icons.drag_handle),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _AddMusicSheet extends StatefulWidget {
  @override
  State<_AddMusicSheet> createState() => _AddMusicSheetState();
}

class _AddMusicSheetState extends State<_AddMusicSheet> {
  List<Song> _songs = [];
  bool _isLoading = false;

  void _search(String q) async {
    setState(() => _isLoading = true);
    final results = q.isEmpty ? await FirestoreService.getSongs(limit: 20) : await FirestoreService.searchSongs(q);
    setState(() { _songs = results; _isLoading = false; });
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    final room = Provider.of<RoomProvider>(context, listen: false);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: context.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Thêm vào Queue...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: context.surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.mint))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _songs.length,
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return ListTile(
                      leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(song.coverUrl ?? '', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.music_note))),
                      title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(song.artist),
                      trailing: IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.mint), onPressed: () {
                        room.addToQueue(song);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${song.title}'), duration: const Duration(seconds: 1)));
                      }),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
