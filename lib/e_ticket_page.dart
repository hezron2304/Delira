import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:delira/theme/app_colors.dart';

class ETicketPage extends StatefulWidget {
  final String orderId;
  final String guestName;
  final String hotelName;
  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final int totalAmount;

  const ETicketPage({
    super.key,
    required this.orderId,
    required this.guestName,
    required this.hotelName,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.totalAmount,
  });

  @override
  State<ETicketPage> createState() => _ETicketPageState();
}

class _ETicketPageState extends State<ETicketPage> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String _formatDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> _captureAndDownload() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        await Gal.putImageBytes(image);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tiket berhasil disimpan ke Galeri!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan tiket: $e')),
        );
      }
    }
  }

  Future<void> _captureAndShare() async {
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = await File('${directory.path}/tiket_${widget.orderId}.png').create();
        await imagePath.writeAsBytes(image);
        
        await Share.shareXFiles([XFile(imagePath.path)], text: 'Cek E-Tiket saya untuk pemesanan di ${widget.hotelName}!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan tiket: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('E-Tiket', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 64),
                      const SizedBox(height: 16),
                      Text('Booking Verified', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      Text(widget.orderId, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(height: 24),
                      
                      QrImageView(
                        data: widget.orderId,
                        version: QrVersions.auto,
                        size: 180.0,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      const SizedBox(height: 24),
                      
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      _buildInfoRow('Nama Tamu', widget.guestName),
                      const SizedBox(height: 12),
                      _buildInfoRow('Hotel', widget.hotelName),
                      const SizedBox(height: 12),
                      _buildInfoRow('Kamar', widget.roomType),
                      const SizedBox(height: 12),
                      _buildInfoRow('Check-in', _formatDate(widget.checkIn)),
                      const SizedBox(height: 12),
                      _buildInfoRow('Check-out', _formatDate(widget.checkOut)),
                      
                      const SizedBox(height: 24),
                      Text('Tunjukkan E-Tiket atau QR Code ini di meja resepsionis saat check-in.', 
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _captureAndDownload,
                  icon: const Icon(Icons.file_download, color: Colors.white),
                  label: Text('Unduh Tiket', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _captureAndShare,
                  icon: const Icon(Icons.share, color: AppColors.primary),
                  label: Text('Bagikan', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
