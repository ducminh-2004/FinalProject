import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../services/room_service.dart';
import '../providers/user_provider.dart';
import '../widgets/add_song_room_sheet.dart';
import 'room_detail_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final TextEditingController _keyController = TextEditingController();
  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  void _showJoinRoomDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Vào phòng bằng mã'),
        content: TextField(
          controller: _keyController,
          decoration: const InputDecoration(
            hintText: 'Nhập mã 6 ký tự',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final key = _keyController.text.trim();
              if (key.length == 6) {
                final roomId = await RoomService.findRoomByKey(key);
                if (roomId != null && context.mounted) {
                  Navigator.pop(context);
                  _keyController.clear();
                  _joinRoom(roomId);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không tìm thấy phòng hoặc mã đã hết hạn')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
            child: const Text('Vào ngay'),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog() {
    final userProvider = context.read<UserProvider>();
    // Chỉ cho phép Premium hoặc Pro tạo phòng
    final tier = userProvider.subscriptionTier.toLowerCase();
    if (tier != 'premium' && tier != 'pro') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yêu cầu Premium/Pro'),
          content: Text('Chỉ người dùng Premium hoặc Pro mới có thể tạo phòng nghe nhạc. Gói hiện tại của bạn là: ${userProvider.subscriptionTier}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Bạn có thể điều hướng tới trang nâng cấp ở đây
              },
              style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
              child: const Text('Nâng cấp ngay'),
            ),
          ],
        ),
      );
      return;
    }

    final nameController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sbContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tạo phòng nghe nhạc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tên phòng của bạn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Chế độ riêng tư', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('Chỉ người có mã mới vào được', style: TextStyle(fontSize: 11)),
                value: isPrivate,
                activeColor: _mintGreen,
                onChanged: (val) => setDialogState(() => isPrivate = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final roomName = nameController.text.trim();
                if (roomName.isEmpty) return;
                
                Navigator.pop(dialogContext); // Đóng dialog nhập tên

                // Đảm bảo widget vẫn còn trên cây trước khi tiếp tục
                if (!context.mounted) return;

                // Mở sheet chọn nhạc bằng context của RoomListScreen (bền vững hơn)
                final List<String>? selectedIds = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const AddSongRoomSheet(isInitial: true),
                );

                if (selectedIds == null) return;

                if (context.mounted) {
                  // Hiển thị loading overlay
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(child: CircularProgressIndicator(color: _mintGreen)),
                  );

                  try {
                    final userId = userProvider.userId;
                    if (userId == null) throw Exception('Bạn cần đăng nhập để tạo phòng');

                    debugPrint('DEBUG: Creating room "$roomName" with ${selectedIds.length} songs, Private: $isPrivate');
                    
                    // Tạo phòng với playlist sẵn có trong một bước
                    final roomId = await RoomService.createRoom(
                      hostId: userId,
                      hostName: userProvider.displayName ?? 'Host',
                      roomName: roomName,
                      initialPlaylist: selectedIds,
                      isPrivate: isPrivate,
                    );
                    
                    debugPrint('DEBUG: Room created successfully: $roomId');

                    if (context.mounted) {
                      Navigator.pop(context); // Đóng loading overlay
                      _joinRoom(roomId); // Chuyển sang màn hình RoomDetail
                    }
                  } catch (e) {
                    debugPrint('CRITICAL ERROR during room creation: $e');
                    if (context.mounted) {
                      Navigator.pop(context); // Đóng loading overlay
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lỗi khi tạo phòng: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
              child: const Text('Tiếp theo'),
            ),
          ],
        ),
      ),
    );
  }

  void _joinRoom(String roomId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoomDetailScreen(roomId: roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        title: const Text('Listening Room', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          IconButton(onPressed: _showJoinRoomDialog, icon: const Icon(Icons.vpn_key_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildQuickAction(context),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Text('Phòng đang hoạt động', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Icon(Icons.live_tv_rounded, color: Colors.red, size: 18),
              ],
            ),
          ),
          Expanded(child: _buildRoomList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        backgroundColor: _mintGreen,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tạo phòng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_mintGreen, Color(0xFF0A1F1A)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Listening Party', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Nghe nhạc cùng bạn bè và mọi người khắp nơi.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _showJoinRoomDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Vào phòng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .snapshots(), // Bỏ tạm where để kiểm tra lỗi
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore Error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Lỗi kết nối: ${snapshot.error}\nHãy kiểm tra Security Rules trên Firebase.', 
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final allDocs = snapshot.data?.docs ?? [];
        // Lọc thủ công ở Client để tránh lỗi Index
        final activeRooms = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'active';
        }).map((doc) => Room.fromFirestore(doc)).toList();

        if (activeRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speaker_group_outlined, size: 64, color: _darkText.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                const Text('Chưa có phòng nào đang phát.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Sắp xếp ở phía Client
        activeRooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: activeRooms.length,
          itemBuilder: (context, index) {
            final room = activeRooms[index];
            return _RoomCard(room: room, onTap: () => _joinRoom(room.id));
          },
        );
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E6B5A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.music_video_rounded, color: Color(0xFF0E6B5A), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Host: ${room.hostName}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.red, size: 14),
                    const SizedBox(width: 4),
                    Text('${room.participants.length}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
