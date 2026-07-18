import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../models/genre.dart';
import '../../firebase/firestore_service.dart';

class AdminSongGenresScreen extends StatefulWidget {
  final Song song;
  const AdminSongGenresScreen({super.key, required this.song});

  @override
  State<AdminSongGenresScreen> createState() => _AdminSongGenresScreenState();
}

class _AdminSongGenresScreenState extends State<AdminSongGenresScreen> {
  List<Genre> _allGenres = [];
  List<String> _selectedGenreIds = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedGenreIds = List.from(widget.song.genreIds);
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await FirestoreService.getGenres(limit: 100);
      setState(() {
        _allGenres = genres;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading genres: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Tìm tên các thể loại tương ứng với ID để lưu vào trường 'genres' (cho nhanh khi hiển thị)
      final List<String> selectedNames = _allGenres
          .where((g) => _selectedGenreIds.contains(g.id))
          .map((g) => g.name)
          .toList();

      await FirestoreService.updateSong(widget.song.id, {
        'genreIds': _selectedGenreIds,
        'genres': selectedNames,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thể loại thành công!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mintGreen = Color(0xFF0E6B5A);

    return Scaffold(
      appBar: AppBar(
        title: Text('Thể loại: ${widget.song.title}'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.bold, color: mintGreen)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allGenres.isEmpty
              ? const Center(child: Text('Chưa có thể loại nào trong database'))
              : ListView.builder(
                  itemCount: _allGenres.length,
                  itemBuilder: (context, index) {
                    final genre = _allGenres[index];
                    final isSelected = _selectedGenreIds.contains(genre.id);
                    return CheckboxListTile(
                      activeColor: mintGreen,
                      title: Text(genre.name),
                      secondary: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: genre.color, shape: BoxShape.circle),
                      ),
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedGenreIds.add(genre.id);
                          } else {
                            _selectedGenreIds.remove(genre.id);
                          }
                        });
                      },
                    );
                  },
                ),
    );
  }
}
