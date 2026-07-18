import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/genre.dart';
import '../providers/user_provider.dart';
import '../firebase/firestore_service.dart';
import '../services/cloudinary_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class ArtistRegisterScreen extends StatefulWidget {
  const ArtistRegisterScreen({super.key});

  @override
  State<ArtistRegisterScreen> createState() => _ArtistRegisterScreenState();
}

class _ArtistRegisterScreenState extends State<ArtistRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final _bioController = TextEditingController();
  final _socialController = TextEditingController();

  List<Genre> _allGenres = [];
  final Set<String> _selectedGenres = {};
  String? _avatarUrl;
  String? _sampleTrackUrl;
  bool _isUploadingAvatar = false;
  bool _isUploadingTrack = false;
  bool _isSubmitting = false;
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameController = TextEditingController(text: user.displayName ?? '');
    _avatarUrl = user.photoUrl;
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    final genres = await FirestoreService.getGenres(limit: 50);
    if (mounted) {
      setState(() {
        _allGenres = genres;
        _loadingGenres = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploadingAvatar = true);
      final url = await CloudinaryService.uploadFile(File(image.path));
      if (mounted) {
        setState(() {
          if (url != null) _avatarUrl = url;
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _pickTrack() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'mp4', 'm4v', 'mov', 'webm'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _isUploadingTrack = true);
      final url = await CloudinaryService.uploadFile(
        File(result.files.single.path!),
        isAudio: true,
      );
      if (mounted) {
        setState(() {
          if (url != null) _sampleTrackUrl = url;
          _isUploadingTrack = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenres.isEmpty) {
      _showSnack('Vui lòng chọn ít nhất một thể loại');
      return;
    }
    if (_sampleTrackUrl == null) {
      _showSnack('Vui lòng tải lên một bài nhạc mẫu');
      return;
    }

    final userProvider = context.read<UserProvider>();
    if (userProvider.userId == null) return;

    setState(() => _isSubmitting = true);
    try {
      await FirestoreService.submitArtistRequest(
        userId: userProvider.userId!,
        artistName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _avatarUrl,
        genres: _selectedGenres.toList(),
        socialLinks: _socialController.text.trim(),
        sampleTrackUrl: _sampleTrackUrl,
      );
      await userProvider.reloadRole();
      if (mounted) {
        Navigator.pop(context);
        _showSnack('Đã gửi đơn! Đơn của bạn đang chờ admin duyệt.');
      }
    } catch (e) {
      debugPrint('Error submitting artist request: $e');
      if (mounted) _showSnack('Gửi đơn thất bại. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
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
        title: const Text(
          'Đăng ký làm nghệ sĩ',
          style: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loadingGenres
          ? const Center(child: CircularProgressIndicator(color: _mintGreen))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Chia sẻ âm nhạc của bạn với mọi người. Điền thông tin bên dưới, đơn sẽ được admin xét duyệt.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Center(child: _buildAvatarPicker()),
                  const SizedBox(height: 24),
                  _buildField('Tên nghệ sĩ', _nameController,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null),
                  const SizedBox(height: 16),
                  _buildField('Giới thiệu / Bio', _bioController, maxLines: 3),
                  const SizedBox(height: 16),
                  _buildField('Link mạng xã hội (YouTube, Instagram...)', _socialController),
                  const SizedBox(height: 20),
                  const Text('Thể loại nhạc',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _darkText)),
                  const SizedBox(height: 10),
                  _buildGenreChips(),
                  const SizedBox(height: 20),
                  const Text('Bài nhạc mẫu',
                      style: TextStyle(fontWeight: FontWeight.w700, color: _darkText)),
                  const SizedBox(height: 10),
                  _buildTrackPicker(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || _isUploadingAvatar || _isUploadingTrack)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mintGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('GỬI ĐƠN ĐĂNG KÝ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _isUploadingAvatar ? null : _pickAvatar,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _mintGreen.withOpacity(0.1),
          image: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
              ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
              : null,
        ),
        child: _isUploadingAvatar
            ? const Center(child: CircularProgressIndicator())
            : (_avatarUrl == null || _avatarUrl!.isEmpty)
                ? const Icon(Icons.add_a_photo_rounded, color: _mintGreen, size: 32)
                : null,
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildGenreChips() {
    if (_allGenres.isEmpty) {
      return const Text('Chưa có thể loại nào', style: TextStyle(color: Colors.black54));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allGenres.map((g) {
        final selected = _selectedGenres.contains(g.name);
        return FilterChip(
          label: Text(g.name),
          selected: selected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedGenres.add(g.name);
              } else {
                _selectedGenres.remove(g.name);
              }
            });
          },
          selectedColor: _mintGreen.withOpacity(0.2),
          checkmarkColor: _mintGreen,
        );
      }).toList(),
    );
  }

  Widget _buildTrackPicker() {
    return ListTile(
      onTap: _isUploadingTrack ? null : _pickTrack,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(
        _sampleTrackUrl != null ? Icons.check_circle : Icons.audiotrack,
        color: _sampleTrackUrl != null ? Colors.green : _mintGreen,
      ),
      title: Text(
        _isUploadingTrack
            ? 'Đang tải lên...'
            : (_sampleTrackUrl != null ? 'Đã tải lên bài nhạc mẫu' : 'Chọn file nhạc / video (mp3, mp4...)'),
      ),
    );
  }
}
