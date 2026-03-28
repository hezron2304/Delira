import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/models/destinasi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:delira/hotel_page.dart';

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
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;
  bool _isAppBarCollapsed = false;
  bool _isFavorited = false;
  bool _isLoadingGallery = false;
  String? _galleryError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _fetchGallery();
    _fetchFavoriteStatus();
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
      setState(() {
        _isAppBarCollapsed = collapsed;
      });
    }
  }

  Future<void> _fetchGallery() async {
    if (mounted) {
      setState(() {
        _isLoadingGallery = true;
        _galleryError = null;
      });
    }

    try {
      final res = await Supabase.instance.client
          .from('destinasi_galeri')
          .select('*')
          .eq('destinasi_id', destinasi.id ?? '');
      
      if (mounted) {
        setState(() {
          _galleryImages = (res as List).map((e) => e['foto_url']?.toString() ?? '').toList();
          _isLoadingGallery = false;
          
          if (_galleryImages.isEmpty) {
            print('LOG: Gallery is empty for ID: ${destinasi.id}');
            print('LOG: Main fotoUtamaUrl fallback = ${destinasi.fotoUtamaUrl}');
          }
        });
      }
    } catch (e) {
      print('DB_ERROR: $e');
      if (mounted) {
        setState(() {
          _galleryError = e.toString();
          _isLoadingGallery = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DB_ERROR: $e'),
            backgroundColor: Colors.red,
          ),
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
      print('Database Error Details: $e');
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
    
    final shareText = 'Cek tempat wisata keren ini di Delira!\n\n'
        '🏞️ $nama\n'
        '🏷️ Kategori: $kategori\n'
        '⭐ Rating: $rating\n'
        '💸 Tiket: $harga\n\n'
        'Ayo liburan ke Medan dan jelajahi tempat-tempat seru lainnya di aplikasi Delira!';
    
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
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
                  _buildReviewsSection(),
                  const SizedBox(height: 120), // Bottom bar space
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomActionBar(context),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    // PREPEND BASE URL MANUALLY FOR DEBUGGING
    const baseUrl = 'https://pdhvqcbnsncxkfspasjq.supabase.co/storage/v1/object/public/destinasi/';
    
    final List<String> allImages = [];
    
    // Add gallery images first
    for (var img in _galleryImages) {
      if (img.isNotEmpty) {
        if (img.startsWith('http')) {
          allImages.add(img);
        } else {
          allImages.add('$baseUrl$img');
        }
      }
    }
    
    // Fallback to main image if gallery is empty
    if (allImages.isEmpty) {
      if (destinasi.fotoUtamaUrl != null && destinasi.fotoUtamaUrl!.isNotEmpty) {
        final mainImg = destinasi.fotoUtamaUrl!;
        if (mainImg.startsWith('http')) {
          allImages.add(mainImg);
        } else {
          allImages.add('$baseUrl$mainImg');
        }
      }
    }

    print('DEBUG_URL: ${destinasi.fotoUtamaUrl}');
    print('DEBUG: Final allImages List = $allImages');

    return SliverAppBar(
      pinned: true,
      expandedHeight: 260,
      backgroundColor: _isAppBarCollapsed ? Colors.white : Colors.transparent,
      elevation: _isAppBarCollapsed ? 2 : 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: _isAppBarCollapsed ? Colors.transparent : Colors.black26,
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
            backgroundColor: _isAppBarCollapsed ? Colors.transparent : Colors.black26,
            child: IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border, 
                color: _isFavorited 
                    ? Colors.red 
                    : (_isAppBarCollapsed ? AppColors.textPrimary : Colors.white),
                size: 20,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, right: 16),
          child: CircleAvatar(
            backgroundColor: _isAppBarCollapsed ? Colors.transparent : Colors.black26,
            child: IconButton(
              icon: Icon(
                Icons.share_outlined, 
                color: _isAppBarCollapsed ? AppColors.textPrimary : Colors.white,
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
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeaderContent(),
      ),
    );
  }

  Widget _buildHeaderContent() {
    // PREPEND BASE URL MANUALLY FOR DEBUGGING
    const baseUrl = 'https://pdhvqcbnsncxkfspasjq.supabase.co/storage/v1/object/public/destinasi/';
    
    final List<String> allImages = [];
    
    // Add gallery images first
    for (var img in _galleryImages) {
      if (img.isNotEmpty) {
        if (img.startsWith('http')) {
          allImages.add(img);
        } else {
          allImages.add('$baseUrl$img');
        }
      }
    }
    
    // Fallback to main image if gallery is empty
    if (allImages.isEmpty) {
      if (destinasi.fotoUtamaUrl != null && destinasi.fotoUtamaUrl!.isNotEmpty) {
        final mainImg = destinasi.fotoUtamaUrl!;
        if (mainImg.startsWith('http')) {
          allImages.add(mainImg);
        } else {
          allImages.add('$baseUrl$mainImg');
        }
      }
    }

    if (_isLoadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_galleryError != null || (allImages.isEmpty)) {
      final bool mainImgMissing = destinasi.fotoUtamaUrl == null || destinasi.fotoUtamaUrl!.isEmpty;
      final errorMsg = _galleryError ?? (mainImgMissing ? 'Foto Utama juga tidak valid' : 'Galeri Kosong');
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'ERROR: $errorMsg',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchGallery,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
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
            
            return Image.network(
              imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('LOG: Render Error for URL: $imageUrl, Error: $error');
                return Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Render Error: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 10),
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
                    color: Colors.white.withAlpha(_currentPage == entry.key ? 255 : 120),
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
              const Text('•', style: TextStyle(color: AppColors.primary, fontSize: 12)),
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
          Icons.payments_outlined,
          destinasi.formattedPrice,
          'Tiket',
          Colors.teal,
        ),
        _buildStatBox(
          Icons.history,
          '1906',
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
      width: 78,
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '${destinasi.nama} adalah tempat bersejarah yang sangat indah dan ikonik di Kota Medan. Merupakan perpaduan arsitektur yang megah dan memiliki nilai budaya tinggi.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 8),
        const Text(
          'Baca selengkapnya',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Info Kunjungan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          Icons.access_time,
          'Jam Operasional',
          'Setiap Hari: ${destinasi.jamBuka} - ${destinasi.jamTutup}',
        ),
        _buildInfoRow(Icons.attach_money, 'Tiket Masuk', destinasi.formattedPrice),
        _buildInfoRow(
          Icons.checkroom,
          'Dress Code',
          'Berpakaian sopan dan menutup aurat',
        ),
        _buildInfoRow(
          Icons.location_on_outlined,
          'Alamat',
          'Jl. Sisingamangaraja, Medan Kota, Medan',
        ),
        _buildInfoRow(Icons.phone_outlined, 'Kontak', '+62 61 4514441'),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    final List<String> allImages = _galleryImages.isNotEmpty 
        ? _galleryImages.map((img) {
            if (img.startsWith('http')) return img;
            const baseUrl = 'https://pdhvqcbnsncxkfspasjq.supabase.co';
            return '$baseUrl/storage/v1/object/public/destinasi/$img';
          }).toList()
        : [destinasi.fullImageUrl];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Galeri Foto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: allImages.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(
                      allImages[index],
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _launchNavigation() async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${destinasi.latitude},${destinasi.longitude}'
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka peta')),
        );
      }
    }
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
        _buildReviewCard('Ahmad Rizki'),
        const SizedBox(height: 12),
        _buildReviewCard('Siti Aminah'),
      ],
    );
  }

  Widget _buildReviewCard(String name) {
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
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 12),
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
                      (i) => const Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tempat yang sangat indah dan bersejarah. Arsitekturnya luar biasa!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
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
        children: [
          // AI Guide Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {},
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
                  if (destinasi.latitude != 0 && destinasi.longitude != 0) {
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
                icon: const Icon(Icons.explore, size: 16, color: Colors.white),
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
    );
  }
}
