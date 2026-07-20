import 'package:flutter/material.dart';
import 'dart:async';
import '../models/song.dart';
import '../models/album.dart';
import '../firebase/firestore_service.dart';

class AddSongRoomSheet extends StatefulWidget {
  final bool isInitial;
  const AddSongRoomSheet({super.key, this.isInitial = false});

  @override
  State<AddSongRoomSheet> createState() => _AddSongRoomSheetState();
}

class _AddSongRoomSheetState extends State<AddSongRoomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  List<Album> _albumResults = [];
  final Set<String> _selectedSongIds = {};
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultSongs();
  }

  Future<void> _loadDefaultSongs() async {
    setState(() => _isLoading = true);
    final songs = await FirestoreService.getSongs(limit: 20);
    if (mounted) {
      setState(() {
        _searchResults = songs;
        _isLoading = false;
      });
    }
  }

  void _search(String query) async {
    if (query.trim().isEmpty) {
      _loadDefaultSongs();
      return;
    }
    setState(() => _isLoading = true);
    
    try {
      // 1. Tìm kiếm bài hát theo từ khóa
      final songs = await FirestoreService.searchSongs(query);
      
      // 2. Lấy tất cả album (hoặc giới hạn lớn hơn) để lọc chính xác hơn ở Client
      // Vì Firestore search theo substring khá hạn chế, ta lọc ở Client cho chính xác yêu cầu
      final allAlbums = await FirestoreService.getAlbums(limit: 100);
      
      if (mounted) {
        setState(() {
          _searchResults = songs;
          // Lọc album: Theo tiêu đề HOẶC theo tên nghệ sĩ (không phân biệt hoa thường)
          final queryLower = query.toLowerCase();
          _albumResults = allAlbums.where((a) {
            final titleMatch = a.title.toLowerCase().contains(queryLower);
            final artistMatch = a.artist.toLowerCase().contains(queryLower);
            return titleMatch || artistMatch;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintGreen = Color(0xFF0E6B5A);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  widget.isInitial ? 'Chọn nhạc cho phòng của bạn' : 'Thêm bài hát vào danh sách',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm bài hát, nghệ sĩ hoặc album...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF0F2F0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: mintGreen))
                : _searchResults.isEmpty && _albumResults.isEmpty
                  ? const Center(child: Text('Không tìm thấy kết quả'))
                  : ListView(
                    children: [
                      if (_albumResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Text('ALBUMS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
                        ),
                        ..._albumResults.map((album) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                                    ? Image.network(album.coverUrl!, width: 45, height: 45, fit: BoxFit.cover)
                                    : Container(width: 45, height: 45, color: Colors.grey[200], child: const Icon(Icons.album)),
                              ),
                              title: Text(album.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${album.songs.length} bài hát • ${album.artist}'),
                              trailing: Checkbox(
                                value: album.songs.isNotEmpty && album.songs.every((s) => _selectedSongIds.contains(s.id)),
                                activeColor: mintGreen,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedSongIds.addAll(album.songs.map((s) => s.id));
                                    } else {
                                      for (var s in album.songs) {
                                        _selectedSongIds.remove(s.id);
                                      }
                                    }
                                  });
                                },
                              ),
                            )),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Text('BÀI HÁT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
                      ),
                      ..._searchResults.map((song) => CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: song.coverUrl != null && song.coverUrl!.isNotEmpty
                                  ? Image.network(song.coverUrl!, width: 45, height: 45, fit: BoxFit.cover)
                                  : Container(width: 45, height: 45, color: Colors.grey[200], child: const Icon(Icons.music_note)),
                            ),
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(song.artist),
                            activeColor: mintGreen,
                            value: _selectedSongIds.contains(song.id),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedSongIds.add(song.id);
                                } else {
                                  _selectedSongIds.remove(song.id);
                                }
                              });
                            },
                          )),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selectedSongIds.toList()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mintGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  widget.isInitial ? 'Tiếp tục với ${_selectedSongIds.length} bài' : 'Thêm ${_selectedSongIds.length} bài hát',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
