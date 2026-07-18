import 'package:flutter/material.dart';
import '../../models/playlist.dart';
import '../../firebase/firestore_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminPlaylistsScreen extends StatefulWidget {
  const AdminPlaylistsScreen({super.key});

  @override
  State<AdminPlaylistsScreen> createState() => _AdminPlaylistsScreenState();
}

class _AdminPlaylistsScreenState extends State<AdminPlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _isLoading = true);
    try {
      _playlists = await FirestoreService.getPlaylists(limit: 100);
    } catch (e) {
      debugPrint('Error loading playlists: $e');
      _playlists = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Playlist> get _filteredPlaylists {
    if (_searchQuery.isEmpty) return _playlists;
    return _playlists.where((playlist) {
      return playlist.title.toLowerCase().contains(_searchQuery.toLowerCase());
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
          'Quản lý playlist',
          style: TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadPlaylists,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlaylistDialog(context),
        backgroundColor: const Color(0xFF4A6E78),
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
                hintText: 'Tìm kiếm playlist...',
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
                  label: 'Tổng playlist',
                  value: _playlists.length.toString(),
                  color: const Color(0xFF4A6E78),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Playlist list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPlaylists.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.queue_music_rounded,
                              size: 64,
                              color: _darkText.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy playlist',
                              style: TextStyle(
                                color: _darkText.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPlaylists,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPlaylists.length,
                          itemBuilder: (context, index) {
                            return _PlaylistTile(
                              playlist: _filteredPlaylists[index],
                              onEdit: () => _showPlaylistDialog(context, playlist: _filteredPlaylists[index]),
                              onDelete: () => _deletePlaylist(_filteredPlaylists[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistDialog(BuildContext context, {Playlist? playlist}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlaylistFormSheet(
        playlist: playlist,
        onSave: (data) async {
          try {
            if (playlist == null) {
              await FirestoreService.createPlaylist(
                userId: 'system',
                title: data['title'],
                coverUrl: data['coverUrl'],
              );
            } else {
              await FirestoreService.updatePlaylistTitle(playlist.id, data['title']);
            }
            await _loadPlaylists();
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(playlist == null ? 'Đã thêm playlist' : 'Đã cập nhật playlist'),
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

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFE13300)),
            SizedBox(width: 8),
            Text('Xóa playlist'),
          ],
        ),
        content: Text('Bạn có chắc muốn xóa playlist "${playlist.title}"?'),
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
        await FirestoreService.deletePlaylist(playlist.id);
        await _loadPlaylists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa playlist'),
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

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.playlist,
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF4A6E78).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.queue_music_rounded,
                color: Color(0xFF4A6E78),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A1F1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.songIds.length} bài hát',
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                  if (playlist.ownerName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Tạo bởi: ${playlist.ownerName}',
                      style: TextStyle(
                        color: const Color(0xFF0A1F1A).withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
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

class _PlaylistFormSheet extends StatefulWidget {
  final Playlist? playlist;
  final Function(Map<String, dynamic>) onSave;

  const _PlaylistFormSheet({this.playlist, required this.onSave});

  @override
  State<_PlaylistFormSheet> createState() => _PlaylistFormSheetState();
}

class _PlaylistFormSheetState extends State<_PlaylistFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _coverUrlController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.playlist?.title ?? '');
    _coverUrlController = TextEditingController(text: widget.playlist?.coverUrl ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.playlist != null;

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
              isEditing ? 'Sửa playlist' : 'Thêm playlist mới',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A1F1A),
              ),
            ),
            const SizedBox(height: 20),

            _buildTextField('Tên playlist', _titleController, isRequired: true),
            const SizedBox(height: 12),
            _buildTextField('URL ảnh bìa', _coverUrlController),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6E78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isEditing ? 'Lưu thay đổi' : 'Thêm playlist',
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
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên playlist'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFE13300),
        ),
      );
      return;
    }

    widget.onSave({
      'title': _titleController.text.trim(),
      'coverUrl': _coverUrlController.text.trim(),
    });
  }
}
