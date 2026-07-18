import 'package:flutter/material.dart';
import '../../firebase/firestore_service.dart';
import '../../models/subscription_package.dart';

const _mintGreen = Color(0xFF0E6B5A);
const _darkText = Color(0xFF0A1F1A);

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  List<SubscriptionPackage> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() => _isLoading = true);
    try {
      final data = await FirestoreService.getSubscriptionPackages();
      _packages = data.map((d) => SubscriptionPackage.fromFirestore(d['id'], d)).toList();
    } catch (e) {
      debugPrint('Error loading packages: $e');
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Quản lý gói hội viên', style: TextStyle(color: _darkText, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPackageDialog(),
        backgroundColor: _mintGreen,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _mintGreen))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _packages.length,
              itemBuilder: (context, index) {
                final package = _packages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Color(package.colorValue), radius: 8),
                    title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${package.price.toStringAsFixed(0)}đ / ${package.duration}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showPackageDialog(package: package)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deletePackage(package.id)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showPackageDialog({SubscriptionPackage? package}) {
    final nameController = TextEditingController(text: package?.name ?? '');
    final priceController = TextEditingController(text: package?.price.toString() ?? '');
    final durationController = TextEditingController(text: package?.duration ?? '');
    final featuresController = TextEditingController(text: package?.features.join('\n') ?? '');
    int selectedColor = package?.colorValue ?? 0xFF0E6B5A;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(package == null ? 'Thêm gói mới' : 'Sửa gói'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên gói (Standard, Pro, Premium...)')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Giá (VNĐ)'), keyboardType: TextInputType.number),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Thời hạn (ví dụ: 1 tháng)')),
              TextField(controller: featuresController, decoration: const InputDecoration(labelText: 'Tính năng (mỗi dòng 1 cái)'), maxLines: 3),
              const SizedBox(height: 16),
              const Text('Màu sắc gói:'),
              Wrap(
                spacing: 8,
                children: [0xFF0E6B5A, 0xFFE13300, 0xFF8D67AB, 0xFFDC148C].map((c) => GestureDetector(
                  onTap: () => selectedColor = c,
                  child: CircleAvatar(backgroundColor: Color(c), radius: 12),
                )).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameController.text.trim(),
                'price': double.tryParse(priceController.text) ?? 0,
                'duration': durationController.text.trim(),
                'features': featuresController.text.split('\n').where((s) => s.isNotEmpty).toList(),
                'colorValue': selectedColor,
              };
              if (package == null) {
                await FirestoreService.createSubscriptionPackage(data);
              } else {
                await FirestoreService.updateSubscriptionPackage(package.id, data);
              }
              Navigator.pop(context);
              _loadPackages();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePackage(String id) async {
    await FirestoreService.deleteSubscriptionPackage(id);
    _loadPackages();
  }
}
