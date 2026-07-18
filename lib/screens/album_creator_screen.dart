import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/artist.dart';
import '../firebase/firestore_service.dart';
import '../services/cloudinary_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);
const _albumPurple = Color(0xFF8D67AB);

// Cho phép chọn cả file nhạc lẫn video (mp4) — chỉ lấy âm thanh khi upload.
const _audioVideoExts = ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'mp4', 'm4v', 'mov', 'webm'];

/// Shared album creator used by both the artist dashboard and the admin panel.
/// When [fixedArtistId] / [fixedArtistName] are provided (artist flow) the
/// artist is locked; otherwise (admin flow) an artist can be picked.
class AlbumCreatorScreen extends StatefulWidget {
  final String? fixedArtistId;
  final String? fixedArtistName;

  const AlbumCreatorScreen({
    super.key,
    this.fixedArtistId,
    this.fixedArtistName,
  });

  @override
  State<AlbumCreatorScreen> createState() => _AlbumCreatorScreenState();
}

class _AlbumCreatorScreenState extends State<AlbumCreatorScreen> {
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();

  String? _albumCoverUrl;
  bool _isUploadingCover = false;
  bool _isSaving = false;

  // Admin-only artist selection
  List<Artist> _artists = [];
  Artist? _selectedArtist;
  bool _loadingArtists = false;

  final List<_SongDraft> _drafts = [_SongDraft()];

  bool get _isArtistLocked => widget.fixedArtistId != null;

  @override
  void initState() {
    super.initState();
    if (!_isArtistLocked) _loadArtists();
  }

