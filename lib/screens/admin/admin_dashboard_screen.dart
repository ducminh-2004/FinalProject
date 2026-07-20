import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../firebase/firestore_service.dart';
import '../../services/view_service.dart';
import '../../models/view_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/analytics_provider.dart';
import 'admin_users_screen.dart';
import 'admin_songs_screen.dart';
import 'admin_artists_screen.dart';
import 'admin_albums_screen.dart';
import 'admin_genres_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_playlists_screen.dart';
import 'admin_revenue_screen.dart';
import 'admin_artist_requests_screen.dart';

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

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _accentColor = Color(0xFF1DB954);
  static const _bgColor = Color(0xFFF8FAF9);
  static const _darkText = Color(0xFF0A1F1A);

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
        FirestoreService.getTotalRevenue(),
      ]);
      
      _stats = results[0] as Map<String, int>;
      _topSongs = results[1] as List<Map<String, dynamic>>;
      _dailyStats = results[2] as List<DailyStats>;
      _stats['revenue'] = (results[3] as double).toInt();

      // DEBUG: In danh sách top bài hát ra console
      debugPrint('--- TOP 5 SONGS DATA ---');
      if (_topSongs.isEmpty) {
        debugPrint('Không có dữ liệu bài hát nào trong view_stats.');
      } else {
        for (var i = 0; i < _topSongs.length; i++) {
          final song = _topSongs[i];
          debugPrint('${i + 1}. Title: ${song['title']}, Views: ${song['totalViews']}, ID: ${song['id']}');
        }
      }
      debugPrint('------------------------');
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
      backgroundColor: _bgColor,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Hệ thống', Icons.analytics_outlined),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 16),
                    _buildRevenueSummaryCard(),
                    const SizedBox(height: 32),

                    _buildSectionHeader('Hiệu suất', Icons.bar_chart_rounded),
                    const SizedBox(height: 16),
                    _buildCharts(),
                    const SizedBox(height: 32),

                    _buildSectionHeader('Artist Analytics', Icons.person_search_rounded),
                    const SizedBox(height: 16),
                    _buildArtistAnalytics(),
                    const SizedBox(height: 32),

                    _buildSectionHeader('Quản lý', Icons.settings_outlined),
                    const SizedBox(height: 16),
                    _buildManagementGrid(),

                    const SizedBox(height: 48),
                    _buildLogoutButton(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        centerTitle: false,
        title: const Text(
          'Quản trị viên',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        background: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: _AvatarButton(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: _darkText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          icon: Icons.music_note_rounded,
          label: 'Bài hát',
          value: _stats['songs']?.toString() ?? '0',
          gradient: const [Color(0xFF1DB954), Color(0xFF138E41)],
        ),
        _StatCard(
          icon: Icons.person_rounded,
          label: 'Nghệ sĩ',
          value: _stats['artists']?.toString() ?? '0',
          gradient: const [Color(0xFFE13300), Color(0xFFB32900)],
        ),
        _StatCard(
          icon: Icons.album_rounded,
          label: 'Album',
          value: _stats['albums']?.toString() ?? '0',
          gradient: const [Color(0xFF8D67AB), Color(0xFF6C4D8A)],
        ),
        _StatCard(
          icon: Icons.group_rounded,
          label: 'Người dùng',
          value: _stats['users']?.toString() ?? '0',
          gradient: const [Color(0xFFDC148C), Color(0xFFAA106C)],
        ),
      ],
    );
  }

  Widget _buildRevenueSummaryCard() {
    final revenue = _stats['revenue'] ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateTo(AdminRevenueScreen()),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.monetization_on_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tổng doanh thu (VNĐ)',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${NumberFormat.decimalPattern().format(revenue)}đ',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCharts() {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    return Column(
      children: [
        _buildChartContainer(
          'Top 5 bài hát phổ biến',
          'Dựa trên tổng lượt nghe',
          _topSongs.isEmpty
              ? const _EmptyChart(message: 'Chưa có dữ liệu bài hát')
              : AspectRatio(
                  aspectRatio: 1.7,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (_topSongs.isNotEmpty ? (_topSongs[0]['totalViews'] as num).toDouble() * 1.2 : 20),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => _primaryColor,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_topSongs[groupIndex]['title']}\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              children: [
                                TextSpan(
                                  text: '${rod.toY.toInt()} lượt nghe',
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      barGroups: _topSongs.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: (entry.value['totalViews'] as num).toDouble(),
                              gradient: const LinearGradient(
                                colors: [_primaryColor, _accentColor],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
                                String title = _topSongs[index]['title'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    title.length > 5 ? '${title.substring(0, 5)}..' : title,
                                    style: TextStyle(fontSize: 10, color: _darkText.withOpacity(0.4), fontWeight: FontWeight.bold),
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
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: _darkText.withOpacity(0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _buildChartContainer(
          'Xu hướng nghe nhạc',
          'Thống kê trong 7 ngày qua',
          _dailyStats.isEmpty
              ? const _EmptyChart(message: 'Chưa có dữ liệu xu hướng')
              : AspectRatio(
                  aspectRatio: 1.7,
                  child: LineChart(
                    LineChartData(
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => _primaryColor,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final date = _dailyStats[spot.x.toInt()].date;
                              return LineTooltipItem(
                                '${date.day}/${date.month}\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                children: [
                                  TextSpan(
                                    text: '${spot.y.toInt()} lượt nghe',
                                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _dailyStats.asMap().entries.map((entry) {
                            return FlSpot(entry.key.toDouble(), entry.value.totalViews.toDouble());
                          }).toList(),
                          isCurved: true,
                          color: _primaryColor,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: _primaryColor,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [_primaryColor.withOpacity(0.2), _primaryColor.withOpacity(0)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
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
                                  style: TextStyle(fontSize: 10, color: _darkText.withOpacity(0.4), fontWeight: FontWeight.bold),
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
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: _darkText.withOpacity(0.05),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildArtistAnalytics() {
    return Consumer<AnalyticsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        return Column(
          children: [
            Row(
              children: [
                _buildMiniSummaryCard('Tổng lượt xem', provider.totalArtistViews.toString(), Colors.blue),
                const SizedBox(width: 12),
                _buildMiniSummaryCard('Nghệ sĩ HOT nhất', provider.mostViewedArtist, Colors.orange),
                const SizedBox(width: 12),
                _buildMiniSummaryCard('Trung bình', provider.averageViews.toStringAsFixed(0), Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
            _buildChartContainer(
              'Top 10 Nghệ sĩ phổ biến',
              'Sắp xếp theo tổng lượt nghe',
              provider.topArtists.isEmpty
                  ? const _EmptyChart(message: 'Chưa có dữ liệu nghệ sĩ')
                  : AspectRatio(
                      aspectRatio: 1.4, // Slightly taller to accommodate avatars
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: provider.topArtists.isNotEmpty ? (provider.topArtists[0]['totalViews'] as int).toDouble() * 1.3 : 20,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => _primaryColor,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${provider.topArtists[groupIndex]['name']}\n',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  children: [
                                    TextSpan(
                                      text: '${rod.toY.toInt()} lượt nghe',
                                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 12),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          barGroups: provider.topArtists.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            
                            // Rank-based gradients
                            LinearGradient gradient;
                            if (index == 0) {
                              gradient = const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              );
                            } else if (index == 1) {
                              gradient = const LinearGradient(
                                colors: [Color(0xFFC0C0C0), Color(0xFF8E8E8E)], // Silver
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              );
                            } else if (index == 2) {
                              gradient = const LinearGradient(
                                colors: [Color(0xFFCD7F32), Color(0xFF8B4513)], // Bronze
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              );
                            } else {
                              gradient = const LinearGradient(
                                colors: [_primaryColor, _accentColor],
                                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                              );
                            }

                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: (data['totalViews'] as int).toDouble(),
                                  gradient: gradient,
                                  width: 14,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                )
                              ],
                            );
                          }).toList(),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60, // Increased to fit avatar and name
                                getTitlesWidget: (value, meta) {
                                  int index = value.toInt();
                                  if (index >= 0 && index < provider.topArtists.length) {
                                    final artist = provider.topArtists[index];
                                    String name = artist['name'] ?? '';
                                    String? avatarUrl = artist['avatarUrl'];

                                    return SideTitleWidget(
                                      meta: meta,
                                      space: 8,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: _primaryColor.withOpacity(0.1),
                                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                                ? NetworkImage(avatarUrl)
                                                : null,
                                            child: avatarUrl == null || avatarUrl.isEmpty
                                                ? const Icon(Icons.person_rounded, size: 14, color: _primaryColor)
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            name.length > 5 ? '${name.substring(0, 4)}..' : name,
                                            style: TextStyle(fontSize: 9, color: _darkText.withOpacity(0.5), fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: _darkText.withOpacity(0.05),
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _darkText.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, 
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: _darkText.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(String title, String subtitle, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _darkText.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _darkText, fontWeight: FontWeight.w900, fontSize: 16)),
          Text(subtitle, style: TextStyle(color: _darkText.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          chart,
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
                color: const Color(0xFFDC148C),
                onTap: () => _navigateTo(const AdminUsersScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.music_note_rounded,
                title: 'Bài hát',
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
                color: const Color(0xFFE13300),
                onTap: () => _navigateTo(const AdminArtistsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.album_rounded,
                title: 'Album',
                color: const Color(0xFF8D67AB),
                onTap: () => _navigateTo(const AdminAlbumsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ManagementCard(
                icon: Icons.category_rounded,
                title: 'Thể loại',
                color: const Color(0xFF1DB954),
                onTap: () => _navigateTo(const AdminGenresScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.queue_music_rounded,
                title: 'Playlist',
                color: const Color(0xFF4A6E78),
                onTap: () => _navigateTo(const AdminPlaylistsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ManagementCard(
                icon: Icons.stars_rounded,
                title: 'Gói hội viên',
                color: const Color(0xFFDC148C),
                onTap: () => _navigateTo(const AdminSubscriptionsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ManagementCard(
                icon: Icons.monetization_on_rounded,
                title: 'Doanh thu',
                color: Colors.orange,
                onTap: () => _navigateTo(AdminRevenueScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ManagementCard(
                icon: Icons.pending_actions_rounded,
                title: 'Duyệt nghệ sĩ',
                color: const Color(0xFF0E6B5A),
                onTap: () => _navigateTo(const AdminArtistRequestsScreen()),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () {
          context.read<UserProvider>().signOut();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        },
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
        label: const Text(
          'Đăng xuất hệ thống',
          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 14),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.05),
        ),
      ),
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
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.15),
              size: 80,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
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
  final Color color;
  final VoidCallback onTap;

  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F1A).withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0A1F1A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: const Color(0xFF0A1F1A).withOpacity(0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, color: const Color(0xFF0A1F1A).withOpacity(0.05), size: 48),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.3), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton();

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          image: userProvider.photoUrl != null
              ? DecorationImage(image: NetworkImage(userProvider.photoUrl!), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: userProvider.photoUrl == null 
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
