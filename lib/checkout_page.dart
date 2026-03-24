import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delira/theme/app_colors.dart';

class CheckoutPage extends StatefulWidget {
  final String hotelName;
  final String roomType;
  final int roomPrice;
  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final int rooms;
  final int adults;
  final int children;

  const CheckoutPage({
    super.key,
    required this.hotelName,
    required this.roomType,
    required this.roomPrice,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.rooms,
    required this.adults,
    required this.children,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specialRequestController = TextEditingController();
  final _promoController = TextEditingController();

  String _selectedPayment = 'transfer_bank';
  bool _saveGuestData = false;
  bool _isLoading = false;
  int _promoDiscount = 0;
  String _appliedPromo = '';

  @override
  void initState() {
    super.initState();
    _emailController.text =
        Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specialRequestController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> _handlePayment() async {
    // 1. Validate form
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi data tamu terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Generate order ID
    final orderId = 'DELIRA-${DateTime.now().millisecondsSinceEpoch}';

    // 3. Calculate total
    final subtotal = widget.roomPrice * widget.nights * widget.rooms;
    final tax = (subtotal * 0.11).round();
    const serviceFee = 50000;
    final total = subtotal + tax + serviceFee - _promoDiscount;

    // 4. Save booking to Supabase
    try {
      await Supabase.instance.client.from('bookings').insert({
        'order_id': orderId,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'hotel_name': widget.hotelName,
        'room_type': widget.roomType,
        'check_in': widget.checkIn.toIso8601String(),
        'check_out': widget.checkOut.toIso8601String(),
        'nights': widget.nights,
        'rooms': widget.rooms,
        'adults': widget.adults,
        'children': widget.children,
        'guest_name': _nameController.text.trim(),
        'guest_phone': _phoneController.text.trim(),
        'guest_email': _emailController.text.trim(),
        'payment_method': _selectedPayment,
        'total_amount': total,
        'status': _selectedPayment == 'pay_at_hotel' ? 'pay_at_hotel' : 'pending',
        'special_request': _specialRequestController.text.trim(),
        'promo_code': _appliedPromo.isEmpty ? null : _appliedPromo,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan pesanan: $e')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 5. Handle payment method
    if (_selectedPayment == 'pay_at_hotel') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Pesanan Berhasil!'),
          content: Text(
            'Pesanan Anda di ${widget.hotelName} telah dikonfirmasi.\n'
            'Pembayaran dilakukan saat check-in.\n\n'
            'ID Pesanan: $orderId'
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    // 6. Online payments (Pakasir)
    const pakasirSlug = 'delira'; 
    const pakasirApiKey = 'CyedHODmAomCy1xy2f49rbQPJdEDFw54'; 

    final paymentUrl = 'https://app.pakasir.com/pay/$pakasirSlug/$total?order_id=$orderId';

    try {
      final uri = Uri.parse(paymentUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka halaman pembayaran')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildPaymentStatusDialog(orderId, total, pakasirSlug, pakasirApiKey),
    );
  }

  Widget _buildPaymentStatusDialog(String orderId, int total, String slug, String apiKey) {
    bool isChecking = false;
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Selesaikan Pembayaran'),
        content: const Text(
          'Selesaikan pembayaran di halaman Pakasir, '
          'lalu tekan tombol di bawah setelah selesai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: isChecking ? null : () async {
              setDialogState(() => isChecking = true);
              try {
                final response = await http.get(Uri.parse(
                  'https://app.pakasir.com/api/transactiondetail'
                  '?project=$slug&amount=$total&order_id=$orderId&api_key=$apiKey'
                ));
                final data = jsonDecode(response.body);
                if (data['status'] == 'completed') {
                  await Supabase.instance.client
                      .from('bookings')
                      .update({'status': 'paid'})
                      .eq('order_id', orderId);
                  
                  if (!mounted) return;
                  Navigator.of(context).pop(); // Close processing dialog
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AlertDialog(
                      title: const Text('Pembayaran Berhasil! 🎉'),
                      content: Text('ID Pesanan: $orderId\nTerima kasih telah memesan di Delira!'),
                      actions: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text('Kembali ke Beranda',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                } else {
                  setDialogState(() => isChecking = false);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pembayaran belum selesai. Coba lagi.')),
                  );
                }
              } catch (e) {
                setDialogState(() => isChecking = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal mengecek status pembayaran')),
                );
              }
            },
            child: isChecking
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Cek Status Pembayaran',
                    style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _applyPromo() {
    FocusScope.of(context).unfocus();
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'MEDAN10') {
      setState(() {
        _promoDiscount = 50000;
        _appliedPromo = 'MEDAN10';
        _promoController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode promo berhasil digunakan!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode promo tidak valid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.roomPrice * widget.nights * widget.rooms;
    final tax = (subtotal * 0.11).round();
    const serviceFee = 50000;
    final totalAmount = subtotal + tax + serviceFee - _promoDiscount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Checkout', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSection1(),
            const SizedBox(height: 24),
            _buildSection2(),
            const SizedBox(height: 24),
            _buildSection3(),
            const SizedBox(height: 24),
            _buildSection4(),
            const SizedBox(height: 24),
            _buildSection5(),
            const SizedBox(height: 24),
            _buildSection6(subtotal, tax, serviceFee, totalAmount),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Pembayaran', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Rp ${_formatRupiah(totalAmount)}', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Bayar Sekarang →',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection1() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Info Pesanan', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.hotel, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.hotelName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(widget.roomType, style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Check-in • Check-out', '${_formatDate(widget.checkIn)} - ${_formatDate(widget.checkOut)}'),
          const SizedBox(height: 8),
          _buildInfoRow('Jumlah malam', '${widget.nights} malam'),
          const SizedBox(height: 8),
          _buildInfoRow('Kamar & Tamu', '${widget.rooms} Kamar, ${widget.adults} Dewasa${widget.children > 0 ? ', ${widget.children} Anak' : ''}'),
        ],
      ),
    );
  }

  Widget _buildSection2() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data Tamu', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildTextField(_nameController, 'Nama lengkap tamu', Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField(_phoneController, 'Nomor telepon', Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(_emailController, 'Alamat email', Icons.email_outlined, type: TextInputType.emailAddress),
          const SizedBox(height: 8),
          Theme(
            data: ThemeData(unselectedWidgetColor: Colors.grey),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: Text('Simpan data untuk pemesanan berikutnya', 
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700)),
              value: _saveGuestData,
              onChanged: (val) => setState(() => _saveGuestData = val ?? false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection3() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Permintaan Khusus', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            controller: _specialRequestController,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Contoh: kamar lantai tinggi, pillow extra, dll',
              hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(16),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection4() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kode Promo', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(_promoController, 'Masukkan kode promo', Icons.local_offer_outlined)),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _applyPromo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Pakai', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_appliedPromo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_appliedPromo - Diskon Rp ${_formatRupiah(_promoDiscount)}', 
                  style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _appliedPromo = '';
                      _promoDiscount = 0;
                    });
                  },
                  child: Text('Hapus', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSection5() {
    final options = [
      {'val': 'transfer_bank', 'title': 'Transfer Bank', 'sub': 'BCA, Mandiri, BNI', 'ic': Icons.account_balance, 'c': AppColors.primary},
      {'val': 'qris', 'title': 'QRIS', 'sub': 'Scan QR Code', 'ic': Icons.qr_code, 'c': AppColors.primary},
      {'val': 'gopay', 'title': 'GoPay', 'sub': 'E-Wallet', 'ic': Icons.account_balance_wallet, 'c': Colors.green},
      {'val': 'ovo', 'title': 'OVO', 'sub': 'E-Wallet', 'ic': Icons.account_balance_wallet, 'c': Colors.purple},
      {'val': 'kartu_kredit', 'title': 'Kartu Kredit/Debit', 'sub': 'Visa, Mastercard', 'ic': Icons.credit_card, 'c': Colors.blue},
      {'val': 'pay_at_hotel', 'title': 'Bayar di Hotel', 'sub': 'Cash/Card', 'ic': Icons.store, 'c': Colors.orange},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Metode Pembayaran', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = _selectedPayment == opt['val'];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withAlpha(12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
              ),
              child: RadioListTile<String>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: AppColors.primary,
                value: opt['val'] as String,
                groupValue: _selectedPayment,
                onChanged: (val) => setState(() => _selectedPayment = val!),
                title: Text(opt['title'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(opt['sub'] as String, style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                secondary: Icon(opt['ic'] as IconData, color: opt['c'] as Color, size: 28),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSection6(int subtotal, int tax, int serviceFee, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan Biaya', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildInfoRow('Harga kamar × ${widget.nights} malam', 'Rp ${_formatRupiah(subtotal)}'),
          const SizedBox(height: 8),
          _buildInfoRow('Pajak (11%)', 'Rp ${_formatRupiah(tax)}'),
          const SizedBox(height: 8),
          _buildInfoRow('Biaya layanan', 'Rp ${_formatRupiah(serviceFee)}'),
          if (_promoDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Diskon promo', style: GoogleFonts.inter(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('- Rp ${_formatRupiah(_promoDiscount)}', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Rp ${_formatRupiah(total)}', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? type}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withAlpha(70))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
