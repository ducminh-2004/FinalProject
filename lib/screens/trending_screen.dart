import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';
import '../services/view_service.dart';
import 'now_playing_screen.dart';
import 'artist_detail_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  @override
  Widget build(BuildContext context) {
    const mintGreen = Color(0xFF0E6B5A);
    const darkText = Color(0xFF0A1F1A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        surfaceTintColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: const Text(
          'Top Trending Music',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ViewService.getTrendingSongsStream(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: mintGreen));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(mintGreen, darkText);
          }

          final trendingData = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // Podium Section (Top 3)
              SliverToBoxAdapter(
                child: _Podium(songsData: trendingData.take(3).toList()),
              ),
              
              // List Section (from Rank 4 to 50)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final data = trendingData[index + 3];
                      return _TrendingSongTile(
                        song: Song.fromFirestoreMap(data),
                        rank: index + 4,
                        // No views shown for rank 4+ as requested
                        todayViews: null, 
                      );
                    },
                    childCount: trendingData.length > 3 ? trendingData.length - 3 : 0,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color mintGreen, Color darkText) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: mintGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.stacked_line_chart_rounded, size: 64, color: mintGreen),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có xu hướng hôm nay',
            style: TextStyle(color: darkText, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hãy nghe một vài bài hát để bắt đầu bảng xếp hạng trong 24h qua!',
              textAlign: TextAlign.center,
              style: TextStyle(color: darkText.withValues(alpha: 0.5), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<Map<String, dynamic>> songsData;

  const _Podium({required this.songsData});

  @override
  Widget build(BuildContext context) {
    if (songsData.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (songsData.length >= 2)
            Expanded(
              child: _PodiumItem(
                song: Song.fromFirestoreMap(songsData[1]),
                rank: 2,
                height: 160,
                color: const Color(0xFF8FA89B),
                avatarSize: 70,
                todayViews: (songsData[1]['todayViews'] as num?)?.toInt() ?? 0,
              ),
            ),
          
          // 1st Place
          if (songsData.isNotEmpty)
            Expanded(
              child: _PodiumItem(
                song: Song.fromFirestoreMap(songsData[0]),
                rank: 1,
                height: 200,
                color: const Color(0xFF0E6B5A),
                avatarSize: 90,
                isWinner: true,
                todayViews: (songsData[0]['todayViews'] as num?)?.toInt() ?? 0,
              ),
            ),
          
          // 3rd Place
          if (songsData.length >= 3)
            Expanded(
              child: _PodiumItem(
                song: Song.fromFirestoreMap(songsData[2]),
                rank: 3,
                height: 140,
                color: const Color(0xFFB5C9C0),
                avatarSize: 60,
                todayViews: (songsData[2]['todayViews'] as num?)?.toInt() ?? 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final Song song;
  final int rank;
  final double height;
  final Color color;
  final double avatarSize;
  final bool isWinner;
  final int todayViews;

  const _PodiumItem({
    required this.song,
    required this.rank,
    required this.height,
    required this.color,
    required this.avatarSize,
    required this.todayViews,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();
    const darkText = Color(0xFF0A1F1A);

    return GestureDetector(
      onTap: () {
        audioProvider.playSong(song);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: song)),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: isWinner ? 3 : 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                      ? Image.network(song.coverUrl!, fit: BoxFit.cover)
                      : Container(
                          color: color.withValues(alpha: 0.1),
                          child: Icon(Icons.music_note_rounded, color: color, size: avatarSize * 0.5),
                        ),
                ),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              if (isWinner)
                Positioned(
                  top: -25,
                  child: Icon(Icons.workspace_premium_rounded, color: Colors.amber[700], size: 32),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 65,
            child: Column(
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: darkText, fontSize: isWinner ? 14 : 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  song.artistDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: darkText.withValues(alpha: 0.6), fontSize: isWinner ? 12 : 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '$todayViews streams',
                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: height - 100,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.7)],
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Center(
              child: Icon(
                isWinner ? Icons.star_rounded : Icons.trending_up_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingSongTile extends StatelessWidget {
  final Song song;
  final int rank;
  final int? todayViews;

  const _TrendingSongTile({required this.song, required this.rank, this.todayViews});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();
    const mintGreen = Color(0xFF0E6B5A);
    const darkText = Color(0xFF0A1F1A);

    return InkWell(
      onTap: () {
        audioProvider.playSong(song);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: song)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text(
                '$rank',
                style: TextStyle(color: darkText.withValues(alpha: 0.4), fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: mintGreen.withValues(alpha: 0.05),
              ),
              child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(song.coverUrl!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.music_note_rounded, color: mintGreen),
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
                    style: const TextStyle(color: darkText, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: darkText.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  if (todayViews != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$todayViews lượt nghe hôm nay',
                      style: TextStyle(color: mintGreen.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded, color: mintGreen, size: 28),
              onPressed: () {
                audioProvider.playSong(song);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: song)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
