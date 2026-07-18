import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/album.dart';
import '../../firebase/firestore_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminAlbumsScreen extends StatefulWidget {
  const AdminAlbumsScreen({super.key});

  @override
  State<AdminAlbumsScreen> createState() => _AdminAlbumsScreenState();
}

class _AdminAlbumsScreenState extends State<AdminAlbumsScreen> {
  List<Album> _albums = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    try {
      _albums = await FirestoreService.getAlbums(limit: 100);
    } catch (e) {
      debugPrint('Error loading albums: $e');
      _albums = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Album> get _filteredAlbums {
    if (_searchQuery.isEmpty) return _albums;
    return _albums.where((album) {
      return album.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             album.artist.toLowerCase().contains(_searchQuery.toLowerCase());
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
          'Quản lý album',
          style: TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAlbums,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAlbumDialog(context),
        backgroundColor: const Color(0xFF8D67AB),
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
                hintText: 'Tìm kiếm album...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatChip(
                  label: 'Tổng album',
                  value: _albums.length.toString(),
                  color: const Color(0xFF8D67AB),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Album list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAlbums.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.album_rounded,
                              size: 64,
                              color: _darkText.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy album',
                              style: TextStyle(
                                color: _darkText.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAlbums,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAlbums.length,
                          itemBuilder: (context, index) {
                            return _AlbumTile(
                              album: _filteredAlbums[index],
                              onEdit: () => _showAlbumDialog(context, album: _filteredAlbums[index]),
                              onDelete: () => _deleteAlbum(_filteredAlbums[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAlbumDialog(BuildContext context, {Album? album}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlbumFormSheet(
        album: album,
        onSave: (data) async {
          try {
            if (album == null) {
              await FirestoreService.createAlbum(
                title: data['title'],
                artist: data['artist'],
                coverUrl: data['coverUrl'],
              );
            } else {
              await FirestoreService.updateAlbum(album.id, data);
            }
            await _loadAlbums();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(album == null ? 'Đã thêm album' : 'Đã cập nhật album'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Lỗi: $e'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFFE13300),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFE13300)),
            SizedBox(width: 8),
            Text('Xóa album'),
          ],
        ),
        content: Text('Bạn có chắc muốn xóa album "${album.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE13300),
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.deleteAlbum(album.id);
        await _loadAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa album'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFE13300),
            ),
          );
        }
      }
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final Album album;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AlbumTile({
    required this.album,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Cover
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF8D67AB).withValues(alpha: 0.1),
              ),
              child: album.coverUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        album.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.album_rounded,
                          color: Color(0xFF8D67AB),
                          size: 32,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.album_rounded,
                      color: Color(0xFF8D67AB),
                      size: 32,
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A1F1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${album.songs.length} bài hát',
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE13300),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumFormSheet extends StatefulWidget {
  final Album? album;
  final Function(Map<String, dynamic>) onSave;

  const _AlbumFormSheet({this.album, required this.onSave});

  @override
  State<_AlbumFormSheet> createState() => _AlbumFormSheetState();
}

class _AlbumFormSheetState extends State<_AlbumFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  String? _coverUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.album?.title ?? '');
    _artistController = TextEditingController(text: widget.album?.artist ?? '');
    _coverUrl = widget.album?.coverUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (url != null) setState(() => _coverUrl = url);
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.album != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F1A).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Sửa album' : 'Thêm album mới',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A1F1A),
              ),
            ),
            const SizedBox(height: 20),

            _buildTextField('Tên album', _titleController, isRequired: true),
            const SizedBox(height: 12),
            _buildTextField('Nghệ sĩ', _artistController, isRequired: true),
            const SizedBox(height: 12),
            const Text('Ảnh bìa album', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  image: _coverUrl != null ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover) : null,
                ),
                child: _isUploading 
                    ? const Center(child: CircularProgressIndicator()) 
                    : _coverUrl == null ? const Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 40) : null,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D67AB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Lưu thay đổi' : 'Thêm album',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0A1F1A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Color(0xFFE13300)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF7F9F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _save() {
    if (_titleController.text.trim().isEmpty ||
        _artistController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền tên album và nghệ sĩ'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE13300),
        ),
      );
      return;
    }

    widget.onSave({
      'title': _titleController.text.trim(),
      'artist': _artistController.text.trim(),
      'coverUrl': _coverUrl ?? '',
    });
  }
}
