import 'package:flutter/material.dart';
import 'package:delira/hotel_detail_page.dart';
import 'package:delira/theme/app_colors.dart';

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

  final List<Map<String, dynamic>> _hotels = [
    {
      'name': 'Grand Mercure Medan Angkasa',
      'rating': 4.8,
      'distance': '0.5 km',
      'price': 'Rp 850.000',
      'image': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hotel Aryaduta Medan',
      'rating': 4.6,
      'distance': '1.1 km',
      'price': 'Rp 520.000',
      'image': 'https://images.unsplash.com/photo-1590490360182-c33d72085a08?auto=format&fit=crop&q=80',
    },
    {
      'name': 'Hotel Dharma Deli',
      'rating': 4.3,
      'distance': '1.2 km',
      'price': 'Rp 400.000',
      'image': 'https://images.unsplash.com/photo-1566665797739-1674de7a421a?auto=format&fit=crop&q=80',
    },
    {
      'name': 'Novotel Medan',
      'rating': 4.5,
      'distance': '0.8 km',
      'price': 'Rp 750.000',
      'image': 'https://images.unsplash.com/photo-1582719478250-c89cae4df85d?auto=format&fit=crop&q=80',
    },
    {
      'name': 'JW Marriott Medan',
      'rating': 4.9,
      'distance': '1.5 km',
      'price': 'Rp 1.200.000',
      'image': 'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?auto=format&fit=crop&q=80',
    },
    {
      'name': 'Santika Premiere Dyandra',
      'rating': 4.4,
      'distance': '2.0 km',
      'price': 'Rp 480.000',
      'image': 'https://images.unsplash.com/photo-1571003123894-1f0594d2b5d9?auto=format&fit=crop&q=80',
    },
  ];

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
            ),
            const SizedBox(height: 24),

            // Grid
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
                return _HotelCard(
                  name: hotel['name'] as String,
                  rating: hotel['rating'] as double,
                  distance: hotel['distance'] as String,
                  price: hotel['price'] as String,
                  imageUrl: hotel['image'] as String,
                  isSelected: isSelected,
                  hotelData: hotel,
                  onTap: () => _onCardTap(index),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _HotelCard extends StatefulWidget {
  final String name;
  final double rating;
  final String distance;
  final String price;
  final String imageUrl;
  final bool isSelected;
  final Map<String, dynamic> hotelData;
  final VoidCallback onTap;

  const _HotelCard({
    required this.name,
    required this.rating,
    required this.distance,
    required this.price,
    required this.imageUrl,
    required this.isSelected,
    required this.hotelData,
    required this.onTap,
  });

  @override
  State<_HotelCard> createState() => _HotelCardState();
}

class _HotelCardState extends State<_HotelCard> {
  bool _isButtonActive = false;

  @override
  Widget build(BuildContext context) {
    final bool elevated = widget.isSelected;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..setTranslationRaw(0.0, elevated ? -4.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: elevated ? AppColors.primary.withAlpha(80) : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: elevated
                  ? AppColors.primary.withAlpha(40)
                  : Colors.black.withAlpha(8),
              blurRadius: elevated ? 20 : 8,
              offset: Offset(0, elevated ? 8 : 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image container
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      image: DecorationImage(
                        image: NetworkImage(widget.imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.rating.toString(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Info Section
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(Icons.star, color: i < widget.rating.floor() ? Colors.amber : Colors.grey.shade300, size: 12),
                      ),
                    ),
                    Text(widget.distance, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(widget.price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                        ),
                        const Text('/malam', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Button: toggles green on click
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HotelDetailPage(hotel: widget.hotelData),
                          ),
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isButtonActive ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isButtonActive ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isButtonActive ? Colors.white : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
