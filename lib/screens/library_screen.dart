import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/artist.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import 'liked_songs_screen.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';
import 'user_playlists_screen.dart';
import 'profile_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Artist> _followedArtists = [];
  bool _isLoadingArtists = true;
  List<String> _lastFollowedIds = [];

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
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        surfaceTintColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: const Text(
          'Thư viện',
          style: TextStyle(
            color: _darkText,
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
              // Followed Artists section
              _buildSectionHeader('Nghệ sĩ theo dõi'),
              const SizedBox(height: 10),
              _buildFollowedArtistsSection(followedIds),
              const SizedBox(height: 24),

              // Liked Songs
              _buildSectionHeader('Bài hát đã thích'),
              const SizedBox(height: 10),
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
              ),
              const SizedBox(height: 24),

              // Playlists section header
              _buildSectionHeader('Playlist của bạn'),
              const SizedBox(height: 10),

              // Create Playlist button
              _buildCreatePlaylistButton(context),
              const SizedBox(height: 10),

              // User's playlists
              _buildPlaylistItem(
                context,
                title: 'Tạo playlist đầu tiên của bạn',
                subtitle: 'Dễ dàng tạo playlist để sắp xếp nhạc yêu thích',
                icon: Icons.library_music_outlined,
              ),
              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: _darkText,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _darkText.withValues(alpha: 0.05),
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
                style: const TextStyle(
                  color: _darkText,
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _darkText.withValues(alpha: 0.05),
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
                    style: const TextStyle(
                      color: _darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _darkText.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
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
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _darkText.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: _mintGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Tạo playlist',
                style: TextStyle(
                  color: _darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: _darkText.withValues(alpha: 0.4),
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
  }) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _darkText.withValues(alpha: 0.05),
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
                color: _surface,
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
                    style: const TextStyle(
                      color: _darkText,
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
                      color: _darkText.withValues(alpha: 0.6),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0E6B5A),
            image: userProvider.photoUrl != null
                ? DecorationImage(image: NetworkImage(userProvider.photoUrl!), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: userProvider.photoUrl == null 
              ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
