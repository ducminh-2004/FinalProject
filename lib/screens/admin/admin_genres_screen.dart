import 'package:flutter/material.dart';
import '../../models/genre.dart';
import '../../firebase/firestore_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

class AdminGenresScreen extends StatefulWidget {
  const AdminGenresScreen({super.key});

  @override
  State<AdminGenresScreen> createState() => _AdminGenresScreenState();
}

class _AdminGenresScreenState extends State<AdminGenresScreen> {
  List<Genre> _genres = [];
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    setState(() => _isLoading = true);
    try {
      _genres = await FirestoreService.getGenres(limit: 100);
    } catch (e) {
      debugPrint('Error loading genres: $e');
      _genres = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _darkText, size: 20),
        ),
        title: const Text(
          'Quản lý thể loại',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadGenres,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGenreDialog(context),
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Thêm thể loại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _genres.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadGenres,
                  color: _primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: _genres.length,
                    itemBuilder: (context, index) {
                      return _GenreTile(
                        genre: _genres[index],
                        onEdit: () => _showGenreDialog(context, genre: _genres[index]),
                        onDelete: () => _deleteGenre(_genres[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Chưa có thể loại nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showGenreDialog(BuildContext context, {Genre? genre}) {
    showDialog(
      context: context,
      builder: (context) => _GenreDialog(
        genre: genre,
        onSave: (name, colorValue, description, imageUrl) async {
          try {
            if (genre == null) {
              await FirestoreService.createGenre(
                name: name,
                colorValue: colorValue,
                description: description,
                imageUrl: imageUrl,
              );
            } else {
              await FirestoreService.updateGenre(genre.id, {
                'name': name,
                'colorValue': colorValue,
                'description': description,
                'imageUrl': imageUrl,
              });
            }
            await _loadGenres();
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteGenre(Genre genre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xóa thể loại', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Bạn có chắc muốn xóa thể loại "${genre.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.4), fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Xóa ngay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirestoreService.deleteGenre(genre.id);
      await _loadGenres();
    }
  }
}

class _GenreTile extends StatelessWidget {
  final Genre genre;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GenreTile({required this.genre, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF0A1F1A).withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: genre.color,
                      borderRadius: BorderRadius.circular(14),
                      image: genre.imageUrl != null && genre.imageUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(genre.imageUrl!), fit: BoxFit.cover) : null,
                    ),
                    child: genre.imageUrl == null || genre.imageUrl!.isEmpty ? const Icon(Icons.category_rounded, color: Colors.white, size: 24) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(genre.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A))),
                        if (genre.description != null && genre.description!.isNotEmpty)
                          Text(genre.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: const Color(0xFF0A1F1A).withOpacity(0.4), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(icon: Icons.edit_rounded, color: Colors.blueAccent, onTap: onEdit),
                      const SizedBox(width: 8),
                      _ActionButton(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: onDelete),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.onTap});
  @override Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)));
  }
}

class _GenreDialog extends StatefulWidget {
  final Genre? genre; final Function(String name, int colorValue, String description, String imageUrl) onSave;
  const _GenreDialog({this.genre, required this.onSave});
  @override State<_GenreDialog> createState() => _GenreDialogState();
}

class _GenreDialogState extends State<_GenreDialog> {
  late TextEditingController _nameController; late TextEditingController _descriptionController; late int _selectedColor; String? _currentImageUrl; bool _isUploading = false;
  final List<int> _suggestedColors = [0xFF1DB954, 0xFFE13300, 0xFF8D67AB, 0xFFDC148C, 0xFF006450, 0xFF1E3264, 0xFFE8115B, 0xFFF037A5];
  @override void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.genre?.name ?? '');
    _descriptionController = TextEditingController(text: widget.genre?.description ?? '');
    _selectedColor = widget.genre?.colorValue ?? 0xFF1DB954;
    _currentImageUrl = widget.genre?.imageUrl;
  }
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker(); final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final url = await CloudinaryService.uploadImage(File(image.path));
        if (url != null) setState(() => _currentImageUrl = url);
      } finally { setState(() => _isUploading = false); }
    }
  }
  @override Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.genre == null ? 'Thêm thể loại' : 'Sửa thể loại', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildField('Tên thể loại', _nameController), const SizedBox(height: 16),
        _buildField('Mô tả', _descriptionController, maxLines: 2), const SizedBox(height: 24),
        const Text('Hình ảnh thể loại', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A1F1A))), const SizedBox(height: 12),
        GestureDetector(onTap: _isUploading ? null : _pickAndUploadImage, child: Container(height: 140, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF0A1F1A).withOpacity(0.03), borderRadius: BorderRadius.circular(20), image: _currentImageUrl != null ? DecorationImage(image: NetworkImage(_currentImageUrl!), fit: BoxFit.cover) : null, border: Border.all(color: const Color(0xFF0A1F1A).withOpacity(0.05))), child: _isUploading ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) : _currentImageUrl == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_rounded, size: 32, color: const Color(0xFF0A1F1A).withOpacity(0.2)), const SizedBox(height: 8), Text('Tải ảnh lên', style: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.bold))]) : null)),
        const SizedBox(height: 24),
        const Text('Màu sắc nhận diện', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A1F1A))), const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: _suggestedColors.map((colorVal) => GestureDetector(onTap: () => setState(() => _selectedColor = colorVal), child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Color(colorVal), shape: BoxShape.circle, border: _selectedColor == colorVal ? Border.all(color: const Color(0xFF0A1F1A), width: 3) : Border.all(color: Colors.white, width: 2), boxShadow: [if (_selectedColor == colorVal) BoxShadow(color: Color(colorVal).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]), child: _selectedColor == colorVal ? const Icon(Icons.check, size: 18, color: Colors.white) : null))).toList()),
      ])),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.4), fontWeight: FontWeight.bold))),
        ElevatedButton(onPressed: _isUploading ? null : () { if (_nameController.text.isNotEmpty) { widget.onSave(_nameController.text, _selectedColor, _descriptionController.text.trim(), _currentImageUrl ?? ''); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0E6B5A), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
    );
  }
  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A1F1A))), const SizedBox(height: 8), Container(decoration: BoxDecoration(color: const Color(0xFF0A1F1A).withOpacity(0.03), borderRadius: BorderRadius.circular(16)), child: TextField(controller: controller, maxLines: maxLines, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14))))]);
}
