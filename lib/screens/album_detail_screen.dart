import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/album.dart';
import '../models/song.dart';
import '../providers/audio_provider.dart';
import '../providers/user_provider.dart';
import '../extensions/view_extensions.dart';
import '../widgets/song_options_bottom_sheet.dart';
import 'now_playing_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final Album album;

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  late List<Song> _songs;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    _songs = List<Song>.from(widget.album.songs);
    // Track album view
    widget.album.id.trackAlbumView();
  }

  void _playAlbum({bool shuffle = false}) {
    final audioProvider = context.read<AudioProvider>();
    final userProvider = context.read<UserProvider>();
    if (shuffle) {
      audioProvider.toggleShuffle();
    }
    audioProvider.playPlaylist(_songs, userId: userProvider.userId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NowPlayingScreen(initialSong: _songs.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final darkText = const Color(0xFF0A1F1A);
    final secondaryText = darkText.withValues(alpha: 0.55);
    final mintGreen = const Color(0xFF0E6B5A);
    final coverUrl = widget.album.coverUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, coverUrl, mintGreen),
          ),
          SliverToBoxAdapter(
            child: _buildActions(mintGreen),
          ),
          _buildSectionDivider(),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = _songs[index];
                return _SongTile(
                  index: index + 1,
                  song: song,
                  secondaryText: secondaryText,
                  onTap: () {
                    final audioProvider = context.read<AudioProvider>();
                    final userProvider = context.read<UserProvider>();
                    audioProvider.playPlaylist(
                      _songs, 
                      startIndex: index, 
                      userId: userProvider.userId,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NowPlayingScreen(initialSong: song),
                      ),
                    );
                  },
                );
              },
              childCount: _songs.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    final distinctArtists = _songs.map((s) => s.artist).toSet().toList();
    if (distinctArtists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Text(
          distinctArtists.length == 1
              ? '${distinctArtists.first} · ${widget.album.title}'
              : '${widget.album.title} · Playlist',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? coverUrl, Color mintGreen) {
    final textColor = Colors.white;
    final titleText = widget.album.title;
    final subtitleText = widget.album.artist;
    final countText = '${_songs.length} bài hát';
    final typeLabel = _detectTypeLabel();
    final userProvider = context.watch<UserProvider>();
    final isLiked = userProvider.isAlbumLiked(widget.album.id);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.of(context).padding.top + 8,
        12,
        20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mintGreen,
            const Color(0xFF0A1F1A),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tải nhạc sắp có!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.download_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tùy chọn sắp có!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFFDDEBE4),
                ),
                child: coverUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          width: 130,
                          height: 130,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.album_rounded,
                            color: Colors.white70,
                            size: 56,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.album_rounded,
                        color: Colors.white70,
                        size: 56,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          countText,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusLabel(
                          label: isLiked ? 'Đã thích' : 'Yêu thích',
                          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        ),
                        const SizedBox(width: 8),
                        _StatusLabel(
                          label: _isDownloaded ? 'Đã tải' : 'Tải xuống',
                          icon: _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thêm vào playlist sắp có!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('Thêm vào danh sách phát này'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Color mintGreen) {
    final userProvider = context.watch<UserProvider>();
    final isLiked = userProvider.isAlbumLiked(widget.album.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _playAlbum(),
              style: ElevatedButton.styleFrom(
                backgroundColor: mintGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text(
                'Play',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () => _playAlbum(shuffle: true),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2F4F1),
              foregroundColor: const Color(0xFF0A1F1A),
            ),
            icon: const Icon(Icons.shuffle_rounded),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () {
              userProvider.toggleLikeAlbum(widget.album.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(!isLiked ? 'Đã thích album!' : 'Đã bỏ thích album!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2F4F1),
              foregroundColor: const Color(0xFF0A1F1A),
            ),
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? const Color(0xFF0E6B5A) : const Color(0xFF0A1F1A),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tùy chọn sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF2F4F1),
              foregroundColor: const Color(0xFF0A1F1A),
            ),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
    );
  }

  String _detectTypeLabel() {
    if (widget.album.title.toLowerCase().contains('ep')) return 'EP';
    if (widget.album.title.toLowerCase().contains('album')) return 'Album';
    final hasSingleSong = _songs.length == 1;
    final hasMultipleArtists = _songs.map((s) => s.artist).toSet().length > 1;
    if (hasSingleSong) return 'Single';
    if (hasMultipleArtists) return 'Compilation';
    return 'Album';
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.index,
    required this.song,
    required this.secondaryText,
    required this.onTap,
  });

  final int index;
  final Song song;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFDDEBE4),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        song.coverUrl!,
                        fit: BoxFit.cover,
                        width: 42,
                        height: 42,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.music_note_rounded,
                          color: mintGreen.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: mintGreen.withValues(alpha: 0.7),
                      size: 18,
                    ),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                _showSongOptions(context);
              },
              icon: Icon(Icons.more_vert_rounded, color: secondaryText, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _showSongOptions(BuildContext context) {
    SongOptionsBottomSheet.show(context, song);
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
