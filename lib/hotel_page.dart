import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/widgets/hotel_card.dart';
import 'package:delira/search_page.dart';

class HotelPage extends StatefulWidget {
  final double? destLat;
  final double? destLng;
  final String? destName;

  const HotelPage({
    super.key,
    this.destLat,
    this.destLng,
    this.destName,
  });

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  final List<String> _categories = ['Semua', 'Bintang 3+', 'Budget', 'Terdekat'];
  String _activeCategory = 'Semua';

  // Track which card is selected (-1 = none)
  int _selectedCardIndex = -1;

  List<Map<String, dynamic>> _hotels = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  final int _pageSize = 5;

  final ScrollController _scrollController = ScrollController();
  String? _errorMessage;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
    _fetchLocation();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        !_isLoading) {
      _fetchHotels(isLoadMore: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    final pos = await LocationUtils.getCurrentPosition();
    if (mounted) {
      setState(() {
        _currentPosition = pos;
      });
    }
  }

  Future<void> _fetchHotels({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _page = 0;
        _hasMore = true;
        _hotels = [];
      });
    }

    try {
      final from = _page * _pageSize;
      final to = from + _pageSize - 1;

      var query = Supabase.instance.client
          .from('hotel')
          .select('*, hotel_galeri(*), kamar(*)');

      // Apply Filter based on Category
      if (_activeCategory == 'Bintang 3+') {
        query = query.gte('rating', 3);
      }

      var orderedQuery = query.range(from, to);
      
      if (_activeCategory == 'Budget') {
        orderedQuery = orderedQuery.order('harga_termurah', ascending: true);
      } else {
        orderedQuery = orderedQuery.order('created_at', ascending: false);
      }

      final res = await orderedQuery;

      List<Map<String, dynamic>> newData =
          List<Map<String, dynamic>>.from(res);

      bool showNearbySnackBar = false;

      // Logic for Smart Filter (Destination Proximity)
      if (widget.destLat != null && widget.destLng != null) {
        bool anyWithin10km = false;
        
        for (var hotel in newData) {
          final double? hLat = (hotel['latitude'] as num?)?.toDouble();
          final double? hLng = (hotel['longitude'] as num?)?.toDouble();
          
          if (hLat != null && hLng != null) {
            double distance = Geolocator.distanceBetween(
              widget.destLat!,
              widget.destLng!,
              hLat,
              hLng,
            );
            hotel['dist_from_dest'] = distance;
            if (distance <= 10000) anyWithin10km = true;
          } else {
            hotel['dist_from_dest'] = double.infinity;
          }
        }

        // Sort by distance from destination
        newData.sort((a, b) => (a['dist_from_dest'] as double).compareTo(b['dist_from_dest'] as double));

        if (!anyWithin10km && _page == 0) {
          showNearbySnackBar = true;
        }
      }

      if (mounted) {
        setState(() {
          _hotels.addAll(newData);

          if (_activeCategory == 'Terdekat' && _currentPosition != null) {
            try {
              for (var hotel in _hotels) {
                final double? hLat = (hotel['latitude'] as num?)?.toDouble();
                final double? hLng = (hotel['longitude'] as num?)?.toDouble();
                
                if (hLat != null && hLng != null) {
                  hotel['dist_from_user'] = Geolocator.distanceBetween(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    hLat,
                    hLng,
                  );
                } else {
                  hotel['dist_from_user'] = double.infinity;
                }
              }
              _hotels.sort((a, b) => (a['dist_from_user'] as double).compareTo(b['dist_from_user'] as double));
            } catch (e) {
              debugPrint('Error mengurutkan Terdekat di HotelPage: $e');
            }
          }

          _isLoading = false;
          _isLoadingMore = false;
          _page++;
          _hasMore = newData.length == _pageSize;
          _errorMessage = null;
        });

        if (showNearbySnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada hotel yang sangat dekat, menampilkan hotel lainnya di Medan'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('FETCH ERROR: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  void _onCardTap(int index) {
    setState(() {
      // Toggle: if already selected, deselect; otherwise, select this card
      _selectedCardIndex = (_selectedCardIndex == index) ? -1 : index;
    });
  }

  void _onTapOutside() {
    if (_selectedCardIndex != -1) {
      setState(() {
        _selectedCardIndex = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: _onTapOutside, // Tap outside cards resets selection
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Hotel & Penginapan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sekitar Medan Kota',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Search Bar
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
                    hintText: 'Cari hotel...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 22),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.only(top: 14, bottom: 14, right: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
  
              // Chips
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isActive = category == _activeCategory;
                    return GestureDetector(
                      onTap: () {
                        if (_activeCategory != category) {
                          setState(() {
                            _activeCategory = category;
                          });
                          _fetchHotels();
                        }
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
              ),
              const SizedBox(height: 24),
  
              // Grid
              if (_isLoading)
                _buildSkeletonLoader()
              else if (_errorMessage != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Error: $_errorMessage',
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchHotels,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_hotels.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    child: Column(
                      children: [
                        const Icon(Icons.hotel_class_outlined, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        const Text(
                          'Waduh, belum ada hotel yang cocok nih.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Coba ganti filter/kategori atau cek lagi nanti ya.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.48, // Reduced to make cards taller and fix overflow
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _hotels.length,
                itemBuilder: (context, index) {
                  final hotel = _hotels[index];
                  final isSelected = _selectedCardIndex == index;
                  
                  final rawPrice = (hotel['harga_termurah'] as num?)?.toInt() ?? 0;
                  
                  // Calculate display distance for subtitle
                  String? destDistance;
                  if (widget.destLat != null && widget.destLng != null && hotel['dist_from_dest'] != null) {
                    final double d = hotel['dist_from_dest'] as double;
                    if (d < 1000) {
                      destDistance = '${d.toStringAsFixed(0)} m';
                    } else {
                      destDistance = '${(d / 1000).toStringAsFixed(1)} km';
                    }
                  }
  
                  return HotelCard(
                    name: hotel['nama'] ?? hotel['name'] ?? 'Hotel',
                    rating: (hotel['rating'] as num?)?.toDouble() ?? 0.0,
                    distance: LocationUtils.getDisplayDistance(hotel, _currentPosition),
                    price: rawPrice > 0 ? 'Rp ${_formatRupiah(rawPrice)}' : 'Hubungi Kami',
                    imageUrl: hotel['foto_utama_url'] ?? hotel['image_url'] ?? hotel['image'] ?? '',
                    isSelected: isSelected,
                    hotelData: hotel,
                    destName: widget.destName,
                    destDistance: destDistance,
                    onTap: () => _onCardTap(index),
                  );
                },
              ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.48,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image placeholder
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                ),
              ),
              // Content placeholder
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 36,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


