import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/genre.dart';
import '../models/song.dart';
import '../models/artist.dart';
import '../providers/audio_provider.dart';
import '../firebase/firestore_service.dart';
import 'artist_detail_screen.dart';
import 'genre_playlist_screen.dart';
import 'now_playing_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Song> _songResults = [];
  List<Artist> _artistResults = [];
  List<Genre> _genres = [];
  bool _isLoadingGenres = true;
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await FirestoreService.getGenres(limit: 50);
      if (mounted) {
        setState(() {
          _genres = genres;
          _isLoadingGenres = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading genres: $e');
      if (mounted) {
        setState(() => _isLoadingGenres = false);
      }
    }
  }

  static const _darkText = Color(0xFF0A1F1A);
  static const _mintGreen = Color(0xFF0E6B5A);

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showResults = _focusNode.hasFocus && _searchController.text.isNotEmpty;
    });
  }

  Future<void> _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _songResults = [];
        _artistResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await Future.wait([
        FirestoreService.searchSongs(query),
        FirestoreService.searchArtists(query),
      ]);
      
      final songs = results[0] as List<Song>;
      final artists = results[1] as List<Artist>;

      if (mounted) {
        setState(() {
          _songResults = songs;
          _artistResults = artists;
          _showResults = true;
        });
      }
    } catch (e) {
      debugPrint('Error searching: $e');
      if (mounted) {
        setState(() {
          _songResults = [];
          _artistResults = [];
        });
      }
    }

    if (mounted) {
      setState(() => _isSearching = false);
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
          'Search',
          style: TextStyle(
            color: _darkText,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'What do you want to listen to?',
                hintStyle: TextStyle(
                  color: _darkText.withValues(alpha: 0.45),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8FA89B), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF8FA89B), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _songResults = [];
                            _artistResults = [];
                            _showResults = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _mintGreen, width: 1.4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _onSearch,
              onSubmitted: _onSearch,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _showResults ? _buildSearchResults() : _buildBrowseGenres(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: _mintGreen));
    }

    final hasResults = _songResults.isNotEmpty || _artistResults.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: _darkText.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy kết quả',
              style: TextStyle(
                color: _darkText.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thử tìm kiếm với từ khóa khác',
              style: TextStyle(
                color: _darkText.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Artists section
        if (_artistResults.isNotEmpty) ...[
          const Text(
            'Nghệ sĩ',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._artistResults.map((artist) => _ArtistResultTile(artist: artist)),
          const SizedBox(height: 20),
        ],
        // Songs section
        if (_songResults.isNotEmpty) ...[
          const Text(
            'Bài hát',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._songResults.map((song) => _SongResultTile(song: song)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBrowseGenres() {
    if (_isLoadingGenres) {
      return const Center(child: CircularProgressIndicator(color: _mintGreen));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Browse all',
            style: TextStyle(
              color: _darkText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 14),
          _genres.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Chưa có thể loại nào')),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _genres.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    return _GenreTile(genre: genre);
                  },
                ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _ArtistResultTile extends StatelessWidget {
  final Artist artist;

  const _ArtistResultTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDDEBE4),
              ),
              child: artist.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(artist.avatarUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.person_rounded, color: mintGreen.withValues(alpha: 0.7)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (artist.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nghệ sĩ${artist.genres?.isNotEmpty == true ? ' • ${artist.genres!.first}' : ''}',
                    style: TextStyle(
                      color: darkText.withValues(alpha: 0.6),
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
}

class _SongResultTile extends StatelessWidget {
  final Song song;

  const _SongResultTile({required this.song});

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.read<AudioProvider>();
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: () {
        audioProvider.playSong(song);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NowPlayingScreen(initialSong: song),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: mintGreen.withValues(alpha: 0.1),
              ),
              child: song.coverUrl != null && song.coverUrl!.isNotEmpty
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.music_note, size: 12, color: darkText.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            // Try to find the artist to navigate to detail
                            Artist? artist;
                            if (song.artistIds.isNotEmpty) {
                              artist = await FirestoreService.getArtistById(song.artistIds.first);
                            }
                            
                            if (artist == null) {
                              final artists = await FirestoreService.searchArtists(song.artistDisplay);
                              if (artists.isNotEmpty) {
                                artist = artists.firstWhere(
                                  (a) => a.name.toLowerCase() == song.artistDisplay.toLowerCase(),
                                  orElse: () => artists.first,
                                );
                              }
                            }

                            if (artist != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistDetailScreen(artist: artist!),
                                ),
                              );
                            }
                          },
                          child: Text(
                            '${song.artist} • ${song.genres.isNotEmpty ? song.genres.first : "Unknown"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: darkText.withValues(alpha: 0.6),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: darkText.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_circle_filled_rounded, color: mintGreen, size: 40),
              onPressed: () {
                audioProvider.playSong(song);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NowPlayingScreen(initialSong: song),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularArtistCard extends StatelessWidget {
  final Artist artist;

  const _PopularArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    final mintGreen = const Color(0xFF0E6B5A);
    final darkText = const Color(0xFF0A1F1A);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: darkText.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDDEBE4),
              ),
              child: artist.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(artist.avatarUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.person_rounded, color: mintGreen.withValues(alpha: 0.7), size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: darkText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({required this.genre});

  final Genre genre;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GenrePlaylistScreen(genre: genre),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: genre.color,
          borderRadius: BorderRadius.circular(18),
          image: genre.imageUrl != null && genre.imageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(genre.imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.1),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: genre.color.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              genre.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
