import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:intl/intl.dart';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  String _activeCategory = 'Semua';
  List<Map<String, dynamic>> _notifications = [];
  Set<String> _readIds = {}; // Menyimpan ID notifikasi yang sudah dibaca user ini
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _markNotificationsAsRead(List<Map<String, dynamic>> notifs) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || notifs.isEmpty) return;

      // Filter notifikasi yang belum ada di daftar baca (_readIds)
      final unreadNotifs = notifs.where((n) => !_readIds.contains(n['id'])).toList();
      if (unreadNotifs.isEmpty) return;

      // Masukkan ke tabel pivot notifikasi_dibaca agar status baca tersimpan per-user
      final List<Map<String, dynamic>> batchUpdate = unreadNotifs.map((n) => {
        'notifikasi_id': n['id'],
        'user_id': user.id,
      }).toList();

      await Supabase.instance.client
          .from('notifikasi_dibaca')
          .upsert(batchUpdate);
      
      // Update local state agar titik hijau langsung hilang
      if (mounted) {
        setState(() {
          _readIds.addAll(unreadNotifs.map((n) => n['id'].toString()));
        });
      }
    } catch (e) {
      debugPrint('AUTO_MARK_READ_ERROR: $e');
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      // 1. Ambil semua notifikasi (global + personal)
      final notificationsResponse = await Supabase.instance.client
          .from('notifikasi')
          .select('*')
          .or('user_id.is.null,user_id.eq.${user?.id ?? ''}')
          .order('created_at', ascending: false);

      // 2. Ambil daftar ID yang sudah dibaca oleh user ini dari tabel pivot
      final List<String> readIds = [];
      if (user != null) {
        final readResponse = await Supabase.instance.client
            .from('notifikasi_dibaca')
            .select('notifikasi_id')
            .eq('user_id', user.id);
        
        for (var row in (readResponse as List)) {
          readIds.add(row['notifikasi_id'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(notificationsResponse);
          _readIds = readIds.toSet();
          _isLoading = false;
        });

        // Otomatis tandai sebagai dibaca begitu halaman dibuka
        _markNotificationsAsRead(_notifications);
      }
    } catch (e) {
      debugPrint('FETCH_NOTIFIKASI_ERROR: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat notifikasi.';
          _isLoading = false;
        });
      }
    }
  }

  // Get icon based on type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pemesanan':
        return Icons.check_circle_outline;
      case 'promo':
        return Icons.card_giftcard_outlined;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  // Get color based on type
  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'pemesanan':
        return Colors.green;
      case 'promo':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Formatting time (e.g. 2 jam lalu, 1 hari lalu)
  String _formatTime(String createdAt) {
    final date = DateTime.parse(createdAt);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

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
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _notifications.isEmpty 
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _fetchNotifications,
                        color: AppColors.primary,
                        child: _buildNotificationList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    final filteredNodes = _notifications.where((n) => 
      _activeCategory == 'Semua' || n['tipe'] == _activeCategory
    ).toList();

    if (filteredNodes.isEmpty) return _buildEmptyState(message: 'Tidak ada notifikasi di kategori ini.');

    // Flatten logic for lazy list with group headers
    final now = DateTime.now();
    final List<dynamic> flattenedItems = [];

    final todayNotifs = filteredNodes.where((n) {
      final date = DateTime.parse(n['created_at']);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).toList();

    final yesterdayNotifs = filteredNodes.where((n) {
      final date = DateTime.parse(n['created_at']);
      final yesterday = now.subtract(const Duration(days: 1));
      return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
    }).toList();

    final olderNotifs = filteredNodes.where((n) {
      final date = DateTime.parse(n['created_at']);
      final yesterday = now.subtract(const Duration(days: 1));
      return date.isBefore(DateTime(yesterday.year, yesterday.month, yesterday.day));
    }).toList();

    if (todayNotifs.isNotEmpty) {
      flattenedItems.add('Hari ini');
      flattenedItems.addAll(todayNotifs);
    }
    if (yesterdayNotifs.isNotEmpty) {
      flattenedItems.add('Kemarin');
      flattenedItems.addAll(yesterdayNotifs);
    }
    if (olderNotifs.isNotEmpty) {
      flattenedItems.add('Lebih Lama');
      flattenedItems.addAll(olderNotifs);
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: flattenedItems.length,
      itemBuilder: (context, index) {
        final item = flattenedItems[index];
        if (item is String) {
          return _buildGroup(item);
        }
        return _buildNotificationCard(item);
      },
    );
  }

  Widget _buildEmptyState({String? message}) {
    final bool isError = _errorMessage != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.notifications_off_outlined, 
              size: 64, 
              color: isError ? Colors.redAccent.withAlpha(100) : Colors.grey[300]
            ),
            const SizedBox(height: 16),
            Text(
              message ?? (_errorMessage ?? 'Belum ada notifikasi.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: isError ? Colors.redAccent : Colors.grey, fontSize: 14),
            ),
            if (isError) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  onPressed: _fetchNotifications,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
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
    // Cek apakah ID notifikasi ada di daftar baca user ini
    bool isReadByMe = _readIds.contains(n['id'].toString());
    String type = n['tipe'] ?? 'Info';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: !isReadByMe ? AppColors.surface : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(20))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getColorForType(type).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(_getIconForType(type), color: _getColorForType(type), size: 24),
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
                      n['judul'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    if (!isReadByMe)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n['pesan'],
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(n['created_at']),
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
