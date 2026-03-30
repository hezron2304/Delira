import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAppBarCollapsed = false;
  bool _isDescriptionExpanded = false;
  List<Map<String, dynamic>> _ulasanList = [];
  bool _isLoadingUlasan = true;
  String? _ulasanError;
  final TextEditingController _ulasanController = TextEditingController();
  int _selectedRating = 5;
  bool _isSubmittingUlasan = false;

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
    _fetchUlasan();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final collapsed = offset > (350 - kToolbarHeight);
    if (collapsed != _isAppBarCollapsed) {
      if (mounted) {
        setState(() {
          _isAppBarCollapsed = collapsed;
        });
      }
    }
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationUtils.getCurrentPosition();
    if (mounted) {
      final deskripsi = hotel['deskripsi']?.toString() ?? '';
      debugPrint('LOG: Hotel Deskripsi Length: ${deskripsi.length}');
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

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
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
      debugPrint('DB_ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Koneksi database gagal. Gagal memuat status favorit.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
      }
      return;
    }

    final hotelId = hotel['id']?.toString() ?? '';
    if (hotelId.isEmpty) return;

    final wasFavorited = _isFavorited;
    setState(() {
      _isFavorited = !wasFavorited;
    });

    final payload = {'user_id': user.id, 'hotel_id': hotelId};
    debugPrint('Mengirim payload favorit: $payload');

    try {
      if (wasFavorited) {
        // Hapus dari favorit
        await Supabase.instance.client
            .from('favorit')
            .delete()
            .eq('user_id', user.id)
            .eq('hotel_id', hotelId);
      } else {
        // Tambah ke favorit
        await Supabase.instance.client.from('favorit').insert({
          'user_id': user.id,
          'hotel_id': hotelId,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorited ? 'Tersimpan ke Favorit' : 'Dihapus dari Favorit',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: _isFavorited ? Colors.green : Colors.redAccent,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      debugPrint('DB_ERROR: $e');
      if (mounted) {
        setState(() {
          _isFavorited = wasFavorited;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koneksi database gagal. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent, // Make it transparent
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildSliverAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
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
                        _buildDescriptionSection(),
                        const SizedBox(height: 32),
                        _buildGallerySection(),
                        const SizedBox(height: 32),
                        _buildFacilitiesSection(),
                        const SizedBox(height: 32),
                        _buildInformationSection(),
                        const SizedBox(height: 32),
                        _buildLocationSection(),
                        const SizedBox(height: 32),
                        _buildReviewsSection(),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomBookingBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    // Collect all images (main + gallery)
    final List<String> allImages = [];
    final mainImage =
        hotel['foto_utama_url'] ?? hotel['image_url'] ?? hotel['image'] ?? '';
    if (mainImage.isNotEmpty) allImages.add(mainImage);

    for (var item in _galeriList) {
      final url = item['foto_url']?.toString() ?? '';
      if (url.isNotEmpty && url != mainImage) {
        allImages.add(url);
      }
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 350,
      backgroundColor: _isAppBarCollapsed ? Colors.white : Colors.transparent,
      elevation: _isAppBarCollapsed ? 2 : 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: _isAppBarCollapsed
              ? Colors.transparent
              : Colors.black26,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: _isAppBarCollapsed ? AppColors.textPrimary : Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      title: AnimatedOpacity(
        opacity: _isAppBarCollapsed ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          hotel['nama'] ?? hotel['name'] ?? '',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: _isAppBarCollapsed
                ? Colors.transparent
                : Colors.black26,
            child: IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited
                    ? Colors.red
                    : (_isAppBarCollapsed
                          ? AppColors.textPrimary
                          : Colors.white),
                size: 20,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
          child: CircleAvatar(
            backgroundColor: _isAppBarCollapsed
                ? Colors.transparent
                : Colors.black26,
            child: IconButton(
              icon: Icon(
                Icons.share_outlined,
                color: _isAppBarCollapsed
                    ? AppColors.textPrimary
                    : Colors.white,
                size: 20,
              ),
              onPressed: () {
                final harga = (hotel['harga_termurah'] as num?)?.toInt() ?? 0;
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
        ),
      ],
      shape: _isAppBarCollapsed
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                if (mounted) {
                  setState(() {
                    _currentPage = page;
                  });
                }
              },
              itemCount: allImages.length,
              itemBuilder: (context, index) {
                final imageUrl = allImages[index];

                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                      'LOG: Image loading failed for URL: $imageUrl, Error: $error',
                    );
                    return Container(
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (allImages.length > 1)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: allImages.asMap().entries.map((entry) {
                    return Container(
                      width: _currentPage == entry.key ? 24.0 : 8.0,
                      height: 8.0,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white.withAlpha(
                          _currentPage == entry.key ? 255 : 120,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Menghapus _buildImageHeader lama

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

  Widget _buildDescriptionSection() {
    final String deskripsi = hotel['deskripsi']?.toString() ?? '';
    final bool hasDeskripsi = deskripsi.trim().isNotEmpty;
    final String deskripsiText = hasDeskripsi
        ? deskripsi
        : 'Informasi deskripsi belum tersedia untuk hotel ini.';

    // Tampilkan tombol hanya jika teks cukup panjang
    final bool isTextLong = deskripsi.length > 160;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Text(
            deskripsiText,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
            maxLines: _isDescriptionExpanded ? null : 4,
            overflow: _isDescriptionExpanded
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
        ),
        if (hasDeskripsi && isTextLong) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Text(
              _isDescriptionExpanded ? 'Tutup' : 'Baca selengkapnya',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
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
              separatorBuilder: (_, _) => const SizedBox(width: 12),
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

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
    bool showAction = false,
  }) {
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
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.primary,
                              size: 14,
                            ),
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

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ulasan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildAddReviewSection(),
        const SizedBox(height: 24),
        if (_isLoadingUlasan)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_ulasanError != null)
          Center(
            child: Column(
              children: [
                Text(_ulasanError!, style: const TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: _fetchUlasan,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          )
        else if (_ulasanList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada ulasan untuk penginapan ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ulasanList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildReviewCard(_ulasanList[index]),
          ),
      ],
    );
  }

  Widget _buildAddReviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Rating Kamu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = index + 1;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        index < _selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ulasanController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis ulasan kamu di sini...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingUlasan ? null : _submitUlasan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: _isSubmittingUlasan
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Kirim Ulasan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUlasan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan login terlebih dahulu untuk memberikan ulasan.',
          ),
        ),
      );
      return;
    }

    final comment = _ulasanController.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ulasan tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _isSubmittingUlasan = true);

    try {
      await Supabase.instance.client.from('ulasan').insert({
        'user_id': user.id,
        'hotel_id': hotel['id'],
        'rating': _selectedRating,
        'ulasan': comment,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _ulasanController.clear();
        setState(() {
          _selectedRating = 5;
          _isSubmittingUlasan = false;
        });
        _fetchUlasan(); // Refresh list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ulasan berhasil dikirim!')),
        );
      }
    } catch (e) {
      debugPrint('SUBMIT_HOTEL_ULASAN_ERROR: $e');
      if (mounted) {
        setState(() => _isSubmittingUlasan = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim ulasan: $e')));
      }
    }
  }

  Widget _buildReviewCard(Map<String, dynamic> ulasanData) {
    final profiles = ulasanData['profiles'] as Map<String, dynamic>?;
    final String name =
        profiles?['nama_lengkap']?.toString() ?? 'Pengguna Delira';
    final String comment = ulasanData['ulasan']?.toString() ?? '-';
    final int rating = (ulasanData['rating'] as num?)?.toInt() ?? 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        Icons.star,
                        color: i < rating
                            ? Colors.orange
                            : Colors.grey.shade300,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchUlasan() async {
    setState(() {
      _isLoadingUlasan = true;
      _ulasanError = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('ulasan')
          .select('*, profiles(nama_lengkap)')
          .eq('hotel_id', hotel['id']?.toString() ?? '')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _ulasanList = List<Map<String, dynamic>>.from(res);
          _isLoadingUlasan = false;
        });
      }
    } catch (e) {
      debugPrint('FETCH_HOTEL_ULASAN_ERROR: $e');
      if (mounted) {
        setState(() {
          _ulasanError = 'Gagal memuat ulasan.';
          _isLoadingUlasan = false;
        });
      }
    }
  }

  Widget _buildBottomBookingBar(BuildContext context) {
    // Check if bottom padding exists (3-button nav or gestures)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200), // Slightly translucent white
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16, 
                6, // Dikembalikan sedikit agar ada jarak nyaman (biar berjarak)
                16, 
                bottomPadding + 4, // Ruang aman bawah untuk navigasi sistem
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Pindah ke START agar benar-benar mepet atas
                children: [
                  // Price section (flexible, takes remaining space)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4), // Sedikit offset agar teks sejajar tengah tombol secara visual tanpa menambah tinggi bar
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mulai dari',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              height: 1.0, // Hilangkan leading tambahan
                            ),
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
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: Colors.grey,
                                    height: 1.0, 
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
          ),
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
