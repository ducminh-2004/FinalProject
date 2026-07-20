import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/artist.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../services/view_service.dart';
import '../models/view_model.dart';
import '../firebase/firestore_service.dart';
import 'liked_songs_screen.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';
import 'user_playlists_screen.dart';
import '../theme/app_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Artist> _followedArtists = [];
  bool _isLoadingArtists = true;
  List<String> _lastFollowedIds = [];
  String _selectedFilter = 'Tất cả';

  static const _darkText = Color(0xFF0A1F1A);
  static const _mintGreen = Color(0xFF0E6B5A);
  static const _surface = Color(0xFFF2F4F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowedArtists();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    final currentIds = userProvider.followedArtistIds;
    
    // Reload if followedIds changed
    if (currentIds != _lastFollowedIds) {
      _lastFollowedIds = currentIds;
      _loadFollowedArtists();
    }
  }

  Future<void> _loadFollowedArtists() async {
    if (!mounted) return;
    
    final userProvider = context.read<UserProvider>();
    final followedIds = userProvider.followedArtistIds;
    
    debugPrint('Library: Loading followed artists, IDs: $followedIds');
    
    if (followedIds.isEmpty) {
      if (mounted) {
        setState(() {
          _followedArtists = [];
          _isLoadingArtists = false;
        });
      }
      return;
    }
    
    final artists = await userProvider.getFollowedArtists();
    debugPrint('Library: Loaded ${artists.length} artists');
    
    if (mounted) {
      setState(() {
        _followedArtists = artists;
        _isLoadingArtists = false;
      });
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
          'Thư viện',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserPlaylistsScreen()),
            ),
            icon: const Icon(Icons.add_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          final likedSongIds = userProvider.likedSongIds;
          final followedIds = userProvider.followedArtistIds;
          final isLoggedIn = userProvider.isLoggedIn;

          if (!isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_music_outlined, size: 64, color: _darkText.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'Đăng nhập để xem thư viện',
                    style: TextStyle(
                      color: _darkText.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Reload khi followedIds thay đổi
          debugPrint('Library Build: followedIds = $followedIds, artists count = ${_followedArtists.length}');

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Playlist'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nghệ sĩ'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Album'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Liked Songs
              if (_selectedFilter == 'Tất cả' || _selectedFilter == 'Playlist') ...[
                _buildSectionItem(
                  context,
                  icon: Icons.favorite_rounded,
                  iconColor: _mintGreen,
                  title: 'Bài hát đã thích',
                  subtitle: '${likedSongIds.length} bài hát',
                  gradient: LinearGradient(
                    colors: [_mintGreen, _darkText],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
                  ),
                  onPlayTap: () async {
                    final songs = await userProvider.getLikedSongs();
                    if (songs.isNotEmpty && mounted) {
                      // ignore: use_build_context_synchronously
                      context.read<AudioProvider>().playPlaylist(songs, userId: userProvider.userId);
                      // ignore: use_build_context_synchronously
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: songs.first)),
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Followed Artists section
              if (_selectedFilter == 'Tất cả' || _selectedFilter == 'Nghệ sĩ') ...[
                _buildSectionHeader('Nghệ sĩ theo dõi'),
                const SizedBox(height: 10),
                _buildFollowedArtistsSection(followedIds),
                const SizedBox(height: 24),
              ],

              // Playlists section header
              if (_selectedFilter == 'Tất cả' || _selectedFilter == 'Playlist') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Playlist của bạn'),
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserPlaylistsScreen()),
                      ),
                      icon: const Icon(Icons.add_rounded, color: _mintGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // User's playlists display
                StreamBuilder<List<Playlist>>(
                  stream: FirestoreService.watchUserPlaylists(userProvider.userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final playlists = snapshot.data ?? [];
                    if (playlists.isEmpty) {
                      return _buildCreatePlaylistButton(context);
                    }
                    return Column(
                      children: [
                        ...playlists.map((playlist) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPlaylistItem(
                            context,
                            title: playlist.title,
                            subtitle: '${playlist.songIds.length} bài hát',
                            icon: Icons.queue_music_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(playlist: playlist),
                              ),
                            ),
                          ),
                        )),
                        _buildCreatePlaylistButton(context),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Recent History (Professional addition)
              if (_selectedFilter == 'Tất cả') ...[
                _buildSectionHeader('Nghe gần đây'),
                const SizedBox(height: 10),
                _buildRecentHistoryItem(context),
                const SizedBox(height: 100),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentHistoryItem(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    return _buildSectionItem(
      context,
      icon: Icons.history_rounded,
      iconColor: Colors.blue,
      title: 'Lịch sử nghe nhạc',
      subtitle: 'Xem lại các bài hát bạn đã nghe',
      gradient: const LinearGradient(
        colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
      ),
      onTap: () {
      },
      onPlayTap: () async {
        final history = await ViewService.getUserHistory(userProvider.userId!, limit: 20);
        final songIds = history
            .where((r) => r.targetType == ViewTargetType.song)
            .map((r) => r.targetId)
            .toSet()
            .toList();

        if (songIds.isNotEmpty) {
          final songs = await FirestoreService.getSongsByIds(songIds);
          if (songs.isNotEmpty && mounted) {
            // ignore: use_build_context_synchronously
            context.read<AudioProvider>().playPlaylist(songs, userId: userProvider.userId);
            // ignore: use_build_context_synchronously
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NowPlayingScreen(initialSong: songs.first)),
            );
          }
        }
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _mintGreen : context.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _mintGreen : context.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildFollowedArtistsSection(List<String> followedIds) {
    if (_isLoadingArtists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (followedIds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _mintGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person_add_outlined, color: _mintGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa theo dõi nghệ sĩ nào',
                    style: TextStyle(
                      color: _darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow nghệ sĩ để xem ở đây',
                    style: TextStyle(
                      color: _darkText.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_followedArtists.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _followedArtists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final artist = _followedArtists[index];
          return _buildArtistCard(context, artist);
        },
      ),
    );
  }

  Widget _buildArtistCard(BuildContext context, Artist artist) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surface,
              ),
              child: artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        artist.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person_rounded,
                          color: _mintGreen.withValues(alpha: 0.6),
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_rounded,
                      color: _mintGreen.withValues(alpha: 0.6),
                      size: 32,
                    ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Nghệ sĩ',
              style: TextStyle(
                color: _darkText.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
    VoidCallback? onPlayTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.textPrimary.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onPlayTap ?? onTap,
              icon: Icon(Icons.play_circle_filled_rounded, color: _mintGreen, size: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePlaylistButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserPlaylistsScreen()),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.divider,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: _mintGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Tạo playlist',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: context.iconMuted,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.textPrimary.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.surface2,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: Icon(
                icon,
                color: _darkText.withValues(alpha: 0.4),
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: _mintGreen.withValues(alpha: 0.8),
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


