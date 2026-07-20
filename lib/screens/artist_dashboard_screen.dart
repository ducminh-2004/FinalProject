import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/artist.dart';
import '../models/song.dart';
import '../models/genre.dart';
import '../providers/user_provider.dart';
import '../firebase/firestore_service.dart';
import '../services/cloudinary_service.dart';
import 'album_creator_screen.dart';
import 'lyrics_editor_screen.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);
const _albumPurple = Color(0xFF8D67AB);

// Cho phép chọn cả file nhạc lẫn video (mp4) — chỉ lấy âm thanh khi upload.
const _audioVideoExts = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'mp4', 'm4v', 'mov', 'webm'];

class ArtistDashboardScreen extends StatefulWidget {
  const ArtistDashboardScreen({super.key});

  @override
  State<ArtistDashboardScreen> createState() => _ArtistDashboardScreenState();
}

class _ArtistDashboardScreenState extends State<ArtistDashboardScreen> {
  Artist? _artist;
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final artistId = context.read<UserProvider>().artistId;
    if (artistId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final artist = await FirestoreService.getArtistById(artistId);
      final songs = await FirestoreService.getSongsByArtistId(artistId);
      if (mounted) {
        setState(() {
          _artist = artist;
          _songs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading artist dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAlbumCreator() {
    final userProvider = context.read<UserProvider>();
    if (_artist == null || userProvider.artistId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumCreatorScreen(
          fixedArtistId: userProvider.artistId,
          fixedArtistName: _artist!.name,
        ),
      ),
    ).then((created) {
      if (created == true) _loadData();
    });
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.music_note_rounded, color: _mintGreen),
              title: const Text('Đăng bài hát', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tải lên một bài hát đơn'),
              onTap: () {
                Navigator.pop(ctx);
                _openUploadSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add_rounded, color: _albumPurple),
              title: const Text('Đăng album', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Tạo album và thêm nhiều bài cùng lúc'),
              onTap: () {
                Navigator.pop(ctx);
                _openAlbumCreator();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openProfileEdit() {
    final artistId = context.read<UserProvider>().artistId;
    if (artistId == null || _artist == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArtistProfileEditSheet(
        artist: _artist!,
        onSave: (data) async {
          try {
            await FirestoreService.updateArtist(artistId, data);
            if (mounted) Navigator.pop(context);
            _loadData();
          } catch (e) {
            debugPrint('Error updating artist profile: $e');
          }
        },
      ),
    );
  }

  void _openUploadSheet({Song? song}) {
    final artistId = context.read<UserProvider>().artistId;
    if (artistId == null || _artist == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SongUploadSheet(
        song: song,
        onSave: (data) async {
          try {
            if (song == null) {
              await FirestoreService.createSong(
                title: data['title'],
                artists: [_artist!.name],
                artistIds: [artistId],
                coverUrl: data['coverUrl'],
                audioUrl: data['audioUrl'],
                genres: List<String>.from(data['genres'] ?? []),
              );
            } else {
              await FirestoreService.updateSong(song.id, {
                'title': data['title'],
                'coverUrl': data['coverUrl'],
                'audioUrl': data['audioUrl'],
                'genres': data['genres'],
              });
            }
            if (mounted) Navigator.pop(context);
            _loadData();
          } catch (e) {
            debugPrint('Error saving song: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài hát'),
        content: Text('Bạn có chắc muốn xóa "${song.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteSong(song.id);
      _loadData();
    }
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
        title: const Text('Trang nghệ sĩ',
            style: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: (_isLoading || _artist == null) ? null : _openProfileEdit,
            icon: const Icon(Icons.edit_rounded, color: _darkText),
            tooltip: 'Chỉnh sửa hồ sơ',
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh_rounded, color: _darkText)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isLoading || _artist == null) ? null : _showCreateMenu,
        backgroundColor: _mintGreen,
        icon: const Icon(Icons.upload_rounded, color: Colors.white),
        label: const Text('Đăng nhạc', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mintGreen))
          : _artist == null
              ? const Center(child: Text('Không tìm thấy hồ sơ nghệ sĩ'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildStats(),
                      const SizedBox(height: 24),
                      const Text('Bài hát của bạn',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkText)),
                      const SizedBox(height: 12),
                      if (_songs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('Chưa có bài hát nào. Nhấn "Đăng nhạc" để bắt đầu!'),
                        )
                      else
                        ..._songs.map((s) => _SongTile(
                              song: s,
                              onEdit: () => _openUploadSheet(song: s),
                              onDelete: () => _deleteSong(s),
                              onLyrics: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LyricsEditorScreen(song: s),
                                ),
                              ),
                            )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final a = _artist!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_mintGreen, _darkText]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white24,
            backgroundImage: (a.avatarUrl != null && a.avatarUrl!.isNotEmpty)
                ? NetworkImage(a.avatarUrl!)
                : null,
            child: (a.avatarUrl == null || a.avatarUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white, size: 36)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    if (a.isVerified == true) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.white, size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (a.bio != null && a.bio!.isNotEmpty)
                  Text(a.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(child: _statCard(Icons.library_music_rounded, '${_songs.length}', 'Bài hát')),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.people_rounded, '${_artist!.followerCount ?? 0}', 'Follower')),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.headphones_rounded, '${_artist!.monthlyListeners ?? 0}', 'Lượt nghe')),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _mintGreen, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkText)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLyrics;

  const _SongTile({
    required this.song,
    required this.onEdit,
    required this.onDelete,
    required this.onLyrics,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _mintGreen.withOpacity(0.1),
            image: (song.coverUrl != null && song.coverUrl!.isNotEmpty)
                ? DecorationImage(image: NetworkImage(song.coverUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: (song.coverUrl == null || song.coverUrl!.isEmpty)
              ? const Icon(Icons.music_note_rounded, color: _mintGreen)
              : null,
        ),
        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(song.genres.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onLyrics,
              icon: const Icon(Icons.lyrics_outlined, color: Colors.deepPurpleAccent),
              tooltip: 'Lời bài hát',
            ),
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _ArtistProfileEditSheet extends StatefulWidget {
  final Artist artist;
  final Function(Map<String, dynamic>) onSave;
  const _ArtistProfileEditSheet({required this.artist, required this.onSave});

  @override
  State<_ArtistProfileEditSheet> createState() => _ArtistProfileEditSheetState();
}

class _ArtistProfileEditSheetState extends State<_ArtistProfileEditSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _socialController;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  List<Genre> _allGenres = [];
  final Set<String> _selectedGenres = {};
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artist.name);
    _bioController = TextEditingController(text: widget.artist.bio ?? '');
    _socialController = TextEditingController(text: widget.artist.socialLinks ?? '');
    _avatarUrl = widget.artist.avatarUrl;
    _selectedGenres.addAll(widget.artist.genres ?? const []);
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await FirestoreService.getGenres(limit: 50);
    if (mounted) {
      setState(() {
        _allGenres = genres;
        _loadingGenres = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingAvatar = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (mounted) {
        setState(() {
          if (url != null) _avatarUrl = url;
          _isUploadingAvatar = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chỉnh sửa hồ sơ nghệ sĩ',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _isUploadingAvatar ? null : _pickAvatar,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _mintGreen.withOpacity(0.1),
                    image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _isUploadingAvatar
                      ? const Center(child: CircularProgressIndicator())
                      : (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? const Icon(Icons.add_a_photo_rounded, color: _mintGreen, size: 30)
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên nghệ sĩ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Giới thiệu / Bio', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _socialController,
              decoration: const InputDecoration(
                  labelText: 'Link mạng xã hội', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Thể loại nhạc', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_loadingGenres)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_allGenres.isEmpty)
              const Text('Chưa có thể loại nào', style: TextStyle(color: Colors.black54))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allGenres.map((g) {
                  final selected = _selectedGenres.contains(g.name);
                  return FilterChip(
                    label: Text(g.name),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedGenres.add(g.name);
                        } else {
                          _selectedGenres.remove(g.name);
                        }
                      });
                    },
                    selectedColor: _mintGreen.withOpacity(0.2),
                    checkmarkColor: _mintGreen,
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUploadingAvatar || _isSaving)
                    ? null
                    : () {
                        if (_nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên nghệ sĩ')),
                          );
                          return;
                        }
                        setState(() => _isSaving = true);
                        widget.onSave({
                          'name': _nameController.text.trim(),
                          'bio': _bioController.text.trim(),
                          'avatarUrl': _avatarUrl ?? '',
                          'socialLinks': _socialController.text.trim(),
                          'genres': _selectedGenres.toList(),
                        });
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _mintGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('LƯU HỒ SƠ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongUploadSheet extends StatefulWidget {
  final Song? song;
  final Function(Map<String, dynamic>) onSave;
  const _SongUploadSheet({this.song, required this.onSave});

  @override
  State<_SongUploadSheet> createState() => _SongUploadSheetState();
}

class _SongUploadSheetState extends State<_SongUploadSheet> {
  late TextEditingController _titleController;
  late TextEditingController _genresController;
  String? _coverUrl;
  String? _audioUrl;
  bool _isUploadingCover = false;
  bool _isUploadingAudio = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _genresController = TextEditingController(text: widget.song?.genres.join(', ') ?? '');
    _coverUrl = widget.song?.coverUrl;
    _audioUrl = widget.song?.audioUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _genresController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingCover = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (mounted) setState(() {
        if (url != null) _coverUrl = url;
        _isUploadingCover = false;
      });
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioVideoExts,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final rawName = result.files.single.name;
    final dot = rawName.lastIndexOf('.');
    final baseName = dot > 0 ? rawName.substring(0, dot) : rawName;

    // Lấy luôn tên bài từ file nhạc (nếu chưa nhập).
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = baseName;
    }

    setState(() => _isUploadingAudio = true);
    final url = await CloudinaryService.uploadFile(File(path), isAudio: true);
    if (mounted) {
      setState(() {
        if (url != null) _audioUrl = url;
        _isUploadingAudio = false;
      });
    }

    // Nếu có ảnh đi kèm cùng thư mục (cùng tên) và chưa chọn ảnh -> lấy luôn.
    if (_coverUrl == null || _coverUrl!.isEmpty) {
      await _tryPickSiblingCover(path);
    }
  }

  Future<void> _tryPickSiblingCover(String audioPath) async {
    final sep = audioPath.contains('\\') ? '\\' : '/';
    final slash = audioPath.lastIndexOf(sep);
    if (slash < 0) return;
    final dir = audioPath.substring(0, slash);
    final fileName = audioPath.substring(slash + 1);
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;

    for (final ext in const ['.jpg', '.jpeg', '.png', '.webp']) {
      final candidate = File('$dir$sep$base$ext');
      if (candidate.existsSync()) {
        setState(() => _isUploadingCover = true);
        final url = await CloudinaryService.uploadFile(candidate);
        if (mounted) {
          setState(() {
            if (url != null) _coverUrl = url;
            _isUploadingCover = false;
          });
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.song == null ? 'Đăng bài hát mới' : 'Sửa bài hát',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Tên bài hát', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Ảnh bìa', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCover,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  image: (_coverUrl != null && _coverUrl!.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _isUploadingCover
                    ? const Center(child: CircularProgressIndicator())
                    : (_coverUrl == null || _coverUrl!.isEmpty)
                        ? const Icon(Icons.add_a_photo)
                        : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text('File nhạc', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              onTap: _pickAudio,
              tileColor: _mintGreen.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(_audioUrl != null ? Icons.check_circle : Icons.audiotrack,
                  color: _audioUrl != null ? Colors.green : _mintGreen),
              title: Text(_isUploadingAudio
                  ? 'Đang tải lên...'
                  : (_audioUrl != null ? 'Đã tải lên file nhạc' : 'Chọn file nhạc / video (mp3, mp4...)')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genresController,
              decoration: const InputDecoration(
                  labelText: 'Thể loại (phân cách bằng dấu phẩy)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUploadingCover || _isUploadingAudio)
                    ? null
                    : () {
                        if (_titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên bài hát')),
                          );
                          return;
                        }
                        if (_audioUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng tải lên file nhạc')),
                          );
                          return;
                        }
                        final genres = _genresController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        widget.onSave({
                          'title': _titleController.text.trim(),
                          'coverUrl': _coverUrl ?? '',
                          'audioUrl': _audioUrl ?? '',
                          'genres': genres,
                        });
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _mintGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('LƯU BÀI HÁT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
