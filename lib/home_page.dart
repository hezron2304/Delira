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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:delira/notifikasi_page.dart';

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
  String? _avatarUrl;
  Position? _currentPosition;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchDestinasi();
    _fetchLocation().then((_) => _checkAutoArrival());
    _fetchUnreadCount();
  }

  Future<void> _checkAutoArrival() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || _currentPosition == null) return;

      // 1. Ambil semua destinasi & hotel (untuk pemindaian)
      // _destinasiList sudah diisi oleh _fetchDestinasi
      
      // Ambil hotel juga (karena di HomePage belum tentu semua hotel di-load)
      final hotelRes = await Supabase.instance.client.from('hotel').select('id, nama, latitude, longitude');
      final List hotels = hotelRes as List;

      final now = DateTime.now();
      final threshold = now.subtract(const Duration(hours: 24)).toIso8601String();

      // --- CEK DESTINASI ---
      for (var dest in _destinasiList) {
        final double dist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          dest.latitude,
          dest.longitude,
        );

        if (dist <= 500) {
          // Cek apakah sudah check-in di tempat ini dalam 24 jam terakhir
          final existing = await Supabase.instance.client
              .from('riwayat_kunjungan')
              .select('id')
              .eq('user_id', user.id)
              .eq('destinasi_id', dest.id!)
              .gt('waktu_kunjungan', threshold)
              .maybeSingle();

          if (existing == null) {
            // Auto Check-in!
            await Supabase.instance.client.from('riwayat_kunjungan').insert({
              'user_id': user.id,
              'destinasi_id': dest.id!,
              'waktu_kunjungan': now.toIso8601String(),
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anda terdeteksi di ${dest.nama}! Kunjungan otomatis dicatat. 📍'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return; // Berhenti setelah menemukan satu (opsional, agar tidak spam banyak tempat sekaligus)
          }
        }
      }

      // --- CEK HOTEL ---
      for (var h in hotels) {
        final double hLat = (h['latitude'] is String) ? double.tryParse(h['latitude']) ?? 0 : (h['latitude'] as num?)?.toDouble() ?? 0;
        final double hLng = (h['longitude'] is String) ? double.tryParse(h['longitude']) ?? 0 : (h['longitude'] as num?)?.toDouble() ?? 0;
        
        final double dist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          hLat,
          hLng,
        );

        if (dist <= 500) {
          final existing = await Supabase.instance.client
              .from('riwayat_kunjungan')
              .select('id')
              .eq('user_id', user.id)
              .eq('hotel_id', h['id'])
              .gt('waktu_kunjungan', threshold)
              .maybeSingle();

          if (existing == null) {
            await Supabase.instance.client.from('riwayat_kunjungan').insert({
              'user_id': user.id,
              'hotel_id': h['id'],
              'waktu_kunjungan': now.toIso8601String(),
            });

            if (mounted) {
              final String name = h['nama'] ?? 'Hotel';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Anda terdeteksi di $name! Kunjungan otomatis dicatat. 🏨'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('AUTO_CHECKIN_ERROR: $e');
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
            _avatarUrl = res['foto_url'];
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

  Future<void> _fetchUnreadCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Ambil semua ID notifikasi yang relevan (global + personal)
      final allNotifsRes = await Supabase.instance.client
          .from('notifikasi')
          .select('id')
          .or('user_id.is.null,user_id.eq.${user.id}');
      
      final List allNotifIds = (allNotifsRes as List).map((n) => n['id'].toString()).toList();

      // 2. Ambil ID yang sudah dibaca oleh user ini
      final readRes = await Supabase.instance.client
          .from('notifikasi_dibaca')
          .select('notifikasi_id')
          .eq('user_id', user.id);
      
      final List readIds = (readRes as List).map((n) => n['notifikasi_id'].toString()).toList();

      // 3. Hitung yang belum ada di daftar baca
      int unread = 0;
      for (var id in allNotifIds) {
        if (!readIds.contains(id)) unread++;
      }

      if (mounted) {
        setState(() {
          _unreadCount = unread;
        });
      }
    } catch (e) {
      debugPrint('FETCH_UNREAD_COUNT_ERROR: $e');
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

  Color get _navColor {
    if (_currentIndex == 1) return Colors.transparent; // Map
    if (_currentIndex == 2 || _currentIndex == 4) return Colors.white; // Hotel, AI Guide
    return AppColors.surface; // Home, Profile
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, 
        systemNavigationBarColor: _navColor, // Match active tab background
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
                      : CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(child: _buildHeader(context)),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(child: _buildCategoryChips()),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(child: _buildSectionTitle('Destinasi Unggulan')),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),
                            SliverToBoxAdapter(
                                child: _isLoading
                                    ? _buildShimmerHorizontal()
                                    : _buildDestinasiUnggulanList()),
                            const SliverToBoxAdapter(child: SizedBox(height: 24)),
                            SliverToBoxAdapter(child: _buildSectionTitle('Terdekat dari Kamu')),
                            const SliverToBoxAdapter(child: SizedBox(height: 16)),
                            _isLoading
                                ? SliverToBoxAdapter(child: _buildShimmerVertical())
                                : _buildTerdekatSliverList(),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = 3; // Navigate to Profil tab
                  });
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        image: _avatarUrl != null 
                            ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover) 
                            : null,
                      ),
                      child: _avatarUrl == null 
                        ? Center(
                            child: Text(
                              _userInitials, 
                              style: const TextStyle(
                                color: AppColors.primary, 
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : null,
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
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotifikasiPage()),
                  );
                  // Refresh badge count when returning
                  _fetchUnreadCount();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
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
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl), 
                            fit: BoxFit.cover
                          ) 
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

  Widget _buildTerdekatSliverList() {
    final items = List<Destinasi>.from(_filteredDestinasi);

    if (_currentPosition != null) {
      try {
        items.sort((a, b) {
          final distA = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              a.latitude,
              a.longitude);
          final distB = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              b.latitude,
              b.longitude);
          return distA.compareTo(distB);
        });
      } catch (e) {
        debugPrint('Error sorting Destinasi by distance: $e');
      }
    }

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Text('Tidak ada destinasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final String name = item.nama;
            final String kategori = item.kategori;
            final double rating = item.rating;
            final String dist = LocationUtils.getDisplayDistance(
                item.toMap(), _currentPosition);

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
                      MaterialPageRoute(
                          builder: (_) => DetailPage(destinasi: item)),
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
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.grey, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    kategori,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('•',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(rating.toString(),
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12)),
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
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: _navColor, // Match active tab background
      padding: EdgeInsets.zero,
      elevation: 0, // No border line
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
