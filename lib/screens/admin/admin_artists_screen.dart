import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/artist.dart';
import '../../firebase/firestore_service.dart';

class AdminArtistsScreen extends StatefulWidget {
  const AdminArtistsScreen({super.key});

  @override
  State<AdminArtistsScreen> createState() => _AdminArtistsScreenState();
}

class _AdminArtistsScreenState extends State<AdminArtistsScreen> {
  List<Artist> _artists = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _accentColor = Color(0xFFE13300);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

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
          'Quản lý nghệ sĩ',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadArtists,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showArtistDialog(context),
        backgroundColor: _accentColor,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Thêm nghệ sĩ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatsRow(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredArtists.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadArtists,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
            hintText: 'Tìm kiếm tên nghệ sĩ...',
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
            label: 'Tổng số',
            value: _artists.length.toString(),
            color: _primaryColor,
          ),
          const SizedBox(width: 8),
          _StatBadge(
            label: 'Đã xác minh',
            value: _artists.where((a) => a.isVerified ?? false).length.toString(),
            color: Colors.blueAccent,
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
          Icon(Icons.person_search_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy nghệ sĩ nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
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
            if (!mounted) return;
            Navigator.pop(context);
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  Future<void> _deleteArtist(Artist artist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xóa nghệ sĩ', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Hành động này sẽ xóa vĩnh viễn nghệ sĩ "${artist.name}" khỏi hệ thống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: _darkText.withOpacity(0.4), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
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
      await FirestoreService.deleteArtist(artist.id);
      _loadArtists();
    }
  }

  Future<void> _toggleVerify(Artist artist) async {
    await FirestoreService.updateArtist(artist.id, {
      'isVerified': !(artist.isVerified ?? false),
    });
    _loadArtists();
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0E6B5A).withOpacity(0.05),
                          image: artist.avatarUrl != null
                              ? DecorationImage(image: NetworkImage(artist.avatarUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: artist.avatarUrl == null
                            ? const Icon(Icons.person_rounded, color: Color(0xFF0E6B5A), size: 32)
                            : null,
                      ),
                      if (artist.isVerified ?? false)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0A1F1A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${artist.monthlyListeners ?? 0} người nghe hàng tháng',
                          style: TextStyle(
                            color: const Color(0xFF0A1F1A).withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    icon: Icon(Icons.more_vert_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'verify') onToggleVerify();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: _PopupItem(icon: Icons.edit_rounded, label: 'Chỉnh sửa')),
                      PopupMenuItem(
                        value: 'verify',
                        child: _PopupItem(
                          icon: (artist.isVerified ?? false) ? Icons.verified_user_outlined : Icons.verified_user_rounded,
                          label: (artist.isVerified ?? false) ? 'Hủy xác minh' : 'Xác minh',
                        ),
                      ),
                      const PopupMenuItem(value: 'delete', child: _PopupItem(icon: Icons.delete_outline_rounded, label: 'Xóa', color: Colors.redAccent)),
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

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _PopupItem({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF0A1F1A).withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
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
  late TextEditingController _bioController;
  late TextEditingController _genresController;
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.artist?.name ?? '');
    _bioController = TextEditingController(text: widget.artist?.bio ?? '');
    _genresController = TextEditingController(text: (widget.artist?.genres ?? []).join(', '));
    _avatarUrl = widget.artist?.avatarUrl;
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
                  widget.artist == null ? 'Thêm nghệ sĩ mới' : 'Chỉnh sửa nghệ sĩ',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A1F1A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A1F1A).withOpacity(0.03),
                        image: _avatarUrl != null ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) : null,
                        border: Border.all(color: const Color(0xFF0A1F1A).withOpacity(0.05), width: 2),
                      ),
                      child: _avatarUrl == null && !_isUploading
                          ? Icon(Icons.add_a_photo_outlined, color: const Color(0xFF0A1F1A).withOpacity(0.2), size: 32)
                          : _isUploading 
                              ? const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2)) 
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF0E6B5A), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            _buildField('Tên nghệ sĩ', _nameController, Icons.person_rounded),
            const SizedBox(height: 16),
            _buildField('Thể loại (cách nhau bằng dấu phẩy)', _genresController, Icons.category_rounded),
            const SizedBox(height: 16),
            _buildField('Tiểu sử', _bioController, Icons.description_rounded, maxLines: 3),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : () {
                  if (_nameController.text.isEmpty) return;
                  widget.onSave({
                    'name': _nameController.text.trim(),
                    'avatarUrl': _avatarUrl ?? '',
                    'bio': _bioController.text.trim(),
                    'genres': _genresController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE13300),
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

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A1F1A).withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 0),
                child: Icon(icon, size: 20, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}
