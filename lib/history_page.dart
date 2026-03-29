import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:intl/intl.dart';

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

    final table = widget.type == HistoryType.visit ? 'riwayat_kunjungan' : 'riwayat_scan';
    final orderBy = widget.type == HistoryType.visit ? 'waktu_kunjungan' : 'waktu_scan';

    _historyFuture = Supabase.instance.client
        .from(table)
        .select()
        .eq('user_id', user.id)
        .order(orderBy, ascending: false)
        .then((data) => List<Map<String, dynamic>>.from(data));
  }

  String _formatDate(String dateString) {
    try {
      final d = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(d);
    } catch (_) {
      try {
        final d = DateTime.parse(dateString);
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        return '${d.day} ${months[d.month]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        return dateString;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == HistoryType.visit ? 'Riwayat Kunjungan' : 'Riwayat Scan AI';
    final emptyLabel = widget.type == HistoryType.visit ? 'Belum ada kunjungan' : 'Belum ada scan AI';
    final emptyIcon = widget.type == HistoryType.visit ? Icons.location_on_outlined : Icons.document_scanner_outlined;

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
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            } else if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Terjadi kesalahan: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final name = widget.type == HistoryType.visit 
                      ? (item['nama_destinasi'] ?? 'Destinasi') 
                      : (item['nama_objek'] ?? 'Scan AI');
                  final date = widget.type == HistoryType.visit 
                      ? item['waktu_kunjungan'] 
                      : item['waktu_scan'];

                  return _buildHistoryCard(name, date.toString());
                },
              ),
            );
          },
        ),
      ),
    );
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

  Widget _buildHistoryCard(String name, String date) {
    return Container(
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
              widget.type == HistoryType.visit ? Icons.location_on : Icons.auto_awesome,
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
    );
  }
}
