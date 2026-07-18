import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/artist.dart';
import '../../firebase/firestore_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminArtistsScreen extends StatefulWidget {
  const AdminArtistsScreen({super.key});

  @override
  State<AdminArtistsScreen> createState() => _AdminArtistsScreenState();
}

class _AdminArtistsScreenState extends State<AdminArtistsScreen> {
  List<Artist> _artists = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    setState(() => _isLoading = true);
    try {
      _artists = await FirestoreService.getArtists(limit: 100);
    } catch (e) {
      debugPrint('Error loading artists: $e');
      _artists = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Artist> get _filteredArtists {
    if (_searchQuery.isEmpty) return _artists;
    return _artists.where((artist) {
      return artist.name.toLowerCase().contains(_searchQuery.toLowerCase());
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
          'Quản lý nghệ sĩ',
          style: TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadArtists,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showArtistDialog(context),
        backgroundColor: const Color(0xFFE13300),
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
                hintText: 'Tìm kiếm nghệ sĩ...',
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
                  label: 'Tổng nghệ sĩ',
                  value: _artists.length.toString(),
                  color: const Color(0xFFE13300),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Đã xác minh',
                  value: _artists.where((a) => a.isVerified ?? false).length.toString(),
                  color: Colors.blue,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Artist list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredArtists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_rounded,
                              size: 64,
                              color: _darkText.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy nghệ sĩ',
                              style: TextStyle(
                                color: _darkText.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadArtists,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredArtists.length,
                          itemBuilder: (context, index) {
                            return _ArtistTile(
                              artist: _filteredArtists[index],
                              onEdit: () => _showArtistDialog(context, artist: _filteredArtists[index]),
                              onDelete: () => _deleteArtist(_filteredArtists[index]),
                              onToggleVerify: () => _toggleVerify(_filteredArtists[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showArtistDialog(BuildContext context, {Artist? artist}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ArtistFormSheet(
        artist: artist,
        onSave: (data) async {
          try {
            if (artist == null) {
              await FirestoreService.createArtist(
                name: data['name'],
                avatarUrl: data['avatarUrl'],
                bio: data['bio'],
                genres: List<String>.from(data['genres'] ?? []),
              );
            } else {
              await FirestoreService.updateArtist(artist.id, data);
            }
            await _loadArtists();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(artist == null ? 'Đã thêm nghệ sĩ' : 'Đã cập nhật nghệ sĩ'),
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

  Future<void> _deleteArtist(Artist artist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFE13300)),
            SizedBox(width: 8),
            Text('Xóa nghệ sĩ'),
          ],
        ),
        content: Text('Bạn có chắc muốn xóa nghệ sĩ "${artist.name}"?'),
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
        await FirestoreService.deleteArtist(artist.id);
        await _loadArtists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa nghệ sĩ'),
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

  Future<void> _toggleVerify(Artist artist) async {
    try {
      await FirestoreService.updateArtist(artist.id, {
        'isVerified': !(artist.isVerified ?? false),
      });
      await _loadArtists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((artist.isVerified ?? false) ? 'Đã hủy xác minh' : 'Đã xác minh nghệ sĩ'),
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

class _ArtistTile extends StatelessWidget {
  final Artist artist;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVerify;

  const _ArtistTile({
    required this.artist,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVerify,
  });

  String _formatNumber(int? number) {
    if (number == null) return '0';
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

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
            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFE13300).withValues(alpha: 0.1),
              backgroundImage: artist.avatarUrl != null
                  ? NetworkImage(artist.avatarUrl!)
                  : null,
              child: artist.avatarUrl == null
                  ? Text(
                      artist.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFE13300),
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Info
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
                          style: const TextStyle(
                            color: Color(0xFF0A1F1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (artist.isVerified ?? false) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.headphones_rounded,
                        size: 14,
                        color: const Color(0xFF0A1F1A).withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatNumber(artist.monthlyListeners)} người nghe/tháng',
                        style: TextStyle(
                          color: const Color(0xFF0A1F1A).withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if ((artist.genres ?? []).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: (artist.genres ?? []).take(2).map((g) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE13300).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          g,
                          style: const TextStyle(
                            color: Color(0xFFE13300),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'verify') onToggleVerify();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Sửa'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'verify',
                  child: Row(
                    children: [
                      Icon(
                        (artist.isVerified ?? false) ? Icons.remove_moderator : Icons.verified_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text((artist.isVerified ?? false) ? 'Hủy xác minh' : 'Xác minh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Color(0xFFE13300)),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Color(0xFFE13300))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistFormSheet extends StatefulWidget {
  final Artist? artist;
  final Function(Map<String, dynamic>) onSave;

  const _ArtistFormSheet({this.artist, required this.onSave});

  @override
  State<_ArtistFormSheet> createState() => _ArtistFormSheetState();
}

class _ArtistFormSheetState extends State<_ArtistFormSheet> {
  late TextEditingController _nameController;
  String? _avatarUrl;
  late TextEditingController _bioController;
  late TextEditingController _genresController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artist?.name ?? '');
    _avatarUrl = widget.artist?.avatarUrl;
    _bioController = TextEditingController(text: widget.artist?.bio ?? '');
    _genresController = TextEditingController(
      text: (widget.artist?.genres ?? []).join(', ') ?? '',
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (url != null) setState(() => _avatarUrl = url);
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _genresController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.artist != null;

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
              isEditing ? 'Sửa nghệ sĩ' : 'Thêm nghệ sĩ mới',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A1F1A),
              ),
            ),
            const SizedBox(height: 20),

            _buildTextField('Tên nghệ sĩ', _nameController, isRequired: true),
            const SizedBox(height: 12),
            const Text('Avatar nghệ sĩ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[100],
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _isUploading 
                    ? const CircularProgressIndicator() 
                    : _avatarUrl == null ? const Icon(Icons.add_a_photo_rounded, color: Colors.grey) : null,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField('Tiểu sử', _bioController, maxLines: 3),
            const SizedBox(height: 12),
            _buildTextField('Thể loại (phân cách bằng dấu phẩy)', _genresController),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE13300),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Lưu thay đổi' : 'Thêm nghệ sĩ',
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
      {bool isRequired = false, int maxLines = 1}) {
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
          maxLines: maxLines,
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nghệ sĩ'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE13300),
        ),
      );
      return;
    }

    final genres = _genresController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    widget.onSave({
      'name': _nameController.text.trim(),
      'avatarUrl': _avatarUrl ?? '',
      'bio': _bioController.text.trim(),
      'genres': genres,
    });
  }
}
