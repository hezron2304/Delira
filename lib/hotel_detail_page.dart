import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delira/room_selection_page.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';

class HotelDetailPage extends StatefulWidget {
  final Map<String, dynamic> hotel;

  const HotelDetailPage({super.key, required this.hotel});

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  Map<String, dynamic> get hotel => widget.hotel;
  List<Map<String, dynamic>> _galeriList = [];
  bool _isFavorited = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // Baca langsung dari nested join 'hotel_galeri' yang sudah ada di payload hotel
    final raw = hotel['hotel_galeri'];
    if (raw is List) {
      _galeriList = List<Map<String, dynamic>>.from(raw);
      // Sort berdasarkan urutan secara ascending (sisi Dart)
      _galeriList.sort(
        (a, b) =>
            ((a['urutan'] as num?) ?? 0).compareTo((b['urutan'] as num?) ?? 0),
      );
    }
    _fetchFavoriteStatus();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationUtils.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
    }
  }

  Future<void> _openNavigation() async {
    final lat = hotel['latitude'];
    final lng = hotel['longitude'];

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koordinat lokasi tidak tersedia')),
      );
      return;
    }

    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi peta')),
      );
    }
  }

  Future<void> _fetchFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    debugPrint('Memulai pengecekan status favorit untuk user: ${user?.id}');
    if (user == null) return;

    try {
      final res = await Supabase.instance.client
          .from('favorit')
          .select()
          .eq('user_id', user.id)
          .eq('hotel_id', hotel['id']?.toString() ?? '')
          .maybeSingle();

      debugPrint('Hasil query favorit untuk hotel ${hotel['id']}: $res');
      if (mounted) {
        setState(() {
          _isFavorited = res != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorites: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk menyimpan favorit')),
      );
      return;
    }

    final hotelId = hotel['id']?.toString() ?? '';
    if (hotelId.isEmpty) return;

    final wasFavorited = _isFavorited;
    setState(() {
      _isFavorited = !wasFavorited;
    });

    final payload = {
      'user_id': user.id,
      'hotel_id': hotelId,
    };
    debugPrint('Mengirim payload favorit: $payload');

    try {
      if (wasFavorited) {
        await Supabase.instance.client
            .from('favorit')
            .delete()
            .eq('user_id', user.id)
            .eq('hotel_id', hotelId);
      } else {
        await Supabase.instance.client.from('favorit').insert(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorited ? 'Ditambahkan ke favorit' : 'Dihapus dari favorit',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating favorites: $e');
      if (mounted) {
        setState(() {
          _isFavorited = wasFavorited;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memperbarui favorit')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageHeader(context),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(),
                      const SizedBox(height: 16),
                      _buildRatingRow(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 32),
                      _buildGallerySection(),
                      const SizedBox(height: 32),
                      _buildFacilitiesSection(),
                      const SizedBox(height: 32),
                      _buildInformationSection(),
                      const SizedBox(height: 32),
                      _buildLocationSection(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildBottomBookingBar(context),
        ],
      ),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 350,
          width: double.infinity,
          child: Image.network(
            hotel['foto_utama_url'] ??
                hotel['image_url'] ??
                hotel['image'] ??
                '',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.black26,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: IconButton(
                        icon: Icon(
                          _isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorited ? Colors.red : Colors.white,
                        ),
                        onPressed: _toggleFavorite,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: Colors.black26,
                      child: IconButton(
                        icon: const Icon(
                          Icons.share_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          final harga =
                              (hotel['harga_termurah'] as num?)?.toInt() ?? 0;
                          final formattedPrice = harga > 0
                              ? harga.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]}.',
                                )
                              : '0';
                          final bintang = (hotel['bintang'] as num?)?.toInt() ?? 0;
                          final namaHotel =
                              hotel['nama']?.toString() ??
                              hotel['name']?.toString() ??
                              'Hotel';
                          final slug = hotel['slug']?.toString() ?? '';
                          final shareText =
                              'Cek penginapan keren ini di Delira!\n\n'
                              '🏢 $namaHotel\n'
                              '⭐ Bintang $bintang\n'
                              '💸 Mulai dari Rp $formattedPrice / malam\n\n'
                              'Lihat detail selengkapnya di sini:\n'
                              'https://delira.app/hotel/$slug\n\n'
                              'Ayo liburan ke Medan dan booking sekarang di aplikasi Delira!';
                          Share.share(shareText);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Text(
      hotel['nama'] ?? hotel['name'] ?? '',
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.2,
      ),
    );
  }

  Widget _buildRatingRow() {
    final bintang = (hotel['bintang'] as num?)?.toInt() ?? 0;
    return Row(
      children: List.generate(
        5,
        (index) => Icon(
          Icons.star,
          size: 24,
          color: index < bintang ? Colors.amber : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatBox(
          Icons.star,
          (hotel['rating'] as num?)?.toDouble().toString() ?? '5.0',
          'Rating',
          Colors.orange,
        ),
        _buildStatBox(
          Icons.location_on,
          LocationUtils.getDisplayDistance(hotel, _currentPosition),
          'Jarak',
          Colors.green,
        ),
        _buildStatBox(
          Icons.payments_outlined,
          _formatHarga(hotel['harga_termurah']),
          'Mulai dari',
          Colors.teal,
        ),
      ],
    );
  }

  String _formatHarga(dynamic val) {
    final n = (val as num?)?.toInt() ?? 0;
    if (n == 0) return 'Hubungi';
    return 'Rp ${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Widget _buildStatBox(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Galeri Foto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_galeriList.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Tidak ada foto galeri.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _galeriList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final fotoUrl =
                    _galeriList[index]['foto_url']?.toString() ?? '';
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fotoUrl,
                    width: 140,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 140,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFacilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fasilitas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFacilityChip(Icons.wifi, 'WiFi'),
            _buildFacilityChip(Icons.pool, 'Kolam Renang'),
            _buildFacilityChip(Icons.fitness_center, 'Gym'),
            _buildFacilityChip(Icons.restaurant, 'Sarapan'),
            _buildFacilityChip(Icons.directions_car, 'Parkir'),
          ],
        ),
      ],
    );
  }

  Widget _buildFacilityChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.location_on_outlined,
                'Alamat',
                hotel['alamat']?.toString() ?? 'Alamat tidak tersedia',
                onTap: _openNavigation,
                showAction: true,
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.access_time,
                'Check-in / Check-out',
                hotel['waktu_checkin_checkout']?.toString() ?? '14:00 / 12:00',
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.block,
                'Kebijakan',
                hotel['kebijakan']?.toString() ?? 'Sesuai kebijakan hotel',
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.payment,
                'Metode Pembayaran',
                'Bayar Online (Pakasir) & Bayar di Hotel',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle, {VoidCallback? onTap, bool showAction = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (showAction)
                        Row(
                          children: [
                            Text(
                              'Buka Peta',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.primary, size: 14),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lokasi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _openNavigation,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                // Grid Dummy Background
                CustomPaint(painter: _GridPainter(), size: Size.infinite),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.hotel,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      Container(width: 4, height: 16, color: AppColors.primary),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ketuk untuk buka peta',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBookingBar(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Price section (flexible, takes remaining space)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mulai dari',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatHarga(hotel['harga_termurah']),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B4A),
                          ),
                        ),
                        const TextSpan(
                          text: '/malam',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Pesan Sekarang button (fixed width)
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomSelectionPage(hotel: hotel),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6B4A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Pesan Sekarang',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withAlpha(100)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
