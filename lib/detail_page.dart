import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:delira/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/models/destinasi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:delira/hotel_page.dart';
import 'package:delira/map_page.dart';
import 'package:delira/ai_guide_page.dart';

class DetailPage extends StatefulWidget {
  final Destinasi destinasi;

  const DetailPage({super.key, required this.destinasi});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Destinasi get destinasi => widget.destinasi;
  Position? _currentPosition;
  List<String> _galleryImages = [];
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isAppBarCollapsed = false;
  bool _isFavorited = false;
  bool _isLoadingGallery = false;
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
    _recordVisit();
    _fetchLocation();
    _fetchGallery();
    _fetchFavoriteStatus();
    _fetchUlasan();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _recordVisit() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || destinasi.id == null) return;

      // Get accurate current position for validation
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Dist destinasi coordinates
      final double destLat = destinasi.latitude;
      final double destLng = destinasi.longitude;

      // Calculate distance in meters
      final double distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        destLat,
        destLng,
      );

      debugPrint(
        'DEBUG: Geofencing Check: distance = $distance meters (Threshold: 500m)',
      );

      // ONLY RECORD if within 500m radius
      if (distance <= 500) {
        await Supabase.instance.client.from('riwayat_kunjungan').insert({
          'user_id': user.id,
          'destinasi_id': destinasi.id!,
          'waktu_kunjungan': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kunjungan Anda di ${destinasi.nama} telah dicatat!',
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        // TOO FAR SnackBar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Anda sedang tidak di ${destinasi.nama}, kunjungan tidak akan masuk riwayat.',
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error recording visit (geofencing): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat kunjungan: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
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
      setState(() {
        _isAppBarCollapsed = collapsed;
      });
    }
  }

  Future<void> _fetchGallery() async {
    if (mounted) {
      setState(() {
        _isLoadingGallery = true;
      });
    }

    try {
      final res = await Supabase.instance.client
          .from('destinasi_galeri')
          .select('*')
          .eq('destinasi_id', destinasi.id ?? '')
          .order('urutan', ascending: true); // Sesuai schema: urutan integer

      if (mounted) {
        setState(() {
          _galleryImages = (res as List)
              .map((e) => e['foto_url']?.toString() ?? '')
              .where((url) => url.isNotEmpty)
              .toList();
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      debugPrint('DB_ERROR: $e');
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB_ERROR: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationUtils.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
    }
  }

  /// Menggabungkan foto utama (dari destinasi) dan foto-foto dari galeri.
  List<String> _getAllImages() {
    final List<String> allImages = [];
    const baseUrl =
        'https://pdhvqcbnsncxkfspasjq.supabase.co/storage/v1/object/public/destinasi/';

    // 1. Tambahkan foto utama sebagai gambar pertama di slider
    if (destinasi.fotoUtamaUrl != null && destinasi.fotoUtamaUrl!.isNotEmpty) {
      final mainImg = destinasi.fotoUtamaUrl!;
      allImages.add(mainImg.startsWith('http') ? mainImg : '$baseUrl$mainImg');
    }

    // 2. Tambahkan foto-foto dari tabel destinasi_galeri
    for (var img in _galleryImages) {
      final imageUrl = img.startsWith('http') ? img : '$baseUrl$img';
      // Hindari duplikasi jika foto utama ada di galeri juga
      if (!allImages.contains(imageUrl)) {
        allImages.add(imageUrl);
      }
    }

    return allImages;
  }

  Future<void> _fetchFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || destinasi.id == null) return;

    try {
      final res = await Supabase.instance.client
          .from('favorit')
          .select()
          .eq('user_id', user.id)
          .eq('destinasi_id', destinasi.id!)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorited = res != null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching favorite status: $e');
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

    if (destinasi.id == null) return;

    final wasFavorited = _isFavorited;
    setState(() {
      _isFavorited = !wasFavorited;
    });

    try {
      if (wasFavorited) {
        await Supabase.instance.client
            .from('favorit')
            .delete()
            .eq('user_id', user.id)
            .eq('destinasi_id', destinasi.id!);
      } else {
        await Supabase.instance.client.from('favorit').insert({
          'user_id': user.id,
          'destinasi_id': destinasi.id!,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorited ? 'Destinasi disimpan!' : 'Dihapus dari Favorit',
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
      debugPrint('Database Error Details: $e');
      if (mounted) {
        setState(() {
          _isFavorited = wasFavorited;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui favorit. Silakan coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareDestinasi() {
    final nama = destinasi.nama;
    final kategori = destinasi.kategori;
    final rating = destinasi.rating;
    final harga = destinasi.formattedPrice;

    final shareText =
        'Cek tempat wisata keren ini di Delira!\n\n'
        '🏞️ $nama\n'
        '🏷️ Kategori: $kategori\n'
        '⭐ Rating: $rating\n'
        '💸 Tiket: $harga\n\n'
        'Ayo liburan ke Medan dan jelajahi tempat-tempat seru lainnya di aplikasi Delira!';

    // ignore: deprecated_member_use
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.light, // Keep light for image header
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
                        const SizedBox(height: 24),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                        _buildDescriptionSection(),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                        _buildVisitInfoSection(),
                        const SizedBox(height: 24),
                        _buildGallerySection(),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                        _buildLocationSection(),
                        const SizedBox(height: 32),
                        _buildReviewsSection(),
                        const SizedBox(
                          height: 100,
                        ), // Ruang bawah agar tidak tertutup bar
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final List<String> allImages = _getAllImages();
    debugPrint('DEBUG: Header sliders with ${allImages.length} images');

    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
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
          destinasi.nama,
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
              onPressed: _shareDestinasi,
            ),
          ),
        ),
      ],
      shape: _isAppBarCollapsed
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(background: _buildHeaderContent()),
    );
  }

  Widget _buildHeaderContent() {
    final List<String> allImages = _getAllImages();

    if (allImages.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (int page) {
            setState(() {
              _currentPage = page;
            });
          },
          itemCount: allImages.length,
          itemBuilder: (context, index) {
            final imageUrl = allImages[index];

            return CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.broken_image,
                    size: 48,
                    color: Colors.grey,
                  ),
                );
              },
            );
          },
        ),
        // Indikator Titik (Dots)
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
    );
  }

  // Menghapus _buildImageHeader yang lama karena sudah dipindah ke _buildSliverAppBar

  Widget _buildTitleSection() {
    final bool isOpen = destinasi.isOpenNow();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          destinasi.nama,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destinasi.kategori,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '•',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                isOpen ? 'BUKA' : 'TUTUP',
                style: TextStyle(
                  color: isOpen ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatBox(
          Icons.star,
          destinasi.rating.toString(),
          'Rating',
          Colors.orange,
        ),
        _buildStatBox(
          Icons.location_on,
          LocationUtils.getDisplayDistance(destinasi.toMap(), _currentPosition),
          'Jarak',
          Colors.green,
        ),
        _buildStatBox(
          Icons.history,
          destinasi.tahun ?? '-',
          'Tahun',
          Colors.grey,
        ),
      ],
    );
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final bool hasDeskripsi = destinasi.deskripsi.trim().isNotEmpty;
    final String deskripsiText = hasDeskripsi
        ? destinasi.deskripsi
        : 'Informasi deskripsi belum tersedia untuk ${destinasi.nama}.';

    // Tampilkan tombol hanya jika teks cukup panjang (estimasi > 160 karakter untuk 4 baris)
    final bool isTextLong = destinasi.deskripsi.length > 160;

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

  Widget _buildVisitInfoSection() {
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.access_time,
                'Jam Operasional',
                'Setiap Hari: ${destinasi.jamBuka} - ${destinasi.jamTutup}',
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.payments_outlined,
                'Tiket Masuk',
                destinasi.formattedPrice,
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.checkroom,
                'Dress Code',
                'Berpakaian sopan dan menutup aurat',
              ),
              const Divider(height: 32),
              _buildInfoRow(
                Icons.location_on_outlined,
                'Alamat',
                'Jl. Sisingamangaraja, Medan Kota, Medan',
                showAction: true,
                onTap: _launchNavigation,
              ),
              const Divider(height: 32),
              _buildInfoRow(Icons.phone_outlined, 'Kontak', '+62 61 4514441'),
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
    bool showAction = false,
    VoidCallback? onTap,
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

  Widget _buildGallerySection() {
    const baseUrl =
        'https://pdhvqcbnsncxkfspasjq.supabase.co/storage/v1/object/public/destinasi/';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Galeri Foto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_isLoadingGallery)
          const Center(child: CircularProgressIndicator())
        else if (_galleryImages.isEmpty)
          const Text(
            'Tidak ada foto galeri.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _galleryImages.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final img = _galleryImages[index];
                final imageUrl = img.startsWith('http') ? img : '$baseUrl$img';

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 140, // Mengikuti desain hotel_detail_page
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 140,
                      color: Colors.grey.shade200,
                    ),
                    errorWidget: (context, url, error) => Container(
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

  Future<void> _fetchUlasan() async {
    setState(() {
      _isLoadingUlasan = true;
      _ulasanError = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('ulasan')
          .select('*, profiles(nama_lengkap)')
          .eq('destinasi_id', destinasi.id ?? '')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _ulasanList = List<Map<String, dynamic>>.from(res);
          _isLoadingUlasan = false;
        });
      }
    } catch (e) {
      debugPrint('FETCH_ULASAN_ERROR: $e');
      if (mounted) {
        setState(() {
          _ulasanError = 'Gagal memuat ulasan.';
          _isLoadingUlasan = false;
        });
      }
    }
  }

  Future<void> _launchNavigation() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          initialLocation: LatLng(destinasi.latitude, destinasi.longitude),
          initialName: destinasi.nama,
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
          onTap: _launchNavigation,
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
                          Icons.location_on,
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
                    'Belum ada ulasan untuk tempat ini.',
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
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
        'destinasi_id': destinasi.id,
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
      debugPrint('SUBMIT_ULASAN_ERROR: $e');
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

  Widget _buildBottomActionBar(BuildContext context) {
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
              border: Border(
                top: BorderSide(color: Colors.black.withAlpha(20)),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6, // Jarak nyaman sesuai preferensi di hotel detail
                16,
                bottomPadding + 4, // Ruang aman bawah untuk navigasi sistem
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Guide Button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AIGuidePage(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.smart_toy_outlined,
                          size: 16,
                          color: Color(0xFF1A6B4A),
                        ),
                        label: const Text(
                          'AI Guide',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A6B4A),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A6B4A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Hotel Button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (destinasi.latitude != 0 &&
                              destinasi.longitude != 0) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HotelPage(
                                  destLat: destinasi.latitude,
                                  destLng: destinasi.longitude,
                                  destName: destinasi.nama,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lokasi Destinasi tidak valid'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.hotel_outlined,
                          size: 16,
                          color: Color(0xFF1A6B4A),
                        ),
                        label: const Text(
                          'Hotel Dekat',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A6B4A),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A6B4A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Navigasi Button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _launchNavigation,
                        icon: const Icon(
                          Icons.explore,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Navigasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          elevation: 0,
                        ),
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
      ..color = AppColors.border.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;

    const double step = 30.0;

    for (double i = step; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = step; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
