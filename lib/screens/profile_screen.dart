import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/user_provider.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';
import 'now_playing_screen.dart';
import '../firebase/auth_service.dart';
import 'login_screen.dart';
import 'liked_songs_screen.dart';
import 'user_playlists_screen.dart';
import 'edit_profile_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'artist_register_screen.dart';
import 'artist_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Playlist> _playlists = [];
  List<Song> _recentSongs = [];
  bool _isLoading = true;
  int _songsPlayed = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final playlists = await FirestoreService.getUserPlaylists(userProvider.userId!);
      final songs = await FirestoreService.getSongs(limit: 50);
      
      setState(() {
        _playlists = playlists;
        _recentSongs = songs.take(3).toList();
        _songsPlayed = songs.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      setState(() => _isLoading = false);
    }
  }

  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        surfaceTintColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: const Text(
          'Hồ sơ',
          style: TextStyle(
            color: _darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showSettingsBottomSheet(context),
            icon: const Icon(Icons.settings_outlined, color: _darkText),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mintGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _mintGreen,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(context, user),
                    const SizedBox(height: 24),
                    _buildStatsSection(context, userProvider),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Playlist của bạn'),
                    const SizedBox(height: 12),
                    _buildPlaylistsSection(context),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Nghe gần đây'),
                    const SizedBox(height: 12),
                    _buildRecentlyPlayed(context),
                    const SizedBox(height: 24),
                    _buildLikedSongsCard(context),
                    const SizedBox(height: 24),
                    _buildAccountSection(context),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, user) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_mintGreen, _darkText],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
              ),
              child: user?.photoURL != null
                  ? Stack(
                      children: [
                        ClipOval(
                          child: Image.network(
                            user!.photoURL!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ],
                    )
                  : const Icon(
                      Icons.add_a_photo_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.displayName ?? user?.email?.split('@').first ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Chưa đăng nhập',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.watch<UserProvider>().subscriptionTier.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildStatsSection(BuildContext context, UserProvider userProvider) {
    final likedCount = userProvider.likedSongIds.length;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.headphones_rounded,
            value: '$_songsPlayed',
            label: 'Bài đã nghe',
            color: _mintGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite_rounded,
            value: '$likedCount',
            label: 'Bài yêu thích',
            color: const Color(0xFFE13300),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.playlist_play_rounded,
            value: '${_playlists.length}',
            label: 'Playlist',
            color: const Color(0xFF8D67AB),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _darkText,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPlaylistsSection(BuildContext context) {
    if (_playlists.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('Chưa có playlist nào'),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _playlists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          return _PlaylistCard(
            playlist: playlist,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: playlist),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRecentlyPlayed(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();

    if (_recentSongs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Chưa nghe bài nào gần đây')),
      );
    }

    return Column(
      children: _recentSongs.map((song) {
        return _RecentlyPlayedTile(
          song: song,
          onTap: () {
            audioProvider.playSong(song);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NowPlayingScreen(initialSong: song),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildLikedSongsCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LikedSongsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8D67AB),
              const Color(0xFF8D67AB).withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D67AB).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bài hát đã thích',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${context.watch<UserProvider>().likedSongIds.length} bài hát',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Container(
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
          _AccountTile(
            icon: Icons.person_outline_rounded,
            title: 'Chỉnh sửa hồ sơ',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
          Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
          _AccountTile(
            icon: Icons.credit_card_outlined,
            title: 'Phương thức thanh toán',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
          _AccountTile(
            icon: Icons.notifications_outlined,
            title: 'Thông báo',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
          _AccountTile(
            icon: Icons.lock_outline_rounded,
            title: 'Quyền riêng tư',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng sắp có!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
          _AccountTile(
            icon: Icons.help_outline_rounded,
            title: 'Trợ giúp',
            onTap: () {},
          ),
          ..._buildArtistTiles(context),
          if (context.watch<UserProvider>().isAdmin) ...[
            Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
            _AccountTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Quản trị hệ thống',
              textColor: const Color(0xFFE13300),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                );
              },
            ),
          ],
          Divider(height: 1, color: _darkText.withValues(alpha: 0.05)),
          _AccountTile(
            icon: Icons.logout_rounded,
            title: 'Đăng xuất',
            textColor: const Color(0xFFE13300),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildArtistTiles(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    // Admin has their own panel; skip artist tiles for admins.
    if (userProvider.isAdmin) return [];

    final divider = Divider(height: 1, color: _darkText.withValues(alpha: 0.05));

    if (userProvider.isArtist) {
      return [
        divider,
        _AccountTile(
          icon: Icons.mic_external_on_rounded,
          title: 'Trang nghệ sĩ',
          textColor: _mintGreen,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArtistDashboardScreen()),
            );
          },
        ),
      ];
    }

    if (userProvider.isPendingArtist) {
      return [
        divider,
        const _AccountTile(
          icon: Icons.hourglass_top_rounded,
          title: 'Đơn nghệ sĩ đang chờ duyệt',
          textColor: Color(0xFFB8860B),
          onTap: _noop,
        ),
      ];
    }

    return [
      divider,
      _AccountTile(
        icon: Icons.star_outline_rounded,
        title: 'Trở thành nghệ sĩ',
        textColor: _mintGreen,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArtistRegisterScreen()),
          );
        },
      ),
    ];
  }

  static void _noop() {}

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _darkText.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Chế độ tối'),
              trailing: Switch(
                value: false,
                onChanged: (value) {},
                activeColor: _mintGreen,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Ngôn ngữ'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Dung lượng'),
              subtitle: const Text('256 MB đã sử dụng'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0A1F1A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F1A).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0E6B5A).withValues(alpha: 0.8),
                      const Color(0xFF0E6B5A).withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 48,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
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
                    '${playlist.songIds.length} bài',
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                      fontSize: 12,
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

class _RecentlyPlayedTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _RecentlyPlayedTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: mintGreen.withValues(alpha: 0.1),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(song.coverUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.music_note_rounded, color: mintGreen.withValues(alpha: 0.7)),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: darkText.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              icon: Icon(Icons.play_circle_filled_rounded, color: mintGreen, size: 36),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? textColor;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: textColor ?? const Color(0xFF0A1F1A)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? const Color(0xFF0A1F1A),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: textColor == null
          ? Icon(Icons.chevron_right_rounded, color: const Color(0xFF0A1F1A).withValues(alpha: 0.3))
          : null,
    );
  }
}
