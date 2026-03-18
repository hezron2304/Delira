import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/profil_page.dart';

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
    try {
      final res = await Supabase.instance.client
          .from('destinasi')
          .select()
          .eq('is_active', true);
      
      if (mounted) {
        setState(() {
          _destinasiList = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching destinasi: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDestinasi {
    if (_activeCategory == 'Semua') return _destinasiList;
    return _destinasiList.where((d) => d['kategori'] == _activeCategory).toList();
  }

  List<Map<String, dynamic>> get _destinasiUnggulan {
    return _filteredDestinasi.where((d) => d['is_featured'] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2D7A4F);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: _currentIndex == 3
            ? const ProfilPage()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(primaryGreen),
                    const SizedBox(height: 24),
                    _buildCategoryChips(primaryGreen),
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
      bottomNavigationBar: _buildBottomNav(primaryGreen),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: primaryGreen,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.explore, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader(Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
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
                children: [
                  const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
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

  Widget _buildCategoryChips(Color primaryGreen) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _x) => const SizedBox(width: 12),
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
                color: isActive ? primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.transparent : primaryGreen,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isActive ? Colors.white : primaryGreen,
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
          color: Colors.black87,
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
        separatorBuilder: (_, _x) => const SizedBox(width: 16),
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
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _x) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final String name = item['nama'] ?? 'Nav';
          final String badge = item['kategori'] ?? 'Wisata';
          final num rating = item['rating'] ?? 0.0;
          final String dist = '${item['jarak_km'] ?? '0.0'} km';
          final String imageUrl = item['image_url'] ?? '';

          return Container(
            width: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(16),
              image: imageUrl.isNotEmpty 
                  ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) 
                  : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade800.withAlpha(200),
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
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⭐ $rating • $dist',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ],
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
          final String badge = item['kategori'] ?? 'Wisata';
          final num rating = item['rating'] ?? 0.0;
          final String dist = '${item['jarak_km'] ?? '0.0'} km';
          final String imageUrl = item['image_url'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrl.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) 
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.bookmark_border, color: Colors.grey, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '⭐ $rating • $dist',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomNav(Color primaryGreen) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'Beranda', 0, primaryGreen),
          _buildNavItem(Icons.map_outlined, 'Peta', 1, primaryGreen),
          const SizedBox(width: 48), // Space for FAB
          _buildNavItem(Icons.hotel_outlined, 'Hotel', 2, primaryGreen),
          _buildNavItem(Icons.person_outline, 'Profil', 3, primaryGreen),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, Color primaryGreen) {
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
          Icon(icon, color: isActive ? primaryGreen : Colors.grey, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? primaryGreen : Colors.grey,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
