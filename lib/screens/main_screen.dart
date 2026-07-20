import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'room_list_screen.dart';
import 'library_screen.dart';
import 'trending_screen.dart';
import 'premium_screen.dart';
import 'now_playing_screen.dart';
import '../providers/audio_provider.dart';
import '../models/song.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  static const _mintGreen = Color(0xFF0E6B5A);

  static const _tabs = <Widget>[
    HomeScreen(key: PageStorageKey('home')),
    SearchScreen(key: PageStorageKey('search')),
    RoomListScreen(key: PageStorageKey('room')),
    TrendingScreen(key: PageStorageKey('trending')),
    LibraryScreen(key: PageStorageKey('library')),
    PremiumScreen(key: PageStorageKey('premium')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<AudioProvider>(
            builder: (context, audio, _) {
              if (!audio.hasSong) return const SizedBox.shrink();
              return _MiniPlayer(
                song: audio.currentSong!,
                isPlaying: audio.isPlaying,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(initialSong: audio.currentSong),
                  ),
                ),
                onPlayPause: audio.togglePlayPause,
                onStop: audio.stop,
              );
            },
          ),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: context.surface,
            surfaceTintColor: context.surface,
            elevation: 1,
            indicatorColor: _mintGreen.withValues(alpha: 0.12),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.speaker_group_outlined),
                selectedIcon: Icon(Icons.speaker_group_rounded),
                label: 'Room',
              ),
              NavigationDestination(
                icon: Icon(Icons.trending_up_outlined),
                selectedIcon: Icon(Icons.trending_up_rounded),
                label: 'Trending',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music_rounded),
                label: 'Thư viện',
              ),
              NavigationDestination(
                icon: Icon(Icons.stars_outlined),
                selectedIcon: Icon(Icons.stars_rounded),
                label: 'Premium',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.song,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onStop,
  });

  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final darkText = context.textPrimary;
    final mintGreen = const Color(0xFF0E6B5A);
    final surface = context.surface2;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: context.surface,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: surface,
              ),
              child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        song.coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, color: mintGreen.withValues(alpha: 0.7), size: 20),
                      ),
                    )
                  : Icon(Icons.music_note_rounded, color: mintGreen.withValues(alpha: 0.7), size: 20),
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
                      color: darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: darkText.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlayPause,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: const Color(0xFF0A1F1A),
                size: 24,
              ),
            ),
            IconButton(
              onPressed: onStop,
              icon: Icon(
                Icons.stop_rounded,
                color: const Color(0xFF0A1F1A).withValues(alpha: 0.6),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
