import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/widgets/hotel_card.dart';
import 'package:delira/theme/app_colors.dart';

class SavedHotelsPage extends StatefulWidget {
  const SavedHotelsPage({super.key});

  @override
  State<SavedHotelsPage> createState() => _SavedHotelsPageState();
}

class _SavedHotelsPageState extends State<SavedHotelsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedItems = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchSavedHotels();
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

  Future<void> _fetchSavedHotels() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Join favorit dengan hotel
      final res = await Supabase.instance.client
          .from('favorit')
          .select('*, hotel(*)')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _savedItems = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching saved hotels: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text(
          'Tempat Tersimpan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedItems.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.48,
                  ),
                  itemCount: _savedItems.length,
                  itemBuilder: (context, index) {
                    final item = _savedItems[index];
                    final hotel = item['hotel'] as Map<String, dynamic>?;

                    if (hotel == null) return const SizedBox.shrink();

                    final rawPrice =
                        (hotel['harga_termurah'] as num?)?.toInt() ?? 0;

                    return HotelCard(
                      name: hotel['nama'] ?? hotel['name'] ?? 'Hotel',
                      rating: (hotel['rating'] as num?)?.toDouble() ?? 0.0,
                      distance: LocationUtils.getDisplayDistance(hotel, _currentPosition),
                      price: rawPrice > 0
                          ? 'Rp ${_formatRupiah(rawPrice)}'
                          : 'Hubungi Kami',
                      imageUrl: hotel['foto_utama_url'] ??
                          hotel['image_url'] ??
                          hotel['image'] ??
                          '',
                      isSelected: false,
                      hotelData: hotel,
                      onTap: () {
                        // Navigasi detail sudah dihandle otomatis oleh HotelCard
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum ada tempat tersimpan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Klik ikon hati pada hotel yang kamu suka untuk menyimpannya di sini agar mudah ditemukan kembali.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
