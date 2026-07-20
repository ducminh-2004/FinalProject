import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../firebase/firestore_service.dart';

class AdminPlaylistsScreen extends StatefulWidget {
  const AdminPlaylistsScreen({super.key});

  @override
  State<AdminPlaylistsScreen> createState() => _AdminPlaylistsScreenState();
}

class _AdminPlaylistsScreenState extends State<AdminPlaylistsScreen> {
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _accentColor = Color(0xFF4A6E78);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

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
          'Quản lý Playlist',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadPlaylists,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlaylistDialog(context),
        backgroundColor: _accentColor,
        icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
        label: const Text('Tạo Playlist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsRow(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredPlaylists.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadPlaylists,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _filteredPlaylists.length,
                          itemBuilder: (context, index) {
                            return _PlaylistTile(
                              playlist: _filteredPlaylists[index],
                              onEdit: () => _showPlaylistDialog(context, playlist: _filteredPlaylists[index]),
                              onDelete: () => _deletePlaylist(_filteredPlaylists[index]),
                              onManageSongs: () => _manageSongs(_filteredPlaylists[index]),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _darkText.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm tiêu đề playlist...',
            hintStyle: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _darkText.withOpacity(0.3), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _StatBadge(
            label: 'Tổng số Playlist',
            value: _playlists.length.toString(),
            color: _accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_remove_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy playlist nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
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
              await FirestoreService.updatePlaylist(playlist.id, {
                'title': data['title'],
                'coverUrl': data['coverUrl'],
              });
            }
            await _loadPlaylists();
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  Future<void> _deletePlaylist(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xóa Playlist', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Bạn có chắc muốn xóa playlist "${playlist.title}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: _darkText.withOpacity(0.4), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa ngay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deletePlaylist(playlist.id);
      _loadPlaylists();
    }
  }

  void _manageSongs(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _PlaylistSongsScreen(playlist: playlist)),
    ).then((_) => _loadPlaylists());
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.7), fontWeight: FontWeight.w600, fontSize: 11),
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
  final VoidCallback onManageSongs;

  const _PlaylistTile({
    required this.playlist,
    required this.onEdit,
    required this.onDelete,
    required this.onManageSongs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onManageSongs,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF4A6E78).withOpacity(0.05),
                    ),
                    child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(playlist.coverUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.queue_music_rounded, color: Color(0xFF4A6E78), size: 28),
                  ),
                  const SizedBox(width: 16),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${playlist.songIds.length} bài hát',
                          style: TextStyle(
                            color: const Color(0xFF0A1F1A).withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          playlist.ownerId == 'system' ? 'Playlist Hệ thống' : 'Playlist Người dùng',
                          style: TextStyle(
                            color: playlist.ownerId == 'system' ? const Color(0xFF0E6B5A) : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
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
  String? _coverUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.playlist?.title ?? '');
    _coverUrl = widget.playlist?.coverUrl;
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.playlist == null ? 'Tạo Playlist mới' : 'Chỉnh sửa Playlist',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A1F1A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildLabel('Tên Playlist'),
            _buildTextField(_titleController, Icons.title_rounded),
            
            const SizedBox(height: 24),
            const Text('Ảnh bìa Playlist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A))),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F1A).withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  image: _coverUrl != null && _coverUrl!.isNotEmpty ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover) : null,
                  border: Border.all(color: const Color(0xFF0A1F1A).withOpacity(0.05)),
                ),
                child: _isUploading 
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) 
                    : (_coverUrl == null || _coverUrl!.isEmpty ? Icon(Icons.add_photo_alternate_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.2), size: 40) : null),
              ),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : () {
                  if (_titleController.text.isEmpty) return;
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'coverUrl': _coverUrl ?? '',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A6E78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('XÁC NHẬN LƯU', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A)));
  }

  Widget _buildTextField(TextEditingController controller, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1F1A).withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _PlaylistSongsScreen extends StatefulWidget {
  final Playlist playlist;
  const _PlaylistSongsScreen({required this.playlist});

  @override
  State<_PlaylistSongsScreen> createState() => _PlaylistSongsScreenState();
}

class _PlaylistSongsScreenState extends State<_PlaylistSongsScreen> {
  List<Song> _allSongs = [];
  List<String> _selectedSongIds = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedSongIds = List<String>.from(widget.playlist.songIds);
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final songs = await FirestoreService.getSongs(limit: 500);
      setState(() {
        _allSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePlaylistSongs() async {
    setState(() => _isLoading = true);
    try {
      await FirestoreService.updatePlaylist(widget.playlist.id, {
        'songIds': _selectedSongIds,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allSongs.where((s) => s.title.toLowerCase().contains(_searchQuery.toLowerCase()) || s.artistDisplay.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Bài hát trong Playlist', style: const TextStyle(color: Color(0xFF0A1F1A), fontSize: 18, fontWeight: FontWeight.w900)),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Color(0xFF0A1F1A))),
        actions: [
          TextButton(
            onPressed: _savePlaylistSongs,
            child: const Text('LƯU', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0E6B5A))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm bài hát để thêm...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Đã chọn ${_selectedSongIds.length} bài hát', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final song = filtered[index];
                      final isSelected = _selectedSongIds.contains(song.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedSongIds.add(song.id);
                            else _selectedSongIds.remove(song.id);
                          });
                        },
                        title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(song.artistDisplay),
                        secondary: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: song.coverUrl != null ? DecorationImage(image: NetworkImage(song.coverUrl!), fit: BoxFit.cover) : null),
                        ),
                        activeColor: const Color(0xFF0E6B5A),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
