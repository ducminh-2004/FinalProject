import 'package:flutter/material.dart';
import '../../models/genre.dart';
import '../../firebase/firestore_service.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminGenresScreen extends StatefulWidget {
  const AdminGenresScreen({super.key});

  @override
  State<AdminGenresScreen> createState() => _AdminGenresScreenState();
}

class _AdminGenresScreenState extends State<AdminGenresScreen> {
  List<Genre> _genres = [];
  bool _isLoading = true;

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
          'Quản lý thể loại',
          style: TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadGenres,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGenreDialog(context),
        backgroundColor: _mintGreen,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _genres.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 64,
                        color: _darkText.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      const Text('Chưa có thể loại nào'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _genres.length,
                  itemBuilder: (context, index) {
                    final genre = _genres[index];
                    return _GenreTile(
                      genre: genre,
                      onEdit: () => _showGenreDialog(context, genre: genre),
                      onDelete: () => _deleteGenre(genre),
                    );
                  },
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
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(genre == null ? 'Đã thêm thể loại' : 'Đã cập nhật thể loại')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteGenre(Genre genre) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thể loại'),
        content: Text('Bạn có chắc muốn xóa thể loại "${genre.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirestoreService.deleteGenre(genre.id);
        await _loadGenres();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
          );
        }
      }
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: genre.color,
            borderRadius: BorderRadius.circular(8),
            image: genre.imageUrl != null && genre.imageUrl!.isNotEmpty
                ? DecorationImage(image: NetworkImage(genre.imageUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: genre.imageUrl == null || genre.imageUrl!.isEmpty
              ? const Icon(Icons.category_rounded, color: Colors.white)
              : null,
        ),
        title: Text(
          genre.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (genre.description != null && genre.description!.isNotEmpty)
              Text(
                genre.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            Text(
              'Hex: #${genre.colorValue.toRadixString(16).toUpperCase()}',
              style: TextStyle(fontSize: 10, color: _darkText.withValues(alpha: 0.5)),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
            IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _GenreDialog extends StatefulWidget {
  final Genre? genre;
  final Function(String name, int colorValue, String description, String imageUrl) onSave;

  const _GenreDialog({this.genre, required this.onSave});

  @override
  State<_GenreDialog> createState() => _GenreDialogState();
}

class _GenreDialogState extends State<_GenreDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late int _selectedColor;
  String? _currentImageUrl;
  bool _isUploading = false;

  final List<int> _suggestedColors = [
    0xFF1DB954, // Green
    0xFFE13300, // Red
    0xFF8D67AB, // Purple
    0xFFDC148C, // Pink
    0xFF006450, // Dark Green
    0xFF1E3264, // Dark Blue
    0xFFE8115B, // Rose
    0xFFF037A5, // Magenta
    0xFFE91E63, // Pink
    0xFF2196F3, // Blue
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFEB3B, // Yellow
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF9E9E9E, // Grey
    0xFF607D8B, // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.genre?.name ?? '');
    _descriptionController = TextEditingController(text: widget.genre?.description ?? '');
    _selectedColor = widget.genre?.colorValue ?? 0xFF1DB954;
    _currentImageUrl = widget.genre?.imageUrl;
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final url = await CloudinaryService.uploadImage(File(image.path));
        if (url != null) {
          setState(() => _currentImageUrl = url);
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.genre == null ? 'Thêm thể loại' : 'Sửa thể loại'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên thể loại'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Ví dụ: Những bài hát nhẹ nhàng...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            const Text('Ảnh thể loại:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _isUploading ? null : _pickAndUploadImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _currentImageUrl != null
                      ? DecorationImage(image: NetworkImage(_currentImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentImageUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey),
                              Text('Nhấn để tải ảnh lên', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Chọn màu nền (dự phòng):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.maxFinite,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedColors.map((colorVal) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: _selectedColor == colorVal
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                      child: _selectedColor == colorVal
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isUploading
              ? null
              : () {
                  if (_nameController.text.isNotEmpty) {
                    widget.onSave(
                      _nameController.text,
                      _selectedColor,
                      _descriptionController.text.trim(),
                      _currentImageUrl ?? '',
                    );
                    Navigator.pop(context);
                  }
                },
          style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
