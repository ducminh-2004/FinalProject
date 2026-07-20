import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/genre.dart';
import '../models/playlist.dart';
import '../providers/audio_provider.dart';
import '../providers/user_provider.dart';
import '../firebase/firestore_service.dart';
import 'now_playing_screen.dart';

class GenrePlaylistScreen extends StatefulWidget {
  final Genre genre;

  const GenrePlaylistScreen({super.key, required this.genre});

  @override
  State<GenrePlaylistScreen> createState() => _GenrePlaylistScreenState();
}

class _GenrePlaylistScreenState extends State<GenrePlaylistScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;

  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    
    try {
      final songs = await FirestoreService.getSongsByGenre(widget.genre.id);
      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading songs: $e');
      if (mounted) {
        setState(() {
          _songs = [];
          _isLoading = false;
        });
      }
    }
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

  void _addToPlaylist(String songId) async {
    // Show bottom sheet to select playlist
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddToPlaylistSheet(songId: songId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final genreColor = Color(widget.genre.colorValue);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: genreColor,
            surfaceTintColor: genreColor,
            pinned: true,
            expandedHeight: 180,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: genreColor,
                  image: widget.genre.imageUrl != null && widget.genre.imageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(widget.genre.imageUrl!),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.3),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text(
                        widget.genre.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 10,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stats and actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: genreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.genre.name,
                      style: TextStyle(
                        color: genreColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_songs.length} bài hát',
                    style: TextStyle(
                      color: _darkText.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Play buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _songs.isEmpty ? null : _playAll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: genreColor,
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
                      color: genreColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _songs.isEmpty ? null : _shufflePlay,
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: genreColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

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
                      color: genreColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Không có bài hát nào',
                      style: TextStyle(
                        color: _darkText.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thử chọn thể loại khác',
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
                  return _GenreSongTile(
                    song: song,
                    genreColor: genreColor,
                    onTap: () => _playSong(index),
                    onAddToPlaylist: () => _addToPlaylist(song.id),
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

class _GenreSongTile extends StatelessWidget {
  final Song song;
  final Color genreColor;
  final VoidCallback onTap;
  final VoidCallback onAddToPlaylist;

  const _GenreSongTile({
    required this.song,
    required this.genreColor,
    required this.onTap,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isLiked = userProvider.isSongLiked(song.id);

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
                color: genreColor.withValues(alpha: 0.1),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note_rounded,
                          color: genreColor.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: genreColor.withValues(alpha: 0.7),
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

            // Like button
            IconButton(
              onPressed: () => userProvider.toggleLike(song.id),
              icon: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? const Color(0xFF8D67AB) : const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToPlaylistSheet extends StatefulWidget {
  final String songId;

  const _AddToPlaylistSheet({required this.songId});

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final playlists = await FirestoreService.getUserPlaylists(userProvider.userId!);
      setState(() {
        _playlists = playlists;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF0A1F1A).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Thêm vào playlist',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1F1A),
            ),
          ),
          const SizedBox(height: 16),
          
          // Create new playlist option
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0E6B5A).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF0E6B5A),
              ),
            ),
            title: const Text('Tạo playlist mới'),
            subtitle: const Text('Thêm bài hát này vào playlist mới'),
            onTap: () {
              Navigator.pop(context);
              _showCreatePlaylistDialog(context, widget.songId);
            },
          ),
          
          const Divider(),
          const SizedBox(height: 8),
          
          // Existing playlists
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF0E6B5A)),
              ),
            )
          else if (_playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Chưa có playlist nào')),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E6B5A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: Color(0xFF0E6B5A),
                      ),
                    ),
                    title: Text(playlist.title),
                    subtitle: Text('${playlist.songIds.length} bài hát'),
                    onTap: () async {
                      await FirestoreService.addSongToPlaylist(playlist.id, widget.songId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm vào ${playlist.title}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, String songId) {
    final controller = TextEditingController();
    final userProvider = context.read<UserProvider>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              if (userProvider.userId != null) {
                final title = controller.text.trim();
                await FirestoreService.createPlaylist(
                  userId: userProvider.userId!,
                  title: title,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã tạo playlist "$title"'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E6B5A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }
}
