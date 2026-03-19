import 'package:flutter/material.dart';
import 'package:delira/detail_page.dart';
import 'package:delira/theme/app_colors.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onHotelRequested;
  const MapPage({super.key, this.onHotelRequested});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  // Data dummy lokasi
  final List<Map<String, dynamic>> _locations = [
    {
      'nama': 'Masjid Raya Al-Mashun',
      'kategori': 'Situs Sejarah',
      'rating': 4.8,
      'jarak_km': 2.3,
      'icon': Icons.mosque,
      'topPercent': 0.30,
      'leftPercent': 0.25,
    },
    {
      'nama': 'Istana Maimun',
      'kategori': 'Sejarah',
      'rating': 4.7,
      'jarak_km': 1.8,
      'icon': Icons.account_balance,
      'topPercent': 0.50,
      'leftPercent': 0.60,
    },
    {
      'nama': 'Gereja Immanuel',
      'kategori': 'Religi',
      'rating': 4.6,
      'jarak_km': 3.1,
      'icon': Icons.church,
      'topPercent': 0.55,
      'leftPercent': 0.20,
    },
    {
      'nama': 'Soto Kesawan',
      'kategori': 'Kuliner',
      'rating': 4.9,
      'jarak_km': 0.8,
      'icon': Icons.ramen_dining,
      'topPercent': 0.38,
      'leftPercent': 0.55,
    },
  ];

  int _selectedIndex = 0;
  late AnimationController _sheetController;
  bool _isDragging = false;

  // Card height for the slide calculation
  static const double _cardMaxSlide = 280.0;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // Start with sheet visible (value=1 means fully open)
    _sheetController.value = 1.0;
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  bool get _isSheetVisible => _sheetController.value > 0.5;

  void _selectLocation(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Always open if tapping a pin
    _sheetController.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) {
      _isDragging = true;
    }
    // Drag down = negative delta on controller value
    // Drag up = positive delta on controller value
    final double delta = -details.primaryDelta! / _cardMaxSlide;
    _sheetController.value = (_sheetController.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    _isDragging = false;
    final double velocity = details.primaryVelocity ?? 0;

    // Fast swipe: respect direction
    if (velocity > 500) {
      // Swipe down fast → close
      _sheetController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else if (velocity < -500) {
      // Swipe up fast → open
      _sheetController.animateTo(1.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      // Slow drag: snap to closest state
      if (_sheetController.value > 0.5) {
        _sheetController.animateTo(1.0, curve: Curves.easeOutCubic);
      } else {
        _sheetController.animateTo(0.0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final selected = _locations[_selectedIndex];

    return Stack(
      children: [
        // Dummy Map Background
        Container(
          color: AppColors.primaryLight.withAlpha(80),
          width: double.infinity,
          height: double.infinity,
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),

        // Clickable Map Pins
        ..._locations.asMap().entries.map((entry) {
          final idx = entry.key;
          final loc = entry.value;
          final isSelected = idx == _selectedIndex;
          return Positioned(
            top: screenH * (loc['topPercent'] as double),
            left: screenW * (loc['leftPercent'] as double),
            child: GestureDetector(
              onTap: () => _selectLocation(idx),
              child: _buildMapPin(
                loc['icon'] as IconData,
                isSelected ? AppColors.primary : AppColors.primary.withAlpha(160),
                isSelected,
              ),
            ),
          );
        }),

        // My Location blue dot
        Positioned(
          top: screenH * 0.46,
          left: screenW * 0.45,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),

        // Near me FAB
        Positioned(
          bottom: _isSheetVisible ? 310 : 100,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'nearMeBtn',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () {},
            child: const Icon(Icons.near_me_outlined, color: AppColors.textPrimary),
          ),
        ),

        // Search Bar at Top
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
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
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari lokasi...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: const Icon(Icons.tune, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),

        // Swipeable Bottom Card — follows finger
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, child) {
            final double slideOffset = _cardMaxSlide * (1 - _sheetController.value);
            return Positioned(
              bottom: 20 - slideOffset,
              left: 16,
              right: 16,
              child: GestureDetector(
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: child!,
              ),
            );
          },
          child: _buildBottomCard(selected),
        ),

        // "Lihat Detail" hint when card is mostly hidden
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, child) {
            // Only show when card is mostly hidden
            final opacity = (1 - _sheetController.value * 3).clamp(0.0, 1.0);
            if (opacity <= 0) return const SizedBox.shrink();
            return Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: opacity,
                child: GestureDetector(
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  onTap: () {
                    _sheetController.animateTo(1.0, curve: Curves.easeOutCubic);
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.keyboard_arrow_up, color: AppColors.primary, size: 20),
                          SizedBox(width: 4),
                          Text(
                            'Lihat Detail',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomCard(Map<String, dynamic> location) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(location['icon'] as IconData, color: AppColors.primary, size: 36),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location['nama'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          location['kategori'] as String,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          location['rating'].toString(),
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 10),
                        const Text('•', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Text(
                          '${location['jarak_km']} km',
                          style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailPage(destinasi: location),
                      ),
                    );
                    if (result == 'GO_TO_HOTEL' && widget.onHotelRequested != null) {
                      widget.onHotelRequested!();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Navigasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin(IconData icon, Color color, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.all(isSelected ? 10 : 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppColors.primary.withAlpha(100) : Colors.black26,
                blurRadius: isSelected ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isSelected ? 22 : 18),
        ),
        Container(
          width: 3,
          height: isSelected ? 18 : 14,
          color: color,
        ),
        Container(
          width: isSelected ? 10 : 7,
          height: isSelected ? 10 : 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withAlpha(50)
      ..strokeWidth = 1.0;

    const double spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
