import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';
import 'now_playing_screen.dart';

class UserPlaylistsScreen extends StatefulWidget {
  const UserPlaylistsScreen({super.key});

  @override
  State<UserPlaylistsScreen> createState() => _UserPlaylistsScreenState();
}

class _UserPlaylistsScreenState extends State<UserPlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final userProvider = context.read<UserProvider>();
    
    setState(() => _isLoading = true);
    
    try {
      if (userProvider.userId != null) {
        final playlists = await FirestoreService.getUserPlaylists(userProvider.userId!);
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      } else {
        setState(() {
          _playlists = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      setState(() {
        _playlists = [];
        _isLoading = false;
      });
    }
  }

  void _showCreatePlaylistDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tạo playlist mới'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tên playlist',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              final userProvider = context.read<UserProvider>();
              if (userProvider.userId != null) {
                await FirestoreService.createPlaylist(
                  userId: userProvider.userId!,
                  title: controller.text.trim(),
                );
                await _loadPlaylists();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã tạo playlist "${controller.text.trim()}"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        surfaceTintColor: const Color(0xFFF7F9F8),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
        ),
        title: const Text(
          'Playlist của bạn',
          style: TextStyle(
            color: _darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showCreatePlaylistDialog,
            icon: const Icon(Icons.add_rounded, color: _darkText),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? _buildEmptyState()
              : _buildPlaylistList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePlaylistDialog,
        backgroundColor: _mintGreen,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 80,
            color: _darkText.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có playlist nào',
            style: TextStyle(
              color: _darkText.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo playlist đầu tiên của bạn',
            style: TextStyle(
              color: _darkText.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePlaylistDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tạo playlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return _PlaylistTile(
          playlist: playlist,
          onTap: () => _openPlaylist(playlist),
          onEdit: () => _showEditPlaylistDialog(playlist),
          onDelete: () => _showDeleteConfirmation(playlist),
        );
      },
    );
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  void _showEditPlaylistDialog(Playlist playlist) {
    final controller = TextEditingController(text: playlist.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sửa playlist'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tên playlist',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              await FirestoreService.updatePlaylistTitle(
                playlist.id,
                controller.text.trim(),
              );
              await _loadPlaylists();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã đổi tên thành "${controller.text.trim()}"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa playlist'),
        content: Text('Bạn có chắc muốn xóa playlist "${playlist.title}" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirestoreService.deletePlaylist(playlist.id);
              await _loadPlaylists();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa "${playlist.title}"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE13300),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Playlist cover
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0E6B5A),
                      const Color(0xFF0E6B5A).withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.queue_music_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              
              // Playlist info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0A1F1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.songIds.length} bài hát',
                      style: TextStyle(
                        color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Color(0xFFE13300)),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Color(0xFFE13300))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  List<Song> _songs = [];
  bool _isLoading = true;

  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    
    final songs = await FirestoreService.getSongsFromPlaylist(_playlist.id);
    
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    final audioProvider = context.read<AudioProvider>();
    audioProvider.playPlaylist(_songs);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(initialSong: _songs.first),
      ),
    );
  }

  void _shufflePlay() {
    if (_songs.isEmpty) return;
    final shuffled = List<Song>.from(_songs)..shuffle();
    final audioProvider = context.read<AudioProvider>();
    audioProvider.playPlaylist(shuffled);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(initialSong: shuffled.first),
      ),
    );
  }

  void _playSong(int index) {
    final audioProvider = context.read<AudioProvider>();
    audioProvider.playPlaylist(_songs, startIndex: index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(initialSong: _songs[index]),
      ),
    );
  }

  void _removeSong(String songId) async {
    await FirestoreService.removeSongFromPlaylist(_playlist.id, songId);
    await _loadSongs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa khỏi playlist'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: const Color(0xFFF7F9F8),
            surfaceTintColor: const Color(0xFFF7F9F8),
            pinned: true,
            expandedHeight: 200,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0E6B5A),
                      const Color(0xFF0E6B5A).withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.queue_music_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _playlist.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_songs.length} bài hát',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Play buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _songs.isEmpty ? null : _playAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mintGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: const Text(
                        'Phát',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _mintGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _songs.isEmpty ? null : _shufflePlay,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: _mintGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Song list
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.music_off_rounded,
                      size: 80,
                      color: _darkText.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Playlist trống',
                      style: TextStyle(
                        color: _darkText.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thêm bài hát từ trang tìm kiếm',
                      style: TextStyle(
                        color: _darkText.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = _songs[index];
                  return _PlaylistSongTile(
                    song: song,
                    onTap: () => _playSong(index),
                    onRemove: () => _removeSong(song.id),
                  );
                },
                childCount: _songs.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _PlaylistSongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistSongTile({
    required this.song,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Cover
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF0E6B5A).withValues(alpha: 0.1),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note_rounded,
                          color: const Color(0xFF0E6B5A).withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: const Color(0xFF0E6B5A).withValues(alpha: 0.7),
                    ),
            ),
            const SizedBox(width: 12),

            // Title and artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A1F1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Remove button
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.remove_circle_outline_rounded,
                color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
