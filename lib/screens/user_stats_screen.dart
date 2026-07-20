import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../models/song.dart';
import '../firebase/firestore_service.dart';
import '../services/view_service.dart';
import '../models/view_model.dart';
import '../theme/app_theme.dart';
import 'now_playing_screen.dart';

class UserStatsScreen extends StatefulWidget {
  const UserStatsScreen({super.key});

  @override
  State<UserStatsScreen> createState() => _UserStatsScreenState();
}

class _UserStatsScreenState extends State<UserStatsScreen> {
  bool _isLoading = true;
  List<Song> _topSongs = [];
  List<_ArtistStat> _topArtists = [];
  int _totalMinutes = 0;
  int _totalSongsPlayed = 0;

  static const _mint = Color(0xFF0E6B5A);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    try {
      final history = await ViewService.getUserHistory(userId, limit: 500);
      final thisMonth = history.where((r) =>
          r.targetType == ViewTargetType.song &&
          r.viewedAt.isAfter(monthStart)).toList();

      _totalSongsPlayed = thisMonth.length;
      _totalMinutes = thisMonth.fold(0, (sum, r) => sum + r.durationSeconds) ~/ 60;

      // Count song plays
      final songCounts = <String, int>{};
      for (final r in thisMonth) {
        songCounts[r.targetId] = (songCounts[r.targetId] ?? 0) + 1;
      }

      // Top 5 songs
      final sortedSongIds = songCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top5Ids = sortedSongIds.take(5).map((e) => e.key).toList();
      final top5Songs = await FirestoreService.getSongsByIds(top5Ids);
      _topSongs = top5Ids
          .map((id) => top5Songs.firstWhere((s) => s.id == id,
              orElse: () => Song(id: id, title: id)))
          .where((s) => s.title.isNotEmpty)
          .toList();

      // Count artist plays
      final artistCounts = <String, int>{};
      for (final r in thisMonth) {
        final song = top5Songs.firstWhere((s) => s.id == r.targetId,
            orElse: () => Song(id: '', title: ''));
        if (song.id.isEmpty && !top5Ids.contains(r.targetId)) {
          // song not in top5, load separately — skip for performance
          continue;
        }
        for (final a in song.artists) {
          artistCounts[a] = (artistCounts[a] ?? 0) + 1;
        }
      }

      // Get full artist play counts from all history
      final allSongIds = thisMonth.map((r) => r.targetId).toSet().toList();
      final allSongs = await FirestoreService.getSongsByIds(allSongIds.take(50).toList());
      final fullArtistCounts = <String, int>{};
      for (final r in thisMonth) {
        final song = allSongs.firstWhere((s) => s.id == r.targetId,
            orElse: () => Song(id: '', title: ''));
        for (final a in song.artists) {
          fullArtistCounts[a] = (fullArtistCounts[a] ?? 0) + 1;
        }
      }

      final sortedArtists = fullArtistCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      _topArtists = sortedArtists
          .take(5)
          .map((e) => _ArtistStat(name: e.key, plays: e.value))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        surfaceTintColor: context.bg,
        elevation: 0,
        title: Text(
          'Thống kê của bạn',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mint))
          : RefreshIndicator(
              onRefresh: _loadStats,
              color: _mint,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildMonthBanner(),
                    const SizedBox(height: 24),
                    _buildStatCards(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Top 5 bài nghe nhiều nhất'),
                    const SizedBox(height: 12),
                    _buildTopSongs(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('Top nghệ sĩ'),
                    const SizedBox(height: 12),
                    _buildTopArtists(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMonthBanner() {
    final now = DateTime.now();
    final months = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
      'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
      'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_mint, const Color(0xFF0A1F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${months[now.month - 1]} ${now.year}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Thống kê nghe nhạc',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Xem lại hành trình âm nhạc của bạn',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _StatBadge(
            icon: Icons.headphones_rounded,
            value: '$_totalSongsPlayed',
            label: 'Lượt nghe',
            color: _mint,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBadge(
            icon: Icons.timer_rounded,
            value: _totalMinutes >= 60
                ? '${(_totalMinutes / 60).toStringAsFixed(1)}h'
                : '${_totalMinutes}p',
            label: 'Thời gian',
            color: const Color(0xFF8D67AB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBadge(
            icon: Icons.library_music_rounded,
            value: '${_topSongs.length}',
            label: 'Bài top',
            color: const Color(0xFFE13300),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildTopSongs() {
    if (_topSongs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Chưa có dữ liệu tháng này')),
      );
    }

    return Column(
      children: List.generate(_topSongs.length, (i) {
        final song = _topSongs[i];
        return _TopSongTile(
          rank: i + 1,
          song: song,
          onTap: () {
            context.read<AudioProvider>().playSong(song);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: song)),
            );
          },
        );
      }),
    );
  }

  Widget _buildTopArtists() {
    if (_topArtists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('Chưa có dữ liệu tháng này')),
      );
    }

    return Column(
      children: List.generate(_topArtists.length, (i) {
        final artist = _topArtists[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _mint.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: _mint,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  artist.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${artist.plays} lượt',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ArtistStat {
  final String name;
  final int plays;
  const _ArtistStat({required this.name, required this.plays});
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TopSongTile extends StatelessWidget {
  final int rank;
  final Song song;
  final VoidCallback onTap;

  const _TopSongTile({
    required this.rank,
    required this.song,
    required this.onTap,
  });

  static const _mint = Color(0xFF0E6B5A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank == 1
                    ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                    : _mint.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank == 1 ? const Color(0xFFFFD700) : _mint,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _mint.withValues(alpha: 0.1),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(song.coverUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.music_note_rounded, color: _mint)),
                    )
                  : const Icon(Icons.music_note_rounded, color: _mint),
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
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_filled_rounded, color: _mint, size: 32),
          ],
        ),
      ),
    );
  }
}
