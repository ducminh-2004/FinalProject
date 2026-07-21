import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/room_provider.dart';
import '../providers/user_provider.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../firebase/firestore_service.dart';
import '../theme/app_theme.dart';
import 'room_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  String _searchQuery = '';

  void _showCreateRoomDialog() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final tier = userProvider.subscriptionTier;
    
    if (tier != 'Premium' && tier != 'Pro') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yêu cầu Premium'),
          content: const Text('Chỉ người dùng Premium hoặc Pro mới được tạo phòng nghe nhạc.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    bool isPublic = true;
    List<Song> selectedSongs = [];
    int step = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: context.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.divider, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text(step == 1 ? 'Tạo phòng nghe nhạc' : 'Thêm nhạc vào hàng đợi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(step == 1 ? 'Chia sẻ không gian âm nhạc của bạn' : 'Chọn bài hát để bắt đầu buổi nghe nhạc', style: TextStyle(color: context.textSecondary)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: step == 1 
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: 'Tên phòng',
                                  hintText: 'VD: Rock & Chill...',
                                  filled: true,
                                  fillColor: context.surface2,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  prefixIcon: const Icon(Icons.music_note_rounded, color: AppColors.mint),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(16)),
                                child: SwitchListTile(
                                  title: const Text('Phòng công khai', style: TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: const Text('Mọi người có thể tìm thấy trong danh sách'),
                                  value: isPublic,
                                  activeColor: AppColors.mint,
                                  onChanged: (val) => setDialogState(() => isPublic = val),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _EnhancedMusicPicker(
                          selectedSongs: selectedSongs,
                          onSelectionChanged: (songs) => setDialogState(() => selectedSongs = songs),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (step == 2)
                        Expanded(
                          child: TextButton(onPressed: () => setDialogState(() => step = 1), child: Text('Quay lại', style: TextStyle(color: context.textSecondary))),
                        ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () async {
                            if (step == 1) {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên phòng')));
                                return;
                              }
                              setDialogState(() => step = 2);
                            } else {
                              if (selectedSongs.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chọn ít nhất 1 bài hát')));
                                return;
                              }
                              final roomProvider = Provider.of<RoomProvider>(context, listen: false);
                              try {
                                await roomProvider.createRoom(
                                  name: nameController.text.trim(),
                                  isPublic: isPublic,
                                  hostId: userProvider.userId!,
                                  hostName: userProvider.displayName ?? 'User',
                                  hostPhotoUrl: userProvider.photoUrl,
                                  isPremium: userProvider.subscriptionTier != 'Free',
                                  initialQueue: selectedSongs,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                              }
                            }
                          },
                          child: Text(step == 1 ? 'Tiếp tục' : 'Tạo phòng (${selectedSongs.length} bài)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinByKeyDialog() {
    final keyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tham gia bằng mã', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: keyController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Mã phòng (Key)',
            hintText: 'Nhập mã 6 ký tự...',
            filled: true,
            fillColor: context.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: context.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white),
            onPressed: () async {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              final roomProvider = Provider.of<RoomProvider>(context, listen: false);
              try {
                await roomProvider.joinRoomByKey(keyController.text.trim(), userProvider.userId!, userProvider.displayName ?? 'User', userProvider.photoUrl, userProvider.subscriptionTier != 'Free');
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy phòng')));
              }
            },
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        title: const Text('Listening Party', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.vpn_key_outlined), onPressed: _showJoinByKeyDialog),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm phòng hoặc Host...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: context.surface2,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.watchPublicRooms(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.mint));
                final rooms = snapshot.data!.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).where((r) {
                  final q = _searchQuery.toLowerCase();
                  return r['name'].toString().toLowerCase().contains(q) || r['hostName'].toString().toLowerCase().contains(q);
                }).toList();
                
                if (rooms.isEmpty) return Center(child: Text('Không có phòng nào phù hợp', style: TextStyle(color: context.textSecondary)));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: ListTile(
                        leading: CircleAvatar(backgroundImage: room['hostPhotoUrl'] != null ? NetworkImage(room['hostPhotoUrl']) : null, child: room['hostPhotoUrl'] == null ? const Icon(Icons.person) : null),
                        title: Text(room['name'] ?? 'Room', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Host: ${room['hostName']} • ${room['listenerCount']} listening'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            final userProvider = Provider.of<UserProvider>(context, listen: false);
                            final roomProvider = Provider.of<RoomProvider>(context, listen: false);
                            await roomProvider.joinRoomById(room['id'], userProvider.userId!, userProvider.displayName ?? 'User', userProvider.photoUrl, userProvider.subscriptionTier != 'Free');
                            if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomScreen()));
                          },
                          child: const Text('Vào'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCreateRoomDialog, label: const Text('Tạo phòng'), icon: const Icon(Icons.add)),
    );
  }
}

