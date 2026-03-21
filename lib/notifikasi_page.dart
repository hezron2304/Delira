import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  String _activeCategory = 'Semua';

  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Pembayaran Berhasil!',
      'content': 'Booking hotel Grand Mercure telah dikonfirmasi',
      'time': '2 jam lalu',
      'type': 'Pemesanan',
      'isUnread': true,
      'group': 'Hari ini',
      'icon': Icons.check_circle_outline,
      'iconColor': Colors.green,
    },
    {
      'title': 'Promo Spesial!',
      'content': 'Diskon 20% untuk booking hotel minggu ini',
      'time': '5 jam lalu',
      'type': 'Promo',
      'isUnread': true,
      'group': 'Hari ini',
      'icon': Icons.card_giftcard_outlined,
      'iconColor': Colors.orange,
    },
    {
      'title': 'Tips Wisata',
      'content': 'Jangan lewatkan Festival Budaya Medan bulan ini',
      'time': '8 jam lalu',
      'type': 'Info',
      'isUnread': false,
      'group': 'Hari ini',
      'icon': Icons.info_outline,
      'iconColor': Colors.blue,
    },
    {
      'title': 'Check-in Reminder',
      'content': 'Jangan lupa check-in besok pukul 14:00',
      'time': '1 hari lalu',
      'type': 'Pemesanan',
      'isUnread': false,
      'group': 'Kemarin',
      'icon': Icons.check_circle_outline,
      'iconColor': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifikasi',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border.withAlpha(50), height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          Expanded(
            child: ListView(
              children: [
                _buildGroup('Hari ini'),
                ..._notifications
                    .where((n) => (n['group'] == 'Hari ini' && (_activeCategory == 'Semua' || n['type'] == _activeCategory)))
                    .map((n) => _buildNotificationCard(n)),
                _buildGroup('Kemarin'),
                ..._notifications
                    .where((n) => (n['group'] == 'Kemarin' && (_activeCategory == 'Semua' || n['type'] == _activeCategory)))
                    .map((n) => _buildNotificationCard(n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = ['Semua', 'Pemesanan', 'Promo', 'Info'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: categories.map((cat) {
          bool isActive = _activeCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _activeCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? AppColors.primaryDark : AppColors.border),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroup(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: const Color(0xFFF5F5F3),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> n) {
    bool isUnread = n['isUnread'];
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 1), // Thin line between
      decoration: BoxDecoration(
        color: isUnread ? AppColors.surface : Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (n['iconColor'] as Color).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(n['icon'], color: n['iconColor'], size: 24),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n['title'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n['content'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  n['time'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
