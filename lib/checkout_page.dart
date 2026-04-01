import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/login_page.dart';
import 'package:delira/payment_success_page.dart';
import 'package:delira/payment_webview_page.dart';

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
  final String hotelId;
  final String kamarId;

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
    required this.hotelId,
    required this.kamarId,
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
  bool _isLoadingPromo = false;
  int _promoDiscount = 0;
  String _appliedPromo = '';
  String? _appliedPromoExpiry;
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  double _discountValue = 0;

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

  String _formatDateWithDay(DateTime d) {
    const days = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
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
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  Future<void> _handlePayment() async {
    final session = Supabase.instance.client.auth.currentSession;
    final user = Supabase.instance.client.auth.currentUser;

    if (session == null || session.isExpired || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi telah habis, silakan masuk kembali.'),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      return;
    }

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
    final payload = {
      'kode_booking': orderId,
      'user_id': user.id,
      'hotel_id': widget.hotelId,
      'kamar_id': widget.kamarId,
      'nama_tamu': _nameController.text.trim(),
      'email_tamu': _emailController.text.trim(),
      'hp_tamu': _phoneController.text.trim(),
      'check_in': widget.checkIn.toIso8601String().split('T')[0],
      'check_out': widget.checkOut.toIso8601String().split('T')[0],
      'jumlah_malam': widget.nights.toInt(),
      'jumlah_tamu': (widget.adults + widget.children).toInt(),
      'harga_per_malam': widget.roomPrice.toInt(),
      'subtotal': subtotal.toInt(),
      'diskon': _promoDiscount.toInt(),
      'total_bayar': total.toInt(),
      'status': 'pending',
      'metode_pembayaran': _selectedPayment,
      'catatan': _specialRequestController.text.trim(),
    };

    debugPrint("--- [DEEP TRACE: PAYLOAD AUDIT] ---");
    debugPrint("Payload: ${jsonEncode(payload)}");
    debugPrint("Session JWT valid? ${session.accessToken.isNotEmpty}");
    debugPrint("Role: ${user.role}");

    try {
      await Supabase.instance.client
          .schema('public')
          .from('booking')
          .insert(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      debugPrint("--- [DEEP TRACE: ERROR HANDLING] ---");
      if (e is PostgrestException) {
        debugPrint("PostgrestException Code: ${e.code}");
        debugPrint("PostgrestException Message: ${e.message}");
        debugPrint("PostgrestException Details: ${e.details}");
        debugPrint("PostgrestException Hint: ${e.hint}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB Error [${e.code}]: ${e.message}')),
        );
      } else {
        debugPrint("Unknown Exception: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 5. Handle payment method
    if (_selectedPayment == 'pay_at_hotel') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(
            hotelName: widget.hotelName,
            roomType: widget.roomType,
            checkIn: widget.checkIn,
            checkOut: widget.checkOut,
            orderId: orderId,
            guestName: _nameController.text.trim(),
            totalAmount: total,
            email: _emailController.text.trim(),
          ),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    // 6. Online payments (Pakasir)
    final paymentUrl =
        'https://app.pakasir.com/pay/delira/$total?order_id=$orderId';

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentWebViewPage(
          paymentUrl: paymentUrl,
          orderId: orderId,
          hotelName: widget.hotelName,
          roomType: widget.roomType,
          checkIn: widget.checkIn,
          checkOut: widget.checkOut,
          guestName: _nameController.text.trim(),
          totalAmount: total,
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  Future<void> _applyPromo() async {
    FocusScope.of(context).unfocus();
    final code = _promoController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _isLoadingPromo = true;
      _appliedPromo = '';
      _appliedPromoExpiry = null;
      _promoDiscount = 0;
      _discountValue = 0;
    });

    try {
      final subtotal = widget.roomPrice * widget.nights * widget.rooms;

      final data = await Supabase.instance.client
          .from('promo_codes')
          .select()
          .eq('code', code)
          .eq('is_active', true)
          .maybeSingle();

      debugPrint('DEBUG: Promo query response: $data');

      if (data == null) {
        throw 'Kode promo tidak valid atau tidak aktif';
      }

      // 1. Check expiry
      if (data['expiry_date'] != null) {
        final expiry = DateTime.parse(data['expiry_date']);
        if (expiry.isBefore(DateTime.now())) {
          throw 'Kode promo sudah kadaluarsa';
        }
      }

      // 2. Check min purchase
      final minPurchase = (data['min_purchase'] ?? 0).toDouble();
      if (subtotal < minPurchase) {
        throw 'Minimal pembelian untuk kode ini adalah Rp ${_formatRupiah(minPurchase.toInt())}';
      }

      // 3. Apply discount
      final type = data['discount_type'] as String;
      final val = (data['discount_value'] as num).toDouble();

      setState(() {
        _appliedPromo = code;
        _discountType = type;
        _discountValue = val;
        _appliedPromoExpiry = data['expiry_date'];
        
        if (type == 'percentage') {
          _promoDiscount = (subtotal * (val / 100)).round();
        } else {
          _promoDiscount = val.round();
        }
        
        _promoController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode promo berhasil digunakan!'),
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Terjadi kesalahan sistem';

      if (e is PostgrestException) {
        // Menangani error spesifik dari Supabase (misal: tabel belum dibuat)
        if (e.code == '42P01') {
          errorMessage =
              'Sistem promo sedang dalam pemeliharaan (Table not found)';
        } else if (e.code == '42501') {
          errorMessage = 'Izin akses promo ditolak (Permission denied)';
        } else {
          errorMessage = 'Database Error: ${e.message}';
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPromo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.roomPrice * widget.nights * widget.rooms;
    final tax = (subtotal * 0.11).round();
    const serviceFee = 50000;

    // Recalculate discount if it's percentage (in case nights/rooms changed, although unlikely here)
    int currentDiscount = _promoDiscount;
    if (_appliedPromo.isNotEmpty && _discountType == 'percentage') {
      currentDiscount = (subtotal * (_discountValue / 100)).round();
    }

    final totalAmount = subtotal + tax + serviceFee - currentDiscount;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 130,
        ),
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
                _buildSection6(subtotal, tax, serviceFee, currentDiscount, totalAmount),
              ],
            ),
          ),
        ),
        bottomSheet: isKeyboardOpen ? null : Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 50),
          decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
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
                    Text(
                      'Total Pembayaran',
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${_formatRupiah(totalAmount)}',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handlePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Bayar Sekarang →',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
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
          Text(
            'Info Pesanan',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.hotel, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.hotelName,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.roomType,
                      style: GoogleFonts.inter(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Check-in', _formatDateWithDay(widget.checkIn)),
          const SizedBox(height: 6),
          _buildInfoRow('Check-out', _formatDateWithDay(widget.checkOut)),
          const SizedBox(height: 8),
          _buildInfoRow('Jumlah malam', '${widget.nights} malam'),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Kamar & Tamu',
            '${widget.rooms} Kamar, ${widget.adults} Dewasa${widget.children > 0 ? ', ${widget.children} Anak' : ''}',
          ),
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
          Text(
            'Data Tamu',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _nameController,
            'Nama lengkap tamu',
            Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _phoneController,
            'Nomor telepon',
            Icons.phone_outlined,
            type: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _emailController,
            'Alamat email',
            Icons.email_outlined,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          Theme(
            data: ThemeData(unselectedWidgetColor: Colors.grey),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.primary,
              title: Text(
                'Simpan data untuk pemesanan berikutnya',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
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
          Text(
            'Permintaan Khusus',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _specialRequestController,
            maxLines: 4,
            style: GoogleFonts.inter(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Contoh: kamar lantai tinggi, pillow extra, dll',
              hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          Text(
            'Kode Promo',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _promoController,
                  'Masukkan kode promo',
                  Icons.local_offer_outlined,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _applyPromo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoadingPromo
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Pakai',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_appliedPromo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _discountType == 'percentage'
                            ? '$_appliedPromo - Diskon ${_discountValue.toInt()}% (Rp ${_formatRupiah(_promoDiscount)})'
                            : '$_appliedPromo - Diskon Rp ${_formatRupiah(_promoDiscount)}',
                        style: GoogleFonts.inter(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _appliedPromo = '';
                          _appliedPromoExpiry = null;
                          _promoDiscount = 0;
                        });
                      },
                      child: Text(
                        'Hapus',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_appliedPromoExpiry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Berlaku hingga: ${_formatDateWithDay(DateTime.parse(_appliedPromoExpiry!))}',
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection5() {
    final options = [
      {
        'val': 'bayar_online',
        'title': 'Bayar Online',
        'sub': 'QRIS, Virtual Account, dan E-Wallet (via Pakasir)',
        'ic': Icons.payment,
        'c': AppColors.primary,
      },
      {
        'val': 'pay_at_hotel',
        'title': 'Bayar di Hotel',
        'sub': 'Bayar tunai atau kartu saat check-in',
        'ic': Icons.store_mall_directory,
        'c': Colors.orange,
      },
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
            child: Text(
              'Metode Pembayaran',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = _selectedPayment == opt['val'];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withAlpha(12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.grey.withAlpha(60),
                ),
              ),
              child: RadioListTile<String>(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: AppColors.primary,
                value: opt['val'] as String,
                // ignore: deprecated_member_use
                groupValue: _selectedPayment,
                // ignore: deprecated_member_use
                onChanged: (val) => setState(() => _selectedPayment = val!),
                title: Text(
                  opt['title'] as String,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  opt['sub'] as String,
                  style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                ),
                secondary: Icon(
                  opt['ic'] as IconData,
                  color: opt['c'] as Color,
                  size: 28,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSection6(int subtotal, int tax, int serviceFee, int discount, int total) {
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
          Text(
            'Ringkasan Biaya',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Harga kamar × ${widget.nights} malam',
            'Rp ${_formatRupiah(subtotal)}',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Pajak (11%)', 'Rp ${_formatRupiah(tax)}'),
          const SizedBox(height: 8),
          _buildInfoRow('Biaya layanan', 'Rp ${_formatRupiah(serviceFee)}'),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diskon promo',
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '- Rp ${_formatRupiah(discount)}',
                  style: GoogleFonts.inter(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
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
              Text(
                'Total',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Rp ${_formatRupiah(total)}',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
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
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? type,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withAlpha(70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
