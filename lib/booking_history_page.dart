import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/e_ticket_page.dart';
import 'package:delira/theme/app_colors.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  void _fetchBookings() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _bookingsFuture = Supabase.instance.client
          .schema('public')
          .from('booking')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
    } else {
      _bookingsFuture = Future.value([]);
    }
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String _formatDate(String dateString) {
    try {
      final d = DateTime.parse(dateString);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${d.day} ${months[d.month]} ${d.year}';
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Riwayat Pemesanan', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          } else if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                      child: const Icon(
                        Icons.history,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Belum Ada Pemesanan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Hotel yang kamu pesan akan muncul di sini',
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

          final bookings = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _fetchBookings();
              });
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = bookings[index];
                final status = b['status']?.toString().toLowerCase() ?? 'pending';
                final isPaid = status == 'paid' || status == 'completed';
                final isPayAtHotel = status == 'pay_at_hotel';

                Color statusColor = Colors.orange;
                String statusText = 'Menunggu Pembayaran';
                
                if (isPaid) {
                  statusColor = Colors.green;
                  statusText = 'Berhasil Terbayar';
                } else if (isPayAtHotel) {
                  statusColor = Colors.blue;
                  statusText = 'Bayar di Hotel';
                }

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: (isPaid || isPayAtHotel) ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ETicketPage(
                            orderId: b['kode_booking'] ?? '-',
                            guestName: b['nama_tamu'] ?? 'Tamu',
                            hotelName: b['hotel_name']?.toString() ?? 'Hotel Grand Mercure Medan',
                            roomType: 'Detail di Resepsionis',
                            checkIn: DateTime.tryParse(b['check_in'].toString()) ?? DateTime.now(),
                            checkOut: DateTime.tryParse(b['check_out'].toString()) ?? DateTime.now(),
                            totalAmount: (b['total_bayar'] as num?)?.toInt() ?? 0,
                          ),
                        ),
                      );
                    } : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesanan ini belum dibayar.')),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.inter(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.date_range, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text('${_formatDate(b['check_in']?.toString() ?? '')} - ${_formatDate(b['check_out']?.toString() ?? '')}', 
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(b['nama_tamu'] ?? '-', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.apartment, size: 16, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b['hotel_name']?.toString() ?? 'Hotel Grand Mercure Medan',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
                              Text('Rp ${_formatRupiah((b['total_bayar'] as num?)?.toInt() ?? 0)}', 
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark)),
                            ],
                          ),
                          if (isPaid || isPayAtHotel) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ETicketPage(
                                        orderId: b['kode_booking'] ?? '-',
                                        guestName: b['nama_tamu'] ?? 'Tamu',
                                        hotelName: b['hotel_name']?.toString() ?? 'Hotel Grand Mercure Medan',
                                        roomType: 'Tipe Kamar Standard',
                                        checkIn: DateTime.tryParse(b['check_in'].toString()) ?? DateTime.now(),
                                        checkOut: DateTime.tryParse(b['check_out'].toString()) ?? DateTime.now(),
                                        totalAmount: (b['total_bayar'] as num?)?.toInt() ?? 0,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
                                label: Text('Lihat E-Tiket', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
