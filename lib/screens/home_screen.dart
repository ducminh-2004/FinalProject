import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/release.dart';
import '../firebase/firestore_service.dart';
import '../services/view_service.dart';
import '../models/view_model.dart';
import '../providers/audio_provider.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'profile_screen.dart';
import '../providers/user_provider.dart';
import 'edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Song> _recentlyPlayed = [];
  List<Artist> _artists = [];
  List<Album> _albums = [];
  bool _isLoading = true;
  StreamSubscription? _historySubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupHistoryStream();
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  void _setupHistoryStream() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId != null) {
      _historySubscription = ViewService.getUserHistoryStream(
        userId,
        limit: 15,
      ).listen((history) async {
        final songIds = <String>[];
        for (final record in history) {
          if (record.targetType == ViewTargetType.song &&
              !songIds.contains(record.targetId)) {
            songIds.add(record.targetId);
          }
        }

        if (songIds.isNotEmpty) {
          final songs = await FirestoreService.getSongsByIds(songIds);
          if (mounted) {
            setState(() {
              _recentlyPlayed = songs;
            });
          }
        } else if (mounted) {
          setState(() => _recentlyPlayed = []);
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = userProvider.userId;

      List<Song> recentlyPlayedSongs = [];

      if (userId != null) {
        // Lấy lịch sử nghe nhạc của người dùng
        final history = await ViewService.getUserHistory(userId, limit: 15);
        final songIds = <String>[];
        for (final record in history) {
          if (record.targetType == ViewTargetType.song &&
              !songIds.contains(record.targetId)) {
            songIds.add(record.targetId);
          }
        }
        
        if (songIds.isNotEmpty) {
          recentlyPlayedSongs = await FirestoreService.getSongsByIds(songIds);
        }
      }

      // Nếu không có lịch sử hoặc chưa đăng nhập, lấy bài hát mới nhất làm fallback
      if (recentlyPlayedSongs.isEmpty) {
        recentlyPlayedSongs = await FirestoreService.getSongs(limit: 8);
      }

      final artists = await FirestoreService.getArtists(limit: 20);
      final albums = await FirestoreService.getAlbums(limit: 20);

      if (mounted) {
        setState(() {
          _recentlyPlayed = recentlyPlayedSongs;
          _artists = artists;
          _albums = albums;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static const _darkText = Color(0xFF0A1F1A);
  static const _mintGreen = Color(0xFF0E6B5A);
  static const _lightSurface = Color(0xFFF2F4F1);

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        surfaceTintColor: const Color(0xFFF7F9F8),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _greeting(),
          style: const TextStyle(
            color: _darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thông báo sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _lightSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined, color: _darkText, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          _AvatarButton(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mintGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _mintGreen,
              child: ListView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 140),
                children: [
                  _SectionTitle('Recently played'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: _recentlyPlayed.isEmpty
                        ? const Center(child: Text('Chưa có bài hát nào'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentlyPlayed.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final item = _recentlyPlayed[index];
                              return _SongCard(
                                song: item,
                                onTap: () {
                                  final audioProvider = context.read<AudioProvider>();
                                  final userProvider = context.read<UserProvider>();
                                  audioProvider.playPlaylist(
                                    _recentlyPlayed,
                                    startIndex: index,
                                    userId: userProvider.userId,
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NowPlayingScreen(initialSong: item),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle('Popular albums & EPs'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 200,
                    child: _albums.isEmpty
                        ? const Center(child: Text('Chưa có album nào'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _albums.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final item = _albums[index];
                              return _AlbumCard(
                                album: item,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AlbumDetailScreen(album: item),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle('Popular artists'),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 130,
                    child: _artists.isEmpty
                        ? const Center(child: Text('Chưa có nghệ sĩ nào'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _artists.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final artist = _artists[index];
                              return _ArtistCircle(
                                artist: artist,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArtistDetailScreen(artist: artist),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _HomeScreenState._darkText,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, this.onTap});

  final Song song;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _HomeScreenState._darkText.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEBE4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: song.coverUrl != null
                    ? Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            song.coverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.music_note_rounded,
                              color: _HomeScreenState._mintGreen.withOpacity(0.6),
                              size: 36,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.music_note_rounded,
                        color: _HomeScreenState._mintGreen.withOpacity(0.6),
                        size: 36,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _HomeScreenState._darkText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeScreenState._darkText.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, this.onTap});

  final Album album;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _HomeScreenState._darkText.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEBE4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: album.coverUrl != null
                    ? Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            album.coverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            alignment: Alignment.center,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.album_rounded,
                              color: _HomeScreenState._mintGreen.withOpacity(0.6),
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.album_rounded,
                        color: _HomeScreenState._mintGreen.withOpacity(0.6),
                        size: 48,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _HomeScreenState._darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _HomeScreenState._darkText.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0E6B5A),
            image: userProvider.photoUrl != null 
                ? DecorationImage(image: NetworkImage(userProvider.photoUrl!), fit: BoxFit.cover)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0E6B5A),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: userProvider.photoUrl == null 
              ? const Icon(Icons.person_rounded, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}

class _ArtistCircle extends StatelessWidget {
  const _ArtistCircle({required this.artist, this.onTap});

  final Artist artist;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(48),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDDEBE4),
                boxShadow: [
                  BoxShadow(
                    color: _HomeScreenState._darkText.withOpacity(0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: artist.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        artist.avatarUrl!,
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          color: _HomeScreenState._mintGreen.withOpacity(0.7),
                          size: 48,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      color: _HomeScreenState._mintGreen.withOpacity(0.7),
                      size: 48,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            artist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _HomeScreenState._darkText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});

  final Release release;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: release.coverColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: release.coverColor.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.album_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            release.type,
            style: TextStyle(
              color: _HomeScreenState._darkText.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            release.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _HomeScreenState._darkText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
