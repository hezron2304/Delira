import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/detail_page.dart';
import 'package:delira/profil_page.dart';
import 'package:delira/hotel_page.dart';
import 'package:delira/map_page.dart';
import 'package:delira/ai_guide_page.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/models/destinasi.dart';
import 'package:delira/search_page.dart';
import 'package:shimmer/shimmer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String _activeCategory = 'Semua';
  final List<String> _categories = ['Semua', 'Sejarah', 'Religi', 'Kuliner'];

  bool _isLoading = true;
  List<Destinasi> _destinasiList = [];
  String _userName = 'Pengguna';
  String _userInitials = 'P';
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchDestinasi();
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

  Future<void> _fetchUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final res = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _userName = res['nama_lengkap'] ?? 'Pengguna';
            if (_userName.isNotEmpty) {
              final parts = _userName.split(' ');
              if (parts.length > 1) {
                _userInitials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              } else {
                _userInitials = parts[0][0].toUpperCase();
              }
            }
          });
        }
      }
    } catch (_) {
      // safe fallback
    }
  }

  Future<void> _fetchDestinasi() async {
    try {
      final res = await Supabase.instance.client.from('destinasi').select();
      if (mounted) {
        setState(() {
          _destinasiList = (res as List).map((d) => Destinasi.fromMap(d)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  List<Destinasi> get _filteredDestinasi {
    if (_activeCategory == 'Semua') return _destinasiList;
    return _destinasiList.where((d) => d.kategori == _activeCategory).toList();
  }

  List<Destinasi> get _destinasiUnggulan {
    return _filteredDestinasi.where((d) => d.isFeatured == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Menjadikan ikon indikator putih untuk tab Beranda (Hijau) dan gelap untuk tab lainnya (Putih)
    final bool isDarkBackground = _currentIndex == 0 || _currentIndex == 4;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkBackground ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: _currentIndex == 4,
        backgroundColor: AppColors.surface,
        body: SafeArea(
          top: false,
          bottom: false,
          child: _currentIndex == 3
              ? const ProfilPage()
              : _currentIndex == 2
                  ? const HotelPage()
                  : _currentIndex == 4
                      ? AIGuidePage(onBackPressed: () => setState(() => _currentIndex = 0))
                      : _currentIndex == 1
                          ? MapPage(onHotelRequested: () {
                              setState(() {
                                _currentIndex = 2;
                              });
                            })
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeader(context),
                                  const SizedBox(height: 24),
                                  _buildCategoryChips(),
                                  const SizedBox(height: 24),
                                  _buildSectionTitle('Destinasi Unggulan'),
                                  const SizedBox(height: 16),
                                  _isLoading ? _buildShimmerHorizontal() : _buildDestinasiUnggulanList(),
                                  const SizedBox(height: 24),
                                  _buildSectionTitle('Terdekat dari Kamu'),
                                  const SizedBox(height: 16),
                                  _isLoading ? _buildShimmerVertical() : _buildTerdekatList(),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
        ),
        bottomNavigationBar: _currentIndex == 4 ? const SizedBox.shrink() : _buildBottomNav(),
        floatingActionButton: _currentIndex == 4
            ? null
            : SizedBox(
                width: 66,
                height: 66,
                child: FittedBox(
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 4;
                      });
                    },
                    backgroundColor: _currentIndex == 4 ? AppColors.primaryDark : AppColors.primary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    heroTag: 'aiGuideMainBtn',
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 32),
                  ),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Mengambil tinggi poni layar (Notch / Status Bar) agar teks tidak tertutup
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16.0,
        left: 24.0,
        right: 24.0,
        bottom: 20.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _userInitials, 
                    style: const TextStyle(
                      color: AppColors.primary, 
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat datang 👋', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                  Text(_userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              readOnly: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                );
              },
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Cari destinasi wisata...',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                border: InputBorder.none,
                contentPadding: EdgeInsets.only(top: 14, bottom: 14, right: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isActive = category == _activeCategory;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCategory = category;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.transparent : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildShimmerHorizontal() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerVertical() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 104,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 60, height: 16, color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Container(width: 120, height: 16, color: Colors.grey.shade300),
                    ],
                  ),
                ),
              )
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildDestinasiUnggulanList() {
    final items = _destinasiUnggulan;
    
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Text('Tidak ada destinasi unggulan untuk kategori ini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final String name = item.nama;
          final String badge = item.kategori;
          final double rating = item.rating;
          final String dist = LocationUtils.getDisplayDistance(item.toMap(), _currentPosition);
          final String imageUrl = item.fullImageUrl;

          return SizedBox(
            width: 280,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    image: imageUrl.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) 
                        : null,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(180),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withAlpha(200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                rating.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              const Text('•', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 6),
                              Text(
                                dist,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DetailPage(destinasi: item)),
                        );
                        if (result == 'GO_TO_HOTEL' && mounted) {
                          setState(() {
                            _currentIndex = 2; // Index for Hotel tab
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTerdekatList() {
    final items = List<Destinasi>.from(_filteredDestinasi);

    if (_currentPosition != null) {
      try {
        items.sort((a, b) {
          final distA = Geolocator.distanceBetween(
            _currentPosition!.latitude, 
            _currentPosition!.longitude, 
            a.latitude, 
            a.longitude
          );
          final distB = Geolocator.distanceBetween(
            _currentPosition!.latitude, 
            _currentPosition!.longitude, 
            b.latitude, 
            b.longitude
          );
          return distA.compareTo(distB);
        });
      } catch (e) {
        debugPrint('Error sorting Destinasi by distance: $e');
      }
    }
    
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Text('Tidak ada destinasi.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: items.map((item) {
          final String name = item.nama;
          final String kategori = item.kategori;
          final double rating = item.rating;
          final String dist = LocationUtils.getDisplayDistance(item.toMap(), _currentPosition);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailPage(destinasi: item)),
                  );
                  if (result == 'GO_TO_HOTEL' && mounted) {
                    setState(() {
                      _currentIndex = 2; // Index for Hotel tab
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            item.iconData,
                            color: AppColors.primaryDark,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Text(
                                      dist,
                                      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  kategori,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                const SizedBox(width: 8),
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(rating.toString(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.white,
      padding: EdgeInsets.zero,
      elevation: 20,
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.home, 'Beranda', 0),
                    _buildNavItem(Icons.map_outlined, 'Peta', 1),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text(
                      'AI Guide',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.hotel_outlined, 'Hotel', 2),
                    _buildNavItem(Icons.person_outline, 'Profil', 3),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? AppColors.primary : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : Colors.grey,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
