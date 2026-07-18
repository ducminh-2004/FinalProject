import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../firebase/firestore_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminArtistRequestsScreen extends StatefulWidget {
  const AdminArtistRequestsScreen({super.key});

  @override
  State<AdminArtistRequestsScreen> createState() => _AdminArtistRequestsScreenState();
}

class _AdminArtistRequestsScreenState extends State<AdminArtistRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      _requests = await FirestoreService.getArtistRequests(status: _filter);
    } catch (e) {
      debugPrint('Error loading requests: $e');
      _requests = [];
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _approve(Map<String, dynamic> request) async {
    final confirmed = await _confirm('Duyệt đơn',
        'Duyệt "${request['artistName']}" thành nghệ sĩ? Người dùng sẽ có quyền đăng tải nhạc.');
    if (confirmed != true) return;
    try {
      await FirestoreService.approveArtistRequest(request);
      _showSnack('Đã duyệt nghệ sĩ mới!');
      _loadRequests();
    } catch (e) {
      debugPrint('Error approving: $e');
      _showSnack('Duyệt thất bại.');
    }
  }

  Future<void> _reject(Map<String, dynamic> request) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối đơn'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Lý do (tuỳ chọn)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FirestoreService.rejectArtistRequest(
          request['userId'] as String, noteController.text.trim());
      _showSnack('Đã từ chối đơn.');
      _loadRequests();
    } catch (e) {
      debugPrint('Error rejecting: $e');
      _showSnack('Từ chối thất bại.');
    }
  }

  Future<bool?> _confirm(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
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
        title: const Text('Đơn đăng ký nghệ sĩ',
            style: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh_rounded, color: _darkText)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _filterChip('Chờ duyệt', 'pending'),
                const SizedBox(width: 8),
                _filterChip('Đã duyệt', 'approved'),
                const SizedBox(width: 8),
                _filterChip('Đã từ chối', 'rejected'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _mintGreen))
                : _requests.isEmpty
                    ? const Center(child: Text('Không có đơn nào'))
                    : RefreshIndicator(
                        onRefresh: _loadRequests,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) => _RequestCard(
                            request: _requests[index],
                            onApprove: () => _approve(_requests[index]),
                            onReject: () => _reject(_requests[index]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filter = value);
        _loadRequests();
      },
      selectedColor: _mintGreen.withOpacity(0.2),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleSample(String url) async {
    if (_playing) {
      await _player.stop();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(url));
      setState(() => _playing = true);
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final status = r['status'] as String? ?? 'pending';
    final genres = (r['genres'] as List?)?.cast<String>() ?? [];
    final avatarUrl = r['avatarUrl'] as String?;
    final sampleUrl = r['sampleTrackUrl'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _mintGreen.withOpacity(0.1),
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, color: _mintGreen)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['artistName'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(r['userId'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black45, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            if ((r['bio'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(r['bio'] as String, style: const TextStyle(color: Colors.black87, fontSize: 13)),
            ],
            if (genres.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: genres
                    .map((g) => Chip(
                          label: Text(g, style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            if ((r['socialLinks'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(r['socialLinks'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                ],
              ),
            ],
            if (sampleUrl != null && sampleUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _toggleSample(sampleUrl),
                icon: Icon(_playing ? Icons.stop_circle : Icons.play_circle_fill, color: _mintGreen),
                label: Text(_playing ? 'Dừng nhạc mẫu' : 'Nghe nhạc mẫu'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _mintGreen,
                  side: const BorderSide(color: _mintGreen),
                ),
              ),
            ],
            if ((r['adminNote'] as String?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text('Ghi chú: ${r['adminNote']}',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mintGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'approved' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'approved' ? 'Đã duyệt' : 'Đã từ chối',
                  style: TextStyle(
                    color: status == 'approved' ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
