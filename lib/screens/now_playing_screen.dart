import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/audio_provider.dart';
import '../providers/user_provider.dart';
import '../models/song.dart';
import '../firebase/firestore_service.dart';
import 'user_playlists_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key, this.initialSong});

  final Song? initialSong;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Play initial song if provided and no song is currently playing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = context.read<AudioProvider>();
      if (widget.initialSong != null && !audioProvider.hasSong) {
        audioProvider.playSong(widget.initialSong!);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);
    final secondaryText = darkText.withOpacity(0.6);

    return Consumer<AudioProvider>(
      builder: (context, audio, child) {
        final currentSong = audio.currentSong ?? widget.initialSong ?? demoCurrentSong;

        // Control animation based on playing state
        if (audio.isPlaying) {
          if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        } else {
          if (_pulseController.isAnimating) _pulseController.stop();
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F9F8),
            body: SafeArea(
              child: Column(
                children: [
                  _buildAppBar(darkText, currentSong),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildAlbumArt(currentSong, mintGreen),
                          const SizedBox(height: 32),
                          _buildSongInfo(currentSong, darkText, secondaryText, audio),
                          const SizedBox(height: 28),
                          _buildProgressBar(audio),
                          const SizedBox(height: 28),
                          _buildControls(mintGreen, darkText, secondaryText, audio),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(Color darkText, Song currentSong) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28, color: darkText.withOpacity(0.75)),
          ),
          Column(
            children: [
              Text(
                'Now Playing',
                style: TextStyle(
                  color: darkText.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'From playlist',
                style: TextStyle(
                  color: darkText.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showSongOptions(context, currentSong),
            icon: Icon(Icons.more_horiz_rounded, color: darkText.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext pageContext, Song song) {
    final userProvider = pageContext.read<UserProvider>();

    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Thêm vào danh sách phát'),
              onTap: () {
                Navigator.pop(sheetContext);
                if (!userProvider.isLoggedIn) {
                  ScaffoldMessenger.of(pageContext).showSnackBar(
                    const SnackBar(content: Text('Vui lòng đăng nhập để thực hiện')),
                  );
                  return;
                }
                _showPlaylistPicker(pageContext, song.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Chia sẻ bài hát'),
              onTap: () {
                Navigator.pop(sheetContext);
                final text = 'Đang nghe "${song.title}" của ${song.artist} trên Music App!';
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép liên kết chia sẻ!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Xem thông tin bài hát'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showSongInfo(pageContext, song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistPicker(BuildContext pageContext, String songId) {
    final userProvider = pageContext.read<UserProvider>();
    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FutureBuilder(
        future: FirestoreService.getUserPlaylists(userProvider.userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }
          final playlists = snapshot.data ?? [];
          if (playlists.isEmpty) {
            return const SizedBox(height: 100, child: Center(child: Text('Bạn chưa có danh sách phát nào')));
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chọn danh sách phát', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play_rounded),
                      title: Text(playlist.title),
                      onTap: () async {
                        try {
                          await FirestoreService.addSongToPlaylist(playlist.id, songId);
                          if (context.mounted) {
                            Navigator.pop(sheetContext);
                            // Xóa SnackBar cũ nếu đang hiển thị
                            ScaffoldMessenger.of(pageContext).removeCurrentSnackBar();

                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              SnackBar(
                                content: const Text('Đã thêm vào danh sách phát'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(milliseconds: 2500),
                                backgroundColor: const Color(0xFF323232),
                                action: SnackBarAction(
                                  label: 'XEM NGAY',
                                  textColor: Colors.white, // Đổi sang màu trắng cho nổi bật
                                  onPressed: () {
                                    Navigator.push(
                                      pageContext,
                                      MaterialPageRoute(
                                        builder: (_) => PlaylistDetailScreen(playlist: playlist),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (pageContext.mounted) {
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(
                                content: Text('Lỗi khi thêm vào danh sách phát'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông tin bài hát'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tiêu đề: ${song.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Nghệ sĩ: ${song.artist}'),
            if (song.genres.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Thể loại: ${song.genres.join(', ')}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song, Color mintGreen) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        height: 320,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: mintGreen.withOpacity(0.22),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: song.coverUrl != null
              ? Image.network(
                  song.coverUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFDDEBE4),
                    alignment: Alignment.center,
                    child: Icon(Icons.music_note_rounded, color: mintGreen.withOpacity(0.7), size: 80),
                  ),
                )
              : Container(
                  color: const Color(0xFFDDEBE4),
                  alignment: Alignment.center,
                  child: Icon(Icons.music_note_rounded, color: mintGreen.withOpacity(0.7), size: 80),
                ),
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song song, Color darkText, Color secondaryText, AudioProvider audio) {
    final userProvider = context.watch<UserProvider>();
    final isLiked = userProvider.isSongLiked(song.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (song.genres.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: song.genres.take(2).map((g) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E6B5A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      g,
                      style: TextStyle(
                        color: const Color(0xFF0E6B5A),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        _LikeButton(
          isLiked: isLiked,
          onTap: () {
            if (!userProvider.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vui lòng đăng nhập để thích bài hát')),
              );
              return;
            }
            userProvider.toggleLike(song.id);
          },
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioProvider audio) {
    final totalDuration = audio.duration.inMilliseconds > 0
        ? audio.duration
        : Duration(milliseconds: audio.currentSong?.durationMs ?? 0);

    final totalSeconds = totalDuration.inSeconds.toDouble();
    final positionSeconds = _isDragging ? _dragValue : audio.position.inSeconds.toDouble();
    final position = positionSeconds.clamp(0.0, totalSeconds);
    final value = totalSeconds > 0 ? (position / totalSeconds).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: const Color(0xFF0E6B5A),
            inactiveTrackColor: const Color(0xFFDDEBE4),
            thumbColor: const Color(0xFF0E6B5A),
            overlayColor: const Color(0xFF0E6B5A).withOpacity(0.18),
          ),
          child: Slider(
            value: value,
            onChanged: (v) {
              setState(() {
                _dragValue = v * totalSeconds;
              });
            },
            onChangeStart: (_) {
              setState(() {
                _isDragging = true;
                _dragValue = audio.position.inSeconds.toDouble();
              });
            },
            onChangeEnd: (v) {
              final newPosition = Duration(seconds: (v * totalSeconds).round());
              audio.seek(newPosition);
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(seconds: position.round())),
                style: TextStyle(
                  color: const Color(0xFF0A1F1A).withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatDuration(totalDuration),
                style: TextStyle(
                  color: const Color(0xFF0A1F1A).withOpacity(0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildControls(Color mintGreen, Color darkText, Color secondaryText, AudioProvider audio) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ControlIcon(
          icon: Icons.shuffle_rounded,
          color: audio.isShuffle ? mintGreen : secondaryText,
          onTap: audio.toggleShuffle,
        ),
        _ControlIcon(
          icon: Icons.skip_previous_rounded,
          color: darkText,
          size: 36,
          onTap: audio.playPrevious,
        ),
        _PlayButton(
          isPlaying: audio.isPlaying,
          mintGreen: mintGreen,
          onTap: audio.togglePlayPause,
        ),
        _ControlIcon(
          icon: Icons.skip_next_rounded,
          color: darkText,
          size: 36,
          onTap: audio.playNext,
        ),
        _ControlIcon(
          icon: Icons.repeat_rounded,
          color: audio.isRepeat ? mintGreen : secondaryText,
          onTap: audio.toggleRepeat,
        ),
      ],
    );
  }
}

// Keep demo data reference for fallback
const demoCurrentSong = Song(
  id: 's1',
  title: 'Nhân Danh Tình Yêu',
  artists: ['Lyhan'],
  coverUrl: '',
  audioUrl: '',
);

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.icon,
    required this.color,
    this.size = 24,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: size),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.mintGreen,
    required this.onTap,
  });

  final bool isPlaying;
  final Color mintGreen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: mintGreen,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: mintGreen.withOpacity(0.3),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.isLiked, required this.onTap});

  final bool isLiked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isLiked ? mintGreen.withOpacity(0.12) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isLiked ? mintGreen : darkText,
          size: 24,
        ),
      ),
    );
  }
}
