import 'package:flutter/material.dart';
import '../../firebase/firestore_service.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await FirestoreService.getAllUsers();
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final email = (user['email'] ?? '').toString().toLowerCase();
      final name = (user['displayName'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery.toLowerCase()) ||
             name.contains(_searchQuery.toLowerCase());
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
          'Quản lý người dùng',
          style: TextStyle(
            color: _darkText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm người dùng...',
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
                  label: 'Tổng',
                  value: _users.length.toString(),
                  color: _mintGreen,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Admin',
                  value: _users.where((u) => u['role'] == 'admin').length.toString(),
                  color: const Color(0xFFE13300),
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Bị ban',
                  value: _users.where((u) => u['isBanned'] == true).length.toString(),
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 64,
                              color: _darkText.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không tìm thấy người dùng',
                              style: TextStyle(
                                color: _darkText.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _UserTile(
                              user: _filteredUsers[index],
                              onRoleChange: (role) => _changeRole(
                                _filteredUsers[index]['id'],
                                role,
                              ),
                              onBan: () => _toggleBan(
                                _filteredUsers[index]['id'],
                                _filteredUsers[index]['isBanned'] ?? false,
                              ),
                              onDelete: () => _deleteUser(
                                _filteredUsers[index]['id'],
                                _filteredUsers[index]['email'] ?? 'user',
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRole(String userId, String role) async {
    try {
      await FirestoreService.setUserRole(userId, role);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(role == 'admin' ? 'Đã thăng thành admin' : 'Đã hạ xuống user'),
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

  Future<void> _toggleBan(String userId, bool currentlyBanned) async {
    try {
      await FirestoreService.setUserBanned(userId, !currentlyBanned);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentlyBanned ? 'Đã ban người dùng' : 'Đã unban người dùng'),
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

  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFE13300)),
            SizedBox(width: 8),
            Text('Xóa người dùng'),
          ],
        ),
        content: Text('Bạn có chắc muốn xóa người dùng "$email"?'),
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
        await FirestoreService.deleteUser(userId);
        await _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa người dùng'),
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

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final Function(String) onRoleChange;
  final VoidCallback onBan;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onRoleChange,
    required this.onBan,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = user['role'] == 'admin';
    final isBanned = user['isBanned'] == true;
    final likedCount = (user['likedSongs'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Opacity(
        opacity: isBanned ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _mintGreen.withValues(alpha: 0.1),
                    backgroundImage: user['photoURL'] != null
                        ? NetworkImage(user['photoURL'])
                        : null,
                    child: user['photoURL'] == null
                        ? Text(
                            (user['displayName'] ?? user['email'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: _mintGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
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
                                user['displayName'] ?? 'Không có tên',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _darkText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE13300).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: Color(0xFFE13300),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            if (isBanned) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BANNED',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user['email'] ?? 'Không có email',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _darkText.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: _darkText.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likedCount bài đã thích',
                              style: TextStyle(
                                color: _darkText.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Actions
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRoleDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isAdmin ? const Color(0xFFE13300) : _mintGreen,
                        side: BorderSide(
                          color: isAdmin ? const Color(0xFFE13300) : _mintGreen,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isAdmin ? 'Hạ cấp' : 'Thăng Admin'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBan,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isBanned ? Colors.green : Colors.grey,
                        side: BorderSide(
                          color: isBanned ? Colors.green : Colors.grey,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isBanned ? 'Unban' : 'Ban'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFE13300),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đổi vai trò'),
        content: const Text('Chọn vai trò cho người dùng này:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRoleChange('user');
            },
            child: const Text('User'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRoleChange('admin');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE13300),
              foregroundColor: Colors.white,
            ),
            child: const Text('Admin'),
          ),
        ],
      ),
    );
  }
}
