import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';
import 'now_playing_screen.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  State<LikedSongsScreen> createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;

  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
  }

  Future<void> _loadLikedSongs() async {
    final userProvider = context.read<UserProvider>();
    final songs = await userProvider.getLikedSongs();
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike(String songId) async {
    final userProvider = context.read<UserProvider>();
    await userProvider.toggleLike(songId);
    await _loadLikedSongs();
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
            expandedHeight: 120,
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
                      const Color(0xFF0E6B5A).withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
              title: const Text(
                'Bài hát đã thích',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),
          
          // Stats and actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Heart icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _mintGreen,
                          _mintGreen.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _mintGreen.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_songs.length} bài hát',
                          style: const TextStyle(
                            color: _darkText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                      Icons.favorite_border_rounded,
                      size: 80,
                      color: _darkText.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có bài hát nào được thích',
                      style: TextStyle(
                        color: _darkText.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thả tim bài hát bạn yêu thích',
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
                  return _SongTile(
                    song: song,
                    onTap: () => _playSong(index),
                    onLikeTap: () => _toggleLike(song.id),
                    isLiked: true,
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

  String _formatTotalDuration() {
    if (_songs.isEmpty) return '';
    int totalMs = 0;
    for (final song in _songs) {
      totalMs += song.durationMs ?? 0;
    }
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    if (hours > 0) {
      return '~${hours}g ${minutes}p';
    }
    return '~${minutes} phút';
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final VoidCallback onLikeTap;
  final bool isLiked;

  const _SongTile({
    required this.song,
    required this.onTap,
    required this.onLikeTap,
    required this.isLiked,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final actuallyLiked = userProvider.isSongLiked(song.id);

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
            
            // Like button
            IconButton(
              onPressed: onLikeTap,
              icon: Icon(
                actuallyLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: actuallyLiked ? const Color(0xFF0E6B5A) : const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
