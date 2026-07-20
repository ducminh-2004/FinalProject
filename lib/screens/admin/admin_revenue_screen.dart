import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../firebase/firestore_service.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> {
  List<Map<String, dynamic>> _logs = [];
  double _totalRevenue = 0;
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirestoreService.getSubscriptionLogs(),
        FirestoreService.getTotalRevenue(),
      ]);
      _logs = results[0] as List<Map<String, dynamic>>;
      _totalRevenue = results[1] as double;
    } catch (e) {
      debugPrint('Error loading revenue data: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _darkText, size: 20),
        ),
        title: const Text(
          'Doanh thu & Lịch sử',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : Column(
              children: [
                _buildRevenueHeader(currencyFormat),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20, color: _primaryColor),
                      SizedBox(width: 8),
                      Text(
                        'Lịch sử giao dịch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkText),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _logs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final date = (log['timestamp'] as dynamic).toDate();
                            return _TransactionLogTile(
                              email: log['userEmail'],
                              packageName: log['packageName'],
                              price: (log['price'] as num).toDouble(),
                              date: date,
                              currencyFormat: currencyFormat,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRevenueHeader(NumberFormat format) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF1DB954)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng doanh thu hệ thống',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            format.format(_totalRevenue),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_logs.length} giao dịch thành công',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
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
          Icon(Icons.receipt_long_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Chưa có giao dịch nào phát sinh',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TransactionLogTile extends StatelessWidget {
  final String email;
  final String packageName;
  final double price;
  final DateTime date;
  final NumberFormat currencyFormat;

  const _TransactionLogTile({
    required this.email,
    required this.packageName,
    required this.price,
    required this.date,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0E6B5A).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF0E6B5A), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A1F1A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã mua gói $packageName',
                  style: TextStyle(fontSize: 12, color: const Color(0xFF0A1F1A).withOpacity(0.5), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${currencyFormat.format(price)}',
                style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.w900, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM, HH:mm').format(date),
                style: TextStyle(fontSize: 10, color: const Color(0xFF0A1F1A).withOpacity(0.3), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
