import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/song.dart';
import '../../firebase/firestore_service.dart';
import 'admin_song_genres_screen.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminSongsScreen extends StatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  State<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends State<AdminSongsScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      _songs = await FirestoreService.getSongs(limit: 100);
    } catch (e) {
      debugPrint('Error loading songs: $e');
      _songs = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Song> get _filteredSongs {
    if (_searchQuery.isEmpty) return _songs;
    return _songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             song.artistDisplay.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
        ),
        title: const Text(
          'Quản lý bài hát',
          style: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loadSongs,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSongDialog(context),
        backgroundColor: _mintGreen,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài hát...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSongs,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSongs.length,
                      itemBuilder: (context, index) {
                        return _SongTile(
                          song: _filteredSongs[index],
                          onEdit: () => _showSongDialog(context, song: _filteredSongs[index]),
                          onDelete: () => _deleteSong(_filteredSongs[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showSongDialog(BuildContext context, {Song? song}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SongFormSheet(
        song: song,
        onSave: (data) async {
          try {
            if (song == null) {
              await FirestoreService.createSong(
                title: data['title'],
                artists: List<String>.from(data['artists']),
                coverUrl: data['coverUrl'],
                audioUrl: data['audioUrl'],
                genres: List<String>.from(data['genres'] ?? []),
              );
            } else {
              await FirestoreService.updateSong(song.id, data);
            }
            await _loadSongs();
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bài hát'),
        content: Text('Bạn có chắc muốn xóa "${song.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteSong(song.id);
      _loadSongs();
    }
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SongTile({required this.song, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: song.coverUrl != null ? DecorationImage(image: NetworkImage(song.coverUrl!), fit: BoxFit.cover) : null,
            color: _mintGreen.withOpacity(0.1),
          ),
          child: song.coverUrl == null ? const Icon(Icons.music_note_rounded, color: _mintGreen) : null,
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(song.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSongGenresScreen(song: song))).then((_) => onEdit()),
              icon: const Icon(Icons.category_outlined, color: _mintGreen),
            ),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _SongFormSheet extends StatefulWidget {
  final Song? song;
  final Function(Map<String, dynamic>) onSave;
  const _SongFormSheet({this.song, required this.onSave});

  @override
  State<_SongFormSheet> createState() => _SongFormSheetState();
}

class _SongFormSheetState extends State<_SongFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _artistsController;
  late TextEditingController _genresController;
  String? _coverUrl;
  String? _audioUrl;
  bool _isUploadingCover = false;
  bool _isUploadingAudio = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _artistsController = TextEditingController(text: widget.song?.artists.join(', ') ?? '');
    _genresController = TextEditingController(text: widget.song?.genres.join(', ') ?? '');
    _coverUrl = widget.song?.coverUrl;
    _audioUrl = widget.song?.audioUrl;
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingCover = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (url != null) setState(() => _coverUrl = url);
      setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploadingAudio = true);
      final url = await CloudinaryService.uploadFile(File(result.files.single.path!), isAudio: true);
      if (url != null) setState(() => _audioUrl = url);
      setState(() => _isUploadingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin bài hát', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildField('Tên bài hát', _titleController),
            _buildField('Nghệ sĩ (phân cách bằng dấu phẩy)', _artistsController),
            const SizedBox(height: 12),
            const Text('Ảnh bìa', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 100, width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
                  image: _coverUrl != null ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover) : null,
                ),
                child: _isUploadingCover ? const Center(child: CircularProgressIndicator()) : (_coverUrl == null ? const Icon(Icons.add_a_photo) : null),
              ),
            ),
            const SizedBox(height: 12),
            const Text('File nhạc', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              onTap: _pickAudio,
              tileColor: _mintGreen.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(_audioUrl != null ? Icons.check_circle : Icons.audiotrack, color: _audioUrl != null ? Colors.green : _mintGreen),
              title: Text(_isUploadingAudio ? 'Đang tải lên...' : (_audioUrl != null ? 'Đã tải lên file nhạc' : 'Chọn file .mp3')),
            ),
            const SizedBox(height: 12),
            _buildField('Thể loại (phân cách bằng dấu phẩy)', _genresController),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUploadingCover || _isUploadingAudio) ? null : () {
                  final artists = _artistsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final genres = _genresController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'artists': artists,
                    'coverUrl': _coverUrl ?? '',
                    'audioUrl': _audioUrl ?? '',
                    'genres': genres,
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('LƯU BÀI HÁT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