class _EnhancedMusicPicker extends StatefulWidget {
  final List<Song> selectedSongs;
  final Function(List<Song>) onSelectionChanged;
  const _EnhancedMusicPicker({required this.selectedSongs, required this.onSelectionChanged});
  @override
  State<_EnhancedMusicPicker> createState() => _EnhancedMusicPickerState();
}

class _EnhancedMusicPickerState extends State<_EnhancedMusicPicker> {
  List<Song> _songs = [];
  List<Album> _albums = [];
  bool _isLoading = false;
  Album? _viewingAlbum;
  List<Song> _albumSongs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([FirestoreService.getSongs(limit: 20), FirestoreService.getAlbums(limit: 10)]);
    setState(() { _songs = results[0] as List<Song>; _albums = results[1] as List<Album>; _isLoading = false; });
  }

  void _search(String q) async {
    if (q.isEmpty) { _load(); return; }
    setState(() => _isLoading = true);
    final results = await FirestoreService.searchSongs(q);
    setState(() { _songs = results; _isLoading = false; });
  }

  void _toggle(Song song) {
    final list = List<Song>.from(widget.selectedSongs);
    if (list.any((s) => s.id == song.id)) list.removeWhere((s) => s.id == song.id);
    else list.add(song);
    widget.onSelectionChanged(list);
  }

  void _viewAlbum(Album album) async {
    setState(() { _viewingAlbum = album; _isLoading = true; });
    final full = await FirestoreService.getAlbumById(album.id);
    setState(() { _albumSongs = full?.songs ?? []; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_viewingAlbum != null) {
      return Column(
        children: [
          Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _viewingAlbum = null)), Expanded(child: Text(_viewingAlbum!.title, style: const TextStyle(fontWeight: FontWeight.bold))), TextButton(onPressed: () {
            final list = List<Song>.from(widget.selectedSongs);
            for (var s in _albumSongs) { if (!list.any((e) => e.id == s.id)) list.add(s); }
            widget.onSelectionChanged(list);
          }, child: const Text('Chọn hết'))]),
          Expanded(child: ListView.builder(itemCount: _albumSongs.length, itemBuilder: (context, i) {
            final s = _albumSongs[i];
            final sel = widget.selectedSongs.any((e) => e.id == s.id);
            return ListTile(leading: Image.network(s.coverUrl ?? '', width: 40, height: 40), title: Text(s.title), trailing: Checkbox(value: sel, onChanged: (_) => _toggle(s)), onTap: () => _toggle(s));
          })),
        ],
      );
    }

    return Column(
      children: [
        TextField(onChanged: _search, decoration: InputDecoration(hintText: 'Tìm bài hát, album...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: context.surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              if (_albums.isNotEmpty) ...[
                const Text('Albums', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _albums.length, itemBuilder: (context, i) {
                  final a = _albums[i];
                  return GestureDetector(onTap: () => _viewAlbum(a), child: Container(width: 100, margin: const EdgeInsets.only(right: 12), child: Column(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(a.coverUrl ?? '', width: 80, height: 80, fit: BoxFit.cover)), Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))])));
                })),
                const SizedBox(height: 16),
              ],
              const Text('Bài hát', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._songs.map((s) {
                final sel = widget.selectedSongs.any((e) => e.id == s.id);
                return ListTile(leading: Image.network(s.coverUrl ?? '', width: 40, height: 40), title: Text(s.title), subtitle: Text(s.artist), trailing: Checkbox(value: sel, onChanged: (_) => _toggle(s)), onTap: () => _toggle(s));
              }),
            ],
          ),
        ),
      ],
    );
  }
}
