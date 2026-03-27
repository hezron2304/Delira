import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/widgets/hotel_card.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

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
      } else if (_activeCategory == 'Budget') {
        query = query.lte('harga_termurah', 500000);
      }

      final res = await query
          .range(from, to)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> newData =
          List<Map<String, dynamic>>.from(res);

      if (mounted) {
        setState(() {
          _hotels.addAll(newData);
          _isLoading = false;
          _isLoadingMore = false;
          _page++;
          _hasMore = newData.length == _pageSize;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('FETCH ERROR: $e');
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
    return GestureDetector(
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
            TextField(
              decoration: InputDecoration(
                hintText: 'Cari hotel...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                
                return HotelCard(
                  name: hotel['nama'] ?? hotel['name'] ?? 'Hotel',
                  rating: (hotel['rating'] as num?)?.toDouble() ?? 0.0,
                  distance: LocationUtils.getDisplayDistance(hotel, _currentPosition),
                  price: rawPrice > 0 ? 'Rp ${_formatRupiah(rawPrice)}' : 'Hubungi Kami',
                  imageUrl: hotel['foto_utama_url'] ?? hotel['image_url'] ?? hotel['image'] ?? '',
                  isSelected: isSelected,
                  hotelData: hotel,
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


