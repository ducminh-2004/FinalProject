import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/cloudinary_service.dart';
import '../../models/song.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../firebase/firestore_service.dart';
import '../lyrics_editor_screen.dart';

class AdminSongsScreen extends StatefulWidget {
  const AdminSongsScreen({super.key});

  @override
  State<AdminSongsScreen> createState() => _AdminSongsScreenState();
}

class _AdminSongsScreenState extends State<AdminSongsScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      _songs = await FirestoreService.getSongs(limit: 100);
    } catch (e) {
      debugPrint('Error loading songs: $e');
      _songs = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Song> get _filteredSongs {
    if (_searchQuery.isEmpty) return _songs;
    return _songs.where((song) {
      return song.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             song.artistDisplay.toLowerCase().contains(_searchQuery.toLowerCase());
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
          'Quản lý bài hát',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadSongs,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSongDialog(context),
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Thêm bài hát', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                : _filteredSongs.isEmpty 
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadSongs,
                        color: _primaryColor,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: _filteredSongs.length,
                          itemBuilder: (context, index) {
                            return _SongTile(
                              song: _filteredSongs[index],
                              onEdit: () => _showSongDialog(context, song: _filteredSongs[index]),
                              onDelete: () => _deleteSong(_filteredSongs[index]),
                              onLyrics: () => _showLyricsSheet(context, _filteredSongs[index]),
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
      padding: const EdgeInsets.all(20),
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
            hintText: 'Tìm kiếm theo tên bài hát hoặc nghệ sĩ...',
            hintStyle: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _darkText.withOpacity(0.3), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy bài hát nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showSongDialog(BuildContext context, {Song? song}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SongFormSheet(
        song: song,
        onSave: (data) async {
          try {
            if (song == null) {
              await FirestoreService.createSong(
                title: data['title'],
                artists: List<String>.from(data['artists']),
                artistIds: List<String>.from(data['artistIds']),
                coverUrl: data['coverUrl'],
                audioUrl: data['audioUrl'],
              );
            } else {
              await FirestoreService.updateSong(song.id, data);
            }
            await _loadSongs();
            if (!mounted) return;
            Navigator.pop(context);
          } catch (e) {
            debugPrint('Error: $e');
          }
        },
      ),
    );
  }

  void _showLyricsSheet(BuildContext context, Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LyricsEditorScreen(song: song)),
    );
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa bài hát', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa bài hát "${song.title}"? Thao tác này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: _darkText.withOpacity(0.5), fontWeight: FontWeight.bold)),
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
      await FirestoreService.deleteSong(song.id);
      _loadSongs();
    }
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF0E6B5A).withOpacity(0.05),
                    ),
                    child: song.coverUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(song.coverUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.music_note_rounded, color: Color(0xFF0E6B5A), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
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
                          song.artistDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF0A1F1A).withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionButton(icon: Icons.lyrics_outlined, color: Colors.deepPurpleAccent, onTap: onLyrics),
                      const SizedBox(width: 8),
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

class _SongFormSheet extends StatefulWidget {
  final Song? song;
  final Function(Map<String, dynamic>) onSave;
  const _SongFormSheet({this.song, required this.onSave});

  @override
  State<_SongFormSheet> createState() => _SongFormSheetState();
}

class _SongFormSheetState extends State<_SongFormSheet> {
  late TextEditingController _titleController;
  List<Artist> _allArtists = [];
  List<Album> _allAlbums = [];
  List<Artist> _selectedArtists = [];
  Album? _selectedAlbum;
  
  String? _coverUrl;
  String? _audioUrl;
  bool _isUploadingCover = false;
  bool _isUploadingAudio = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song?.title ?? '');
    _coverUrl = widget.song?.coverUrl;
    _audioUrl = widget.song?.audioUrl;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final artists = await FirestoreService.getArtists(limit: 100);
      final albums = await FirestoreService.getAlbums(limit: 100);
      
      setState(() {
        _allArtists = artists;
        _allAlbums = albums;
        
        if (widget.song != null) {
          _selectedArtists = _allArtists.where((a) => widget.song!.artistIds.contains(a.id)).toList();
        }
        
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingCover = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (url != null) setState(() => _coverUrl = url);
      setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploadingAudio = true);
      final url = await CloudinaryService.uploadFile(File(result.files.single.path!), isAudio: true);
      if (url != null) setState(() => _audioUrl = url);
      setState(() => _isUploadingAudio = false);
    }
  }

  void _showArtistPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn nghệ sĩ'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allArtists.length,
            itemBuilder: (context, index) {
              final artist = _allArtists[index];
              final isSelected = _selectedArtists.any((a) => a.id == artist.id);
              return CheckboxListTile(
                title: Text(artist.name),
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedArtists.add(artist);
                    } else {
                      _selectedArtists.removeWhere((a) => a.id == artist.id);
                    }
                  });
                  Navigator.pop(context);
                  _showArtistPicker();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
        ],
      ),
    );
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
                  widget.song == null ? 'Thêm bài hát mới' : 'Chỉnh sửa bài hát',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A1F1A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.3)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Tiêu đề bài hát'),
            _buildTextField(_titleController, Icons.title_rounded),
            
            const SizedBox(height: 16),
            _buildLabel('Nghệ sĩ'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._selectedArtists.map((a) => Chip(
                  label: Text(a.name, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => setState(() => _selectedArtists.remove(a)),
                  backgroundColor: const Color(0xFF0E6B5A).withOpacity(0.1),
                  deleteIconColor: const Color(0xFF0E6B5A),
                )),
                ActionChip(
                  label: const Text('Thêm nghệ sĩ', style: TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.add, size: 16),
                  onPressed: _showArtistPicker,
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildLabel('Album (Tùy chọn)'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1F1A).withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Album>(
                  value: _selectedAlbum,
                  hint: const Text('Chọn Album'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<Album>(value: null, child: Text('Không có album')),
                    ..._allAlbums.map((a) => DropdownMenuItem(value: a, child: Text(a.title))),
                  ],
                  onChanged: (val) => setState(() => _selectedAlbum = val),
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Ảnh bìa'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickCover,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1F1A).withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            image: _coverUrl != null ? DecorationImage(image: NetworkImage(_coverUrl!), fit: BoxFit.cover) : null,
                            border: Border.all(color: const Color(0xFF0A1F1A).withOpacity(0.05)),
                          ),
                          child: _isUploadingCover 
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0E6B5A))) 
                              : (_coverUrl == null ? Icon(Icons.add_a_photo_outlined, color: const Color(0xFF0A1F1A).withOpacity(0.2)) : null),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tệp âm thanh'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickAudio,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0E6B5A).withOpacity(0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0E6B5A).withOpacity(0.1)),
                          ),
                          child: _isUploadingAudio 
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0E6B5A))) 
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _audioUrl != null ? Icons.check_circle_rounded : Icons.audiotrack_rounded,
                                      color: _audioUrl != null ? Colors.green : const Color(0xFF0E6B5A),
                                      size: 32,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _audioUrl != null ? 'Đã chọn' : 'Chọn tệp',
                                      style: TextStyle(
                                        color: _audioUrl != null ? Colors.green : const Color(0xFF0E6B5A),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isUploadingCover || _isUploadingAudio || _selectedArtists.isEmpty) ? null : () {
                  if (_titleController.text.isEmpty) return;
                  
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'artists': _selectedArtists.map((a) => a.name).toList(),
                    'artistIds': _selectedArtists.map((a) => a.id).toList(),
                    'albumId': _selectedAlbum?.id,
                    'coverUrl': _coverUrl ?? '',
                    'audioUrl': _audioUrl ?? '',
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E6B5A),
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
