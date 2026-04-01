import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum HistoryType { visit, scan }

class HistoryPage extends StatefulWidget {
  final HistoryType type;
  const HistoryPage({super.key, required this.type});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _historyFuture = Future.value([]);
      return;
    }

    final table = widget.type == HistoryType.visit
        ? 'riwayat_kunjungan'
        : 'riwayat_scan';
    final orderBy = widget.type == HistoryType.visit
        ? 'waktu_kunjungan'
        : 'waktu_scan';

    var query = Supabase.instance.client.from(table).select();

    if (widget.type == HistoryType.visit) {
      // Join with destinasi and hotel tables
      query = Supabase.instance.client.from('riwayat_kunjungan').select('''
        *,
        destinasi(nama, foto_utama_url),
        hotel(nama, foto_utama_url)
      ''');
    }

    _historyFuture = query
        .eq('user_id', user.id)
        .order(orderBy, ascending: false)
        .then((data) {
          final list = List<Map<String, dynamic>>.from(data as List);
          debugPrint('DEBUG: History Data Fetched: ${list.length} items');
          if (list.isNotEmpty) {
            debugPrint('DEBUG: First Item Sample: ${list[0]}');
          }
          return list;
        })
        .catchError((error) {
          debugPrint('DEBUG: Error Fetching History: $error');
          throw error;
        });
  }

  String _formatDate(String dateString) {
    try {
      final d = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(d);
    } catch (_) {
      try {
        final d = DateTime.parse(dateString);
        const months = [
          '',
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'Mei',
          'Jun',
          'Jul',
          'Agu',
          'Sep',
          'Okt',
          'Nov',
          'Des',
        ];
        return '${d.day} ${months[d.month]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return dateString;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == HistoryType.visit
        ? 'Riwayat Kunjungan'
        : 'Riwayat Scan AI';
    final emptyLabel = widget.type == HistoryType.visit
        ? 'Belum ada kunjungan'
        : 'Belum ada scan AI';
    final emptyIcon = widget.type == HistoryType.visit
        ? Icons.location_on_outlined
        : Icons.document_scanner_outlined;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white, // Match background
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal Memuat Data',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}'.contains('permission denied')
                            ? 'Izin akses ditolak. Pastikan tabel database sudah diatur dengan benar.'
                            : '${snapshot.error}'.contains('column')
                            ? 'Terjadi ketidaksesuaian kolom di Database. Hubungi admin.'
                            : 'Terjadi kesalahan: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _fetchHistory();
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(emptyIcon, emptyLabel);
            }

            final items = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _fetchHistory();
                });
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  String name = 'Objek';
                  String date = '';
                  IconData icon = Icons.history;

                  if (widget.type == HistoryType.visit) {
                    final destinasi = item['destinasi'];
                    final hotel = item['hotel'];

                    if (destinasi != null) {
                      name = destinasi['nama'] ?? 'Destinasi';
                      icon = Icons.location_on;
                    } else if (hotel != null) {
                      name = hotel['nama'] ?? 'Hotel';
                      icon = Icons.hotel_rounded;
                    }
                    date = item['waktu_kunjungan']?.toString() ?? '';
                  } else {
                    name = item['nama_objek'] ?? 'Scan AI';
                    date = item['waktu_scan']?.toString() ?? '';
                    icon = Icons.auto_awesome;
                  }

                  return _buildHistoryCard(
                    name,
                    date,
                    icon: icon,
                    onTap: () {
                      debugPrint(
                        'DEBUG: History Card Tapped: $name (Type: ${widget.type})',
                      );
                      _showDetail(item);
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    try {
      // Only show detail for scans
      if (widget.type != HistoryType.scan) {
        debugPrint('DEBUG: Skip detail because type is not scan');
        return;
      }

      debugPrint('DEBUG: Showing detail for: ${item['nama_objek']}');

      final name = item['nama_objek'] ?? 'Scan AI';
      final result =
          item['deskripsi_hasil'] ??
          'Deskripsi tidak tersedia untuk riwayat lama.';
      final date = _formatDate(item['waktu_scan']?.toString() ?? '');

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Scan Image if available
                if (item['foto_scan_url'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: item['foto_scan_url'],
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            date,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Hasil Analisis Delira:',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Text(
                    result,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('DEBUG: Error in _showDetail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menampilkan detail: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildEmptyState(IconData icon, String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aktivitas kamu akan muncul di sini setelah kamu menggunakan fitur ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    String name,
    String date, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon ??
                      (widget.type == HistoryType.visit
                          ? Icons.location_on
                          : Icons.auto_awesome),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
