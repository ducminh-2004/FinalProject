import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../firebase/firestore_service.dart';
import '../../services/view_service.dart';
import '../../models/view_model.dart';
import '../../providers/user_provider.dart';
import '../profile_screen.dart'; // Import ProfileScreen
import 'admin_users_screen.dart';
import 'admin_songs_screen.dart';
import 'admin_artists_screen.dart';
import 'admin_albums_screen.dart';
import 'admin_genres_screen.dart';
import 'admin_subscriptions_screen.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _topSongs = [];
  List<DailyStats> _dailyStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService.getSystemStats(),
        ViewService.getTopSongs(limit: 5),
        ViewService.getDailyStats(days: 7),
      ]);
      
      _stats = results[0] as Map<String, int>;
      _topSongs = results[1] as List<Map<String, dynamic>>;
      _dailyStats = results[2] as List<DailyStats>;
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: _mintGreen,
        surfaceTintColor: _mintGreen,
        elevation: 0,
        title: const Text(
          'Quản trị viên',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đang tạo dữ liệu ảo...')));
              await ViewService.simulateFakeViews();
              await _loadData(); // Tải lại biểu đồ
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo xong! Hãy kiểm tra Trending.')));
              }
            },
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber), // Nút sét cho máu
            tooltip: 'Tạo data ảo',
          ),
          _AvatarButton(onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats grid
              _buildSectionTitle('Tổng quan'),
              const SizedBox(height: 12),
              _buildStatsGrid(),
              const SizedBox(height: 24),

              // Charts
              _buildSectionTitle('Thống kê lượt xem'),
              const SizedBox(height: 12),
              _buildCharts(),
              const SizedBox(height: 24),

              // Management sections
              _buildSectionTitle('Quản lý'),
              const SizedBox(height: 12),
              _buildManagementGrid(),
              
              const SizedBox(height: 32),
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<UserProvider>().signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _darkText,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5, // Tăng tỉ lệ để tránh tràn chữ
      children: [
        _StatCard(
          icon: Icons.music_note_rounded,
          label: 'Bài hát',
          value: _stats['songs']?.toString() ?? '0',
          color: const Color(0xFF1DB954),
        ),
        _StatCard(
          icon: Icons.person_rounded,
          label: 'Nghệ sĩ',
          value: _stats['artists']?.toString() ?? '0',
          color: const Color(0xFFE13300),
        ),
        _StatCard(
          icon: Icons.album_rounded,
          label: 'Album',
          value: _stats['albums']?.toString() ?? '0',
          color: const Color(0xFF8D67AB),
        ),
        _StatCard(
          icon: Icons.group_rounded,
          label: 'Người dùng',
          value: _stats['users']?.toString() ?? '0',
          color: const Color(0xFFDC148C),
        ),
      ],
    );
  }

  Widget _buildCharts() {
    if (_isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

    return Column(
      children: [
        _buildChartCard(
          'Top 5 bài hát theo lượt nghe',
          _topSongs.isEmpty 
            ? const Center(child: Text('Chưa có dữ liệu lượt nghe'))
            : BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (_topSongs.isNotEmpty ? (_topSongs[0]['totalViews'] as num).toDouble() + 5 : 20),
                  barGroups: _topSongs.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value['totalViews'] as num).toDouble(),
                          color: _mintGreen,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        )
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < _topSongs.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                (_topSongs[index]['title'] ?? '').toString().substring(0, 3),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
        ),
        const SizedBox(height: 16),
        _buildChartCard(
          'Xu hướng lượt nghe (7 ngày qua)',
          _dailyStats.isEmpty
            ? const Center(child: Text('Chưa có thống kê ngày'))
            : LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _dailyStats.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalViews.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: _mintGreen,
                      barWidth: 4,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: _mintGreen.withValues(alpha: 0.1)),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < _dailyStats.length) {
                            return Text(
                              '${_dailyStats[index].date.day}/${_dailyStats[index].date.month}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          SizedBox(height: 150, child: chart),
        ],
      ),
    );
  }

  Widget _buildManagementGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ManagementCard(
                icon: Icons.people_rounded,
                title: 'Người dùng',
                subtitle: 'Quản lý tài khoản',
                color: const Color(0xFFDC148C),
                onTap: () => _navigateTo(const AdminUsersScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.music_note_rounded,
                title: 'Bài hát',
                subtitle: 'Thêm, sửa, xóa',
                color: const Color(0xFF1DB954),
                onTap: () => _navigateTo(const AdminSongsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ManagementCard(
                icon: Icons.person_rounded,
                title: 'Nghệ sĩ',
                subtitle: 'Quản lý nghệ sĩ',
                color: const Color(0xFFE13300),
                onTap: () => _navigateTo(const AdminArtistsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.album_rounded,
                title: 'Album',
                subtitle: 'Quản lý album',
                color: const Color(0xFF8D67AB),
                onTap: () => _navigateTo(const AdminAlbumsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ManagementCard(
          icon: Icons.category_rounded,
          title: 'Thể loại',
          subtitle: 'Quản lý danh sách thể loại',
          color: const Color(0xFF1DB954),
          onTap: () => _navigateTo(const AdminGenresScreen()),
          fullWidth: true,
        ),
        const SizedBox(height: 12),
        _ManagementCard(
          icon: Icons.stars_rounded,
          title: 'Gói hội viên',
          subtitle: 'Quản lý các gói Standard, Pro, Premium',
          color: const Color(0xFFDC148C),
          onTap: () => _navigateTo(const AdminSubscriptionsScreen()),
          fullWidth: true,
        ),
      ],
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0A1F1A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F1A).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0A1F1A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF0A1F1A).withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: const Color(0xFF0A1F1A).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.2),
            image: userProvider.photoUrl != null
                ? DecorationImage(image: NetworkImage(userProvider.photoUrl!), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: userProvider.photoUrl == null 
              ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
