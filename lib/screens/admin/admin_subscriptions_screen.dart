import 'package:flutter/material.dart';
import '../../firebase/firestore_service.dart';
import '../../models/subscription_package.dart';

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() => _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  List<SubscriptionPackage> _packages = [];
  bool _isLoading = true;

  static const _primaryColor = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);
  static const _bgColor = Color(0xFFF8FAF9);

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
          'Gói hội viên',
          style: TextStyle(color: _darkText, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            onPressed: _loadPackages,
            icon: const Icon(Icons.refresh_rounded, color: _darkText),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPackageDialog(),
        backgroundColor: const Color(0xFFDC148C),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Thêm gói mới', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _packages.isEmpty 
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPackages,
                  color: _primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: _packages.length,
                    itemBuilder: (context, index) {
                      return _PackageCard(
                        package: _packages[index],
                        onEdit: () => _showPackageDialog(package: _packages[index]),
                        onDelete: () => _deletePackage(_packages[index].id),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stars_rounded, size: 64, color: _darkText.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'Chưa có gói hội viên nào',
            style: TextStyle(color: _darkText.withOpacity(0.3), fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showPackageDialog({SubscriptionPackage? package}) {
    showDialog(
      context: context,
      builder: (context) => _PackageDialog(
        package: package,
        onSave: () => _loadPackages(),
      ),
    );
  }

  Future<void> _deletePackage(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Xóa gói hội viên', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Hành động này không thể hoàn tác. Bạn có chắc chắn muốn xóa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: _darkText.withOpacity(0.4), fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Xóa ngay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteSubscriptionPackage(id);
      _loadPackages();
    }
  }
}

class _PackageCard extends StatelessWidget {
  final SubscriptionPackage package;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PackageCard({required this.package, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F1A).withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(package.colorValue).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: Color(package.colorValue), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0A1F1A))),
                      Text('${package.price.toStringAsFixed(0)}đ / ${package.duration}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(package.colorValue))),
                    ],
                  ),
                ),
                _ActionButton(icon: Icons.edit_rounded, color: Colors.blueAccent, onTap: onEdit),
                const SizedBox(width: 8),
                _ActionButton(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: onDelete),
              ],
            ),
          ),
          if (package.features.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: package.features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: Color(package.colorValue).withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0A1F1A).withOpacity(0.6)))),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
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
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _PackageDialog extends StatefulWidget {
  final SubscriptionPackage? package;
  final VoidCallback onSave;

  const _PackageDialog({this.package, required this.onSave});

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _featuresController;
  late int _selectedColor;

  final List<int> _suggestedColors = [0xFF0E6B5A, 0xFF1DB954, 0xFFE13300, 0xFF8D67AB, 0xFFDC148C, 0xFF006450, 0xFF1E3264, 0xFFE8115B];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.package?.name ?? '');
    _priceController = TextEditingController(text: widget.package?.price.toString() ?? '');
    _durationController = TextEditingController(text: widget.package?.duration ?? '');
    _featuresController = TextEditingController(text: widget.package?.features.join('\n') ?? '');
    _selectedColor = widget.package?.colorValue ?? 0xFF0E6B5A;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(widget.package == null ? 'Thêm gói mới' : 'Sửa gói hội viên', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField('Tên gói (ví dụ: Premium)', _nameController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildField('Giá (VNĐ)', _priceController, keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('Thời hạn', _durationController, hint: '1 tháng')),
              ],
            ),
            const SizedBox(height: 16),
            _buildField('Tính năng (mỗi dòng 1 cái)', _featuresController, maxLines: 4),
            const SizedBox(height: 24),
            const Text('Màu sắc đại diện', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A1F1A))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _suggestedColors.map((colorVal) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorVal),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: _selectedColor == colorVal ? Border.all(color: const Color(0xFF0A1F1A), width: 3) : Border.all(color: Colors.white, width: 2),
                      boxShadow: [if (_selectedColor == colorVal) BoxShadow(color: Color(colorVal).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: _selectedColor == colorVal ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.4), fontWeight: FontWeight.bold))),
        ElevatedButton(
          onPressed: () async {
            if (_nameController.text.isEmpty) return;
            final data = {
              'name': _nameController.text.trim(),
              'price': double.tryParse(_priceController.text) ?? 0,
              'duration': _durationController.text.trim(),
              'features': _featuresController.text.split('\n').where((s) => s.isNotEmpty).toList(),
              'colorValue': _selectedColor,
            };
            if (widget.package == null) {
              await FirestoreService.createSubscriptionPackage(data);
            } else {
              await FirestoreService.updateSubscriptionPackage(widget.package!.id, data);
            }
            widget.onSave();
            if (context.mounted) Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC148C),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Xác nhận', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A1F1A))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF0A1F1A).withOpacity(0.03), borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), hintText: hint, hintStyle: TextStyle(color: const Color(0xFF0A1F1A).withOpacity(0.2))),
          ),
        ),
      ],
    );
  }
}
