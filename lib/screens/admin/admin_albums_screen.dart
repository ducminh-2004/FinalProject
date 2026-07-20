import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../firebase/firestore_service.dart';

class AdminAlbumsScreen extends StatefulWidget {
  const AdminAlbumsScreen({super.key});

  @override
  State<AdminAlbumsScreen> createState() => _AdminAlbumsScreenState();
}

class _AdminAlbumsScreenState extends State<AdminAlbumsScreen> {
  List<Album> _albums = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _accentColor = Color(0xFF8D67AB);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

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
          'Quản lý album',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadAlbums,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAlbumDialog(context),
        backgroundColor: _accentColor,
        icon: const Icon(Icons.album_rounded, color: Colors.white),
        label: const Text('Thêm album', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsRow(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredAlbums.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadAlbums,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
            hintText: 'Tìm kiếm tiêu đề album hoặc nghệ sĩ...',
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
            label: 'Tổng album',
            value: _albums.length.toString(),
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
          Icon(Icons.album_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy album nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
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
                artistId: data['artistId'],
                coverUrl: data['coverUrl'],
              );
            } else {
              await FirestoreService.updateAlbum(album.id, data);
            }
            await _loadAlbums();
            if (mounted) Navigator.pop(context);
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xóa album', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Bạn có chắc muốn xóa album "${album.title}"? Mọi thông tin liên quan sẽ bị gỡ bỏ.'),
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
      await FirestoreService.deleteAlbum(album.id);
      _loadAlbums();
    }
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

class _AlbumTile extends StatelessWidget {
  final Album album;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AlbumTile({required this.album, required this.onEdit, required this.onDelete});

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
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF8D67AB).withOpacity(0.05),
                    ),
                    child: album.coverUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(album.coverUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.album_rounded, color: Color(0xFF8D67AB), size: 24),
                  ),
                  const SizedBox(width: 16),
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF0A1F1A).withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${album.songs.length} bài hát',
                          style: TextStyle(
                            color: const Color(0xFF0A1F1A).withOpacity(0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(icon: Icons.edit_outlined, color: Colors.blueAccent, onTap: onEdit),
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
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
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
  List<Artist> _allArtists = [];
  Artist? _selectedArtist;
  
  String? _coverUrl;
  bool _isUploading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.album?.title ?? '');
    _coverUrl = widget.album?.coverUrl;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final artists = await FirestoreService.getArtists(limit: 100);
      setState(() {
        _allArtists = artists;
        if (widget.album != null && widget.album!.artistId != null) {
          _selectedArtist = _allArtists.where((a) => a.id == widget.album!.artistId).firstOrNull;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading artists: $e');
      setState(() => _isLoadingData = false);
    }
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
    
    if (_isLoadingData) {
      return Container(
        height: 300,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

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
                  widget.album == null ? 'Thêm album mới' : 'Chỉnh sửa album',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A1F1A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Tên album'),
            _buildTextField(_titleController, Icons.title_rounded),
            const SizedBox(height: 16),
            _buildLabel('Nghệ sĩ'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1F1A).withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Artist>(
                  value: _selectedArtist,
                  hint: const Text('Chọn Nghệ sĩ'),
                  isExpanded: true,
                  items: _allArtists.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
                  onChanged: (val) => setState(() => _selectedArtist = val),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('Ảnh bìa album'),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1F1A).withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  image: _coverUrl != null ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover) : null,
                  border: Border.all(color: const Color(0xFF0A1F1A).withOpacity(0.05)),
                ),
                child: _isUploading 
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) 
                    : (_coverUrl == null ? Icon(Icons.add_photo_alternate_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.2), size: 40) : null),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUploading || _selectedArtist == null) ? null : () {
                  if (_titleController.text.isEmpty) return;
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'artist': _selectedArtist!.name,
                    'artistId': _selectedArtist!.id,
                    'coverUrl': _coverUrl ?? '',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D67AB),
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

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A)));
  
  Widget _buildTextField(TextEditingController controller, IconData icon) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(color: const Color(0xFF0A1F1A).withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
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