  Future<void> _loadArtists() async {
    setState(() => _loadingArtists = true);
    final artists = await FirestoreService.getArtists(limit: 200);
    if (mounted) {
      setState(() {
        _artists = artists;
        _loadingArtists = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAlbumCover() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingCover = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (mounted) {
        setState(() {
          if (url != null) _albumCoverUrl = url;
          _isUploadingCover = false;
        });
      }
    }
  }

  void _addDraft() {
    setState(() => _drafts.add(_SongDraft()));
  }

  void _removeDraft(int index) {
    setState(() {
      _drafts[index].dispose();
      _drafts.removeAt(index);
    });
  }

  bool get _isBusy {
    if (_isUploadingCover || _isSaving) return true;
    return _drafts.any((d) => d.isUploadingCover || d.isUploadingAudio);
  }

  Future<void> _save() async {
    final artistName = _isArtistLocked ? widget.fixedArtistName : _selectedArtist?.name;
    final artistId = _isArtistLocked ? widget.fixedArtistId : _selectedArtist?.id;

    if (_titleController.text.trim().isEmpty) {
      _snack('Vui lòng nhập tên album');
      return;
    }
    if (artistName == null || artistName.isEmpty) {
      _snack('Vui lòng chọn nghệ sĩ');
      return;
    }
    final validDrafts = _drafts.where((d) => d.titleController.text.trim().isNotEmpty).toList();
    if (validDrafts.isEmpty) {
      _snack('Album cần ít nhất một bài hát có tên');
      return;
    }
    if (validDrafts.any((d) => d.audioUrl == null)) {
      _snack('Mỗi bài hát cần được tải lên file nhạc');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final songs = validDrafts.map((d) {
        return {
          'title': d.titleController.text.trim(),
          'coverUrl': d.coverUrl ?? '',
          'audioUrl': d.audioUrl ?? '',
          'genres': d.genresController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        };
      }).toList();

      await FirestoreService.createAlbumWithSongs(
        title: _titleController.text.trim(),
        artist: artistName,
        artistId: artistId,
        coverUrl: _albumCoverUrl,
        releaseYear: _yearController.text.trim().isEmpty ? null : _yearController.text.trim(),
        songs: songs,
      );

      if (mounted) {
        Navigator.pop(context, true);
        _snack('Đã tạo album "${_titleController.text.trim()}" với ${songs.length} bài hát');
      }
    } catch (e) {
      debugPrint('Error creating album: $e');
      if (mounted) _snack('Tạo album thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
        title: const Text('Tạo album',
            style: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.w800)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _albumPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('TẠO ALBUM (${_drafts.length} bài)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAlbumSection(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Danh sách bài hát',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkText)),
              Text('${_drafts.length} bài',
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_drafts.length, (i) => _buildSongCard(i)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addDraft,
            icon: const Icon(Icons.add_rounded, color: _mintGreen),
            label: const Text('Thêm bài hát', style: TextStyle(color: _mintGreen)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _mintGreen),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAlbumSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông tin album',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkText)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _isUploadingCover ? null : _pickAlbumCover,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: _albumPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    image: (_albumCoverUrl != null && _albumCoverUrl!.isNotEmpty)
                        ? DecorationImage(image: NetworkImage(_albumCoverUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _isUploadingCover
                      ? const Center(child: CircularProgressIndicator())
                      : (_albumCoverUrl == null || _albumCoverUrl!.isEmpty)
                          ? const Icon(Icons.add_photo_alternate_rounded,
                              color: _albumPurple, size: 36)
                          : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _field('Tên album', _titleController),
                    const SizedBox(height: 12),
                    _field('Năm phát hành', _yearController,
                        keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildArtistSelector(),
        ],
      ),
    );
  }

  Widget _buildArtistSelector() {
    if (_isArtistLocked) {
      return Row(
        children: [
          const Icon(Icons.person, size: 18, color: _mintGreen),
          const SizedBox(width: 8),
          Text('Nghệ sĩ: ${widget.fixedArtistName}',
              style: const TextStyle(fontWeight: FontWeight.w600, color: _darkText)),
        ],
      );
    }
    if (_loadingArtists) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    return DropdownButtonFormField<Artist>(
      initialValue: _selectedArtist,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Nghệ sĩ',
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
      items: _artists
          .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
          .toList(),
      onChanged: (a) => setState(() => _selectedArtist = a),
    );
  }

  Widget _buildSongCard(int index) {
    final d = _drafts[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _albumPurple.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: _albumPurple)),
                ),
                const SizedBox(width: 8),
                const Text('Bài hát', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_drafts.length > 1)
                  IconButton(
                    onPressed: () => _removeDraft(index),
                    icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: d.isUploadingCover ? null : () => _pickSongCover(index),
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: _mintGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      image: (d.coverUrl != null && d.coverUrl!.isNotEmpty)
                          ? DecorationImage(image: NetworkImage(d.coverUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: d.isUploadingCover
                        ? const Center(
                            child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : (d.coverUrl == null || d.coverUrl!.isEmpty)
                            ? const Icon(Icons.image_outlined, color: _mintGreen)
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _field('Tên bài hát', d.titleController),
                      const SizedBox(height: 8),
                      _field('Thể loại (phân cách dấu phẩy)', d.genresController),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Ảnh riêng của bài (để trống sẽ dùng ảnh album)',
                style: TextStyle(fontSize: 11, color: Colors.black45)),
            const SizedBox(height: 8),
            ListTile(
              onTap: d.isUploadingAudio ? null : () => _pickSongAudio(index),
              dense: true,
              tileColor: _mintGreen.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: Icon(d.audioUrl != null ? Icons.check_circle : Icons.audiotrack,
                  color: d.audioUrl != null ? Colors.green : _mintGreen),
              title: Text(
                d.isUploadingAudio
                    ? 'Đang tải lên...'
                    : (d.audioUrl != null ? 'Đã tải lên file nhạc' : 'Chọn file nhạc / video (mp3, mp4...)'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSongCover(int index) async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _drafts[index].isUploadingCover = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (mounted) {
        setState(() {
          if (url != null) _drafts[index].coverUrl = url;
          _drafts[index].isUploadingCover = false;
        });
      }
    }
  }

  Future<void> _pickSongAudio(int index) async {
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
    if (_drafts[index].titleController.text.trim().isEmpty) {
      _drafts[index].titleController.text = baseName;
    }

    setState(() => _drafts[index].isUploadingAudio = true);
    final url = await CloudinaryService.uploadFile(File(path), isAudio: true);
    if (mounted) {
      setState(() {
        if (url != null) _drafts[index].audioUrl = url;
        _drafts[index].isUploadingAudio = false;
      });
    }

    // Ảnh đi kèm cùng thư mục (cùng tên) -> lấy luôn nếu chưa chọn ảnh.
    if (_drafts[index].coverUrl == null || _drafts[index].coverUrl!.isEmpty) {
      await _tryPickSiblingCover(index, path);
    }
  }

  Future<void> _tryPickSiblingCover(int index, String audioPath) async {
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
        setState(() => _drafts[index].isUploadingCover = true);
        final url = await CloudinaryService.uploadFile(candidate);
        if (mounted) {
          setState(() {
            if (url != null) _drafts[index].coverUrl = url;
            _drafts[index].isUploadingCover = false;
          });
        }
        return;
      }
    }
  }

  Widget _field(String label, TextEditingController controller,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF7F9F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SongDraft {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController genresController = TextEditingController();
  String? coverUrl;
  String? audioUrl;
  bool isUploadingCover = false;
  bool isUploadingAudio = false;

  void dispose() {
    titleController.dispose();
    genresController.dispose();
  }
}
