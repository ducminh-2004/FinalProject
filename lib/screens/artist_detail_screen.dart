import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../services/view_service.dart';
import '../models/view_model.dart';
import '../providers/audio_provider.dart';
import '../providers/user_provider.dart';
import '../extensions/view_extensions.dart';
import '../firebase/firestore_service.dart';
import '../widgets/song_options_bottom_sheet.dart';
import 'now_playing_screen.dart';
import 'album_detail_screen.dart';

class ArtistDetailScreen extends StatefulWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<Song> _artistSongs = [];
  List<Album> _artistAlbums = [];
  bool _isLoading = true;
  int _totalStreams = 0;

  @override
  void initState() {
    super.initState();
    _loadArtistContent();
    
    final userProvider = context.read<UserProvider>();
    widget.artist.id.trackArtistView(userId: userProvider.userId);
  }

  Future<void> _loadArtistContent() async {
    try {
      final stats = await ViewService.getViewStats(ViewTargetType.artist, widget.artist.id);

      final allSongs = await FirestoreService.getSongs(limit: 200);
      final allAlbums = await FirestoreService.getAlbums(limit: 100);
      
      final artistNameLower = widget.artist.name.toLowerCase();
      
      final songs = allSongs.where((s) => 
        s.artist.toLowerCase() == artistNameLower
      ).toList();
      
      final albums = allAlbums.where((a) => 
        a.artist.toLowerCase() == artistNameLower
      ).toList();
      
      if (mounted) {
        setState(() {
          _artistSongs = songs;
          _artistAlbums = albums;
          _totalStreams = stats.totalViews;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading artist content: $e');
      if (mounted) {
        setState(() {
          _artistSongs = [];
          _artistAlbums = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintGreen = Color(0xFF0E6B5A);
    const darkText = Color(0xFF0A1F1A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mintGreen))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, mintGreen, darkText),
                ),
                SliverToBoxAdapter(
                  child: _buildActions(context, mintGreen, darkText),
                ),
                if (_artistSongs.isNotEmpty) ...[
                  _buildSectionHeader('Bài hát phổ biến', () {}),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _artistSongs[index];
                        return _ArtistSongTile(
                          song: song,
                          index: index + 1,
                          onTap: () {
                            context.read<AudioProvider>().playPlaylist(_artistSongs, startIndex: index);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NowPlayingScreen(initialSong: song),
                              ),
                            );
                          },
                        );
                      },
                      childCount: _artistSongs.length > 5 ? 5 : _artistSongs.length,
                    ),
                  ),
                ],
                if (_artistAlbums.isNotEmpty) ...[
                  _buildSectionHeader('Album & EP', () {}),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _artistAlbums.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final album = _artistAlbums[index];
                          return _AlbumCard(
                            album: album,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AlbumDetailScreen(album: album),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: _buildAboutSection(darkText),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildHeader(BuildContext context, Color mintGreen, Color darkText) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [mintGreen, const Color(0xFF0A1F1A)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: widget.artist.avatarUrl != null
                  ? Image.network(widget.artist.avatarUrl!, fit: BoxFit.cover)
                  : const Icon(Icons.person_rounded, color: Colors.white, size: 80),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.artist.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (widget.artist.isVerified == true) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified_rounded, color: Colors.blue, size: 22),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Color mintGreen, Color darkText) {
    final userProvider = context.watch<UserProvider>();
    final isFollowing = userProvider.isArtistFollowed(widget.artist.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => userProvider.toggleFollowArtist(widget.artist.id),
            icon: Icon(isFollowing ? Icons.check_rounded : Icons.add_rounded),
            label: Text(isFollowing ? 'Đã follow' : 'Follow'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.transparent : mintGreen,
              foregroundColor: isFollowing ? mintGreen : Colors.white,
              side: isFollowing ? BorderSide(color: mintGreen, width: 2) : BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: darkText.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: darkText.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.share_rounded, color: darkText, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Color darkText) {
    if (widget.artist.bio == null || widget.artist.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Về nghệ sĩ',
            style: TextStyle(
              color: Color(0xFF0A1F1A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.artist.bio!,
            style: TextStyle(
              color: darkText.withOpacity(0.7),
              fontSize: 15,
              height: 1.6,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStreamCard(Color mintGreen, Color darkText) {
    final streams = _totalStreams;
    final formatted = streams >= 1000000
        ? '${(streams / 1000000).toStringAsFixed(1)} triệu'
        : streams >= 1000
            ? '${(streams / 1000).toStringAsFixed(0)} nghìn'
            : '$streams';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: mintGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: mintGreen.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mintGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.trending_up_rounded, color: mintGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatted,
                    style: TextStyle(
                      color: mintGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'lượt stream hàng tháng',
                    style: TextStyle(
                      color: darkText.withOpacity(0.5),
                      fontSize: 13,
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

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF0A1F1A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0E6B5A),
              ),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _ArtistSongTile({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 24,
              child: Text(
                '$index',
                style: TextStyle(
                  color: darkText.withOpacity(0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Cover
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: mintGreen.withOpacity(0.1),
              ),
              child: song.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(song.coverUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.music_note_rounded, color: mintGreen.withOpacity(0.7)),
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
                    style: TextStyle(
                      color: darkText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artistDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: darkText.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // More button
            IconButton(
              onPressed: () {
                SongOptionsBottomSheet.show(context, song);
              },
              icon: Icon(Icons.more_vert_rounded, color: darkText.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F1A).withOpacity(0.07),
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
                  color: const Color(0xFF0E6B5A).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: album.coverUrl != null
                    ? Center(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.network(
                            album.coverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.album_rounded,
                              color: const Color(0xFF0E6B5A).withOpacity(0.5),
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.album_rounded,
                        color: const Color(0xFF0E6B5A).withOpacity(0.5),
                        size: 48,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
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
                    '${album.songs.length} bài hát',
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withOpacity(0.5),
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
