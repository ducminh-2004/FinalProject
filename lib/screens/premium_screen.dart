import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../firebase/firestore_service.dart';
import '../models/subscription_package.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  List<SubscriptionPackage> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    try {
      final data = await FirestoreService.getSubscriptionPackages();
      setState(() {
        _packages = data.map((d) => SubscriptionPackage.fromFirestore(d['id'], d)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    const mintGreen = Color(0xFF0E6B5A);
    const darkText = Color(0xFF0A1F1A);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F9F8),
        elevation: 0,
        title: const Text('Premium', style: TextStyle(color: darkText, fontWeight: FontWeight.w800, fontSize: 24)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: mintGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildCurrentStatus(userProvider),
                  const SizedBox(height: 30),
                  const Text('Chọn gói nâng cấp', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkText)),
                  const SizedBox(height: 20),
                  ..._packages.map((p) => _PackageCard(package: p, currentTier: userProvider.subscriptionTier)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatus(UserProvider user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E6B5A), Color(0xFF0A3F35)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          const Text('Gói hiện tại của bạn', style: TextStyle(color: Colors.white70, fontSize: 14)),
          Text(
            user.subscriptionTier.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final SubscriptionPackage package;
  final String currentTier;

  const _PackageCard({required this.package, required this.currentTier});

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = currentTier == package.name;
    final color = Color(package.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isCurrent ? Border.all(color: color, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(package.name, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Hiện tại', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${package.price.toStringAsFixed(0)}đ / ${package.duration}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Divider(height: 32),
          ...package.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Fix alignment
              children: [
                Icon(Icons.check_circle_rounded, color: color, size: 18),
                const SizedBox(width: 12),
                Expanded( // Fix overflow
                  child: Text(
                    f, 
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent ? null : () => _confirmUpgrade(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(isCurrent ? 'Đang sử dụng' : 'Nâng cấp ngay', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmUpgrade(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận nâng cấp'),
        content: Text('Bạn có muốn nâng cấp lên gói ${package.name} với giá ${package.price.toStringAsFixed(0)}đ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final name = package.name;
              await context.read<UserProvider>().upgradeSubscription(name, package.price);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nâng cấp lên $name thành công!')));
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }
}
