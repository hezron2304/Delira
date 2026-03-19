import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/detail_page.dart';
import 'package:delira/profil_page.dart';
import 'package:delira/hotel_page.dart';
import 'package:delira/map_page.dart';
import 'package:delira/notifikasi_page.dart';
import 'package:delira/ai_guide_page.dart';
import 'package:delira/theme/app_colors.dart';

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
  List<Map<String, dynamic>> _destinasiList = [];
  String _userName = 'Pengguna';
  String _userInitials = 'P';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchDestinasi();
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
    // Dummy Data for UI presentation
    if (mounted) {
      setState(() {
        _destinasiList = [
          {
            'kategori': 'Situs Sejarah',
            'badge': 'Religi',
            'filter': 'Religi',
            'nama': 'Masjid Raya Al-Mashun',
            'rating': 4.8,
            'jarak_km': 2.3,
            'is_featured': true,
            'image_url': 'https://images.unsplash.com/photo-1565552643983-6df3d12ebd83?auto=format&fit=crop&q=80',
            'icon': Icons.mosque,
          },
          {
            'kategori': 'Sejarah',
            'badge': 'Sejarah',
            'filter': 'Sejarah',
            'nama': 'Istana Maimun',
            'rating': 4.7,
            'jarak_km': 1.8,
            'is_featured': true,
            'image_url': 'https://images.unsplash.com/photo-1582539097950-7164998273f3?auto=format&fit=crop&q=80',
            'icon': Icons.account_balance,
          },
          {
            'kategori': 'Religi',
            'badge': 'Religi',
            'filter': 'Religi',
            'nama': 'Gereja Immanuel',
            'rating': 4.6,
            'jarak_km': 3.1,
            'is_featured': false,
            'image_url': '',
            'icon': Icons.church,
          },
          {
            'kategori': 'Kuliner',
            'badge': 'Kuliner',
            'filter': 'Kuliner',
            'nama': 'Soto Kesawan',
            'rating': 4.9,
            'jarak_km': 0.8,
            'is_featured': true,
            'image_url': 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&q=80',
            'icon': Icons.ramen_dining,
          },
          {
            'kategori': 'Situs Sejarah',
            'badge': 'Cagar Budaya',
            'filter': 'Sejarah',
            'nama': 'Mansion Tjong A Fie',
            'rating': 4.8,
            'jarak_km': 1.1,
            'is_featured': true,
            'image_url': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Tjong_A_Fie_Mansion_%286071477708%29.jpg/1200px-Tjong_A_Fie_Mansion_%286071477708%29.jpg',
            'icon': Icons.storefront,
          },
          {
            'kategori': 'Taman Rekreasi',
            'badge': 'Taman',
            'filter': 'Rekreasi',
            'nama': 'Taman Hutan Cemara',
            'rating': 4.5,
            'jarak_km': 6.3,
            'is_featured': true,
            'image_url': 'https://images.unsplash.com/photo-1444459092404-b6e15d2a9311?auto=format&fit=crop&q=80',
            'icon': Icons.park,
          },
        ];
        _isLoading = false;
      });
    }
  }


  List<Map<String, dynamic>> get _filteredDestinasi {
    if (_activeCategory == 'Semua') return _destinasiList;
    return _destinasiList.where((d) => d['filter'] == _activeCategory).toList();
  }

  List<Map<String, dynamic>> get _destinasiUnggulan {
    return _filteredDestinasi.where((d) => d['is_featured'] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: _currentIndex == 3
            ? const ProfilPage()
            : _currentIndex == 2
                ? const HotelPage()
                : _currentIndex == 4
                    ? const AIGuidePage()
                    : _currentIndex == 1
                    ? MapPage(onHotelRequested: () {
                        setState(() {
                          _currentIndex = 2; // Switch to Hotel tab
                        });
                      })
                    : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
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
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 14), // Mendorong FAB agak ke bawah
        child: SizedBox(
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24.0),
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    child: Text(_userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const NotifikasiPage()),
                      );
                    },
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari destinasi wisata...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: const Icon(Icons.tune, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(16),
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
          final String name = item['nama'] ?? 'Nav';
          final String badge = item['badge'] ?? 'Wisata';
          final num rating = item['rating'] ?? 0.0;
          final String dist = '${item['jarak_km'] ?? '0.0'} km';
          final String imageUrl = item['image_url'] ?? '';

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
    final items = _filteredDestinasi;
    
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
          final String name = item['nama'] ?? 'Nav';
          final String kategori = item['kategori'] ?? 'Wisata'; // Use literal category text naturally
          final num rating = item['rating'] ?? 0.0;
          final String dist = '${item['jarak_km'] ?? '0.0'} km';

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
                            item['icon'] ?? Icons.place,
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
      child: SizedBox(
        height: 70,
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
                  SizedBox(height: 6),
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
