import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delira/detail_page.dart';
import 'package:delira/utils/location_utils.dart';
import 'package:delira/models/destinasi.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:flutter/services.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onHotelRequested;
  const MapPage({super.key, this.onHotelRequested});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  List<Destinasi> _allDestinasi = [];
  List<Map<String, dynamic>> _allHotels = [];
  List<Marker> _markers = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    final pos = await LocationUtils.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userPosition = pos;
        // Center map to user once
        if (pos != null) {
          _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
        }
        _buildMarkers(_allDestinasi, _allHotels);
      });
    }
  }

  Future<void> _loadMarkers() async {
    setState(() => _isLoading = true);
    
    // individual data holders
    List<Destinasi> loadedDestinasi = [];
    List<Map<String, dynamic>> loadedHotels = [];
    String? errorSource;

    try {
      // 1. Fetch Destinasi
      try {
        final destResponse = await Supabase.instance.client
            .from('destinasi')
            .select() // Fetch all to avoid missing required fields in Model.fromMap
            .eq('is_active', true);
        
        final List<Map<String, dynamic>> rawDest = List<Map<String, dynamic>>.from(destResponse);
        loadedDestinasi = rawDest.map((d) {
          try {
            return Destinasi.fromMap(d);
          } catch (e) {
            debugPrint('DEBUG: Skip Destinasi ID ${d['id']} due to parse error: $e');
            return null;
          }
        }).whereType<Destinasi>().toList();
        
        debugPrint('DEBUG: Successfully fetched ${loadedDestinasi.length} destinasi');
      } catch (e) {
        debugPrint('DEBUG: Error fetching destinasi: $e');
        errorSource = 'destinasi';
      }

      // 2. Fetch Hotels
      try {
        final hotelResponse = await Supabase.instance.client.from('hotel').select();
        loadedHotels = List<Map<String, dynamic>>.from(hotelResponse);
        debugPrint('DEBUG: Successfully fetched ${loadedHotels.length} hotels');
      } catch (e) {
        debugPrint('DEBUG: Error fetching hotels: $e');
        errorSource = errorSource == null ? 'hotel' : 'data';
      }

      if (mounted) {
        setState(() {
          _allDestinasi = loadedDestinasi;
          _allHotels = loadedHotels;
          _buildMarkers(loadedDestinasi, loadedHotels);
          _isLoading = false;
        });

        // Inform user if partial failure occurred
        if (errorSource != null && loadedDestinasi.isEmpty && loadedHotels.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengambil data $errorSource. Periksa koneksi internet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Global map error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan sistem peta.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _buildMarkers(List<Destinasi> destData, List<Map<String, dynamic>> hotelData) {
    final destMarkers = destData
        .where((d) => d.latitude != 0.0 && d.longitude != 0.0) // Filter invalid coordinates
        .map((dest) {
      return Marker(
        point: LatLng(dest.latitude, dest.longitude),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showBottomSheetDestinasi(dest),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A6B4A),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.place, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();

    final hotelMarkers = hotelData
        .where((h) => (h['latitude'] != null && h['latitude'] != 0.0)) // Filter invalid coordinates
        .map((h) {
      return Marker(
        point: LatLng(
            (h['latitude'] as num?)?.toDouble() ?? 0.0,
            (h['longitude'] as num?)?.toDouble() ?? 0.0),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showBottomSheet(h, true),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.hotel, color: Colors.white, size: 20),
          ),
        ),
      );
    }).toList();

    final userMarker = _userPosition != null 
      ? [Marker(
          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(50),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ],
          ),
        )]
      : [];

    _markers = [...destMarkers, ...hotelMarkers, ...userMarker];
  }

  Future<void> _openNavigation(double lat, double lng, String nama) async {
    // Try Google Maps app first
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$lat,$lng&mode=d'
    );

    // Fallback to browser Google Maps if app not installed
    final googleMapsBrowser = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_name=${Uri.encodeComponent(nama)}&travelmode=driving'
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else if (await canLaunchUrl(googleMapsBrowser)) {
      await launchUrl(googleMapsBrowser, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka navigasi')));
      }
    }
  }

  void _filterByCategory(String category) {
    setState(() => _selectedCategory = category);
    if (category == 'Semua') {
      _buildMarkers(_allDestinasi, _allHotels);
    } else {
      final filtered = _allDestinasi
          .where((d) => d.kategori == category)
          .toList();
      _buildMarkers(filtered, _allHotels);
    }
  }

  void _showBottomSheetDestinasi(Destinasi dest) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      dest.fullImageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFE8F5EE),
                        child: const Icon(Icons.place, color: Color(0xFF1A6B4A), size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dest.nama,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5EE),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                dest.kategori,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF1A6B4A)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            Text(
                              ' ${dest.rating}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(
                              LocationUtils.getDisplayDistance(dest.toMap(), _userPosition),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A6B4A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // close sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailPage(destinasi: dest),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1A6B4A)),
                          foregroundColor: const Color(0xFF1A6B4A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Lihat Detail',
                          style: TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // tutup bottom sheet
                          _openNavigation(
                            dest.latitude,
                            dest.longitude,
                            dest.nama,
                          );
                        },
                        icon: const Icon(Icons.explore, size: 16, color: Colors.white),
                        label: const Text(
                          'Navigasi',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A6B4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomSheetHotel(Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      h['image_url'] ?? '',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Container(
                        width: 80,
                        height: 80,
                        color: const Color(0xFFE8F5EE),
                        child: const Icon(Icons.hotel, color: Colors.orange, size: 40),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          h['nama'] ?? h['name'] ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Hotel',
                                style: TextStyle(fontSize: 11, color: Colors.orange),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            Text(
                              ' ${(h['rating'] as num?)?.toDouble() ?? 5.0}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            const Text('•', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(
                              LocationUtils.getDisplayDistance(h, _userPosition),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context); // close sheet
                          if (widget.onHotelRequested != null) {
                            widget.onHotelRequested!();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Lihat Hotel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context); // tutup bottom sheet
                          _openNavigation(
                            (h['latitude'] as num?)?.toDouble() ?? 0.0,
                            (h['longitude'] as num?)?.toDouble() ?? 0.0,
                            h['nama'] ?? h['name'] ?? '',
                          );
                        },
                        icon: const Icon(Icons.explore, size: 16, color: Colors.white),
                        label: const Text(
                          'Navigasi',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomSheet(dynamic dest, bool isHotel) {
    if (isHotel) {
       _showBottomSheetHotel(dest as Map<String, dynamic>);
    } else {
       _showBottomSheetDestinasi(dest as Destinasi);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent, // Immersive map feel
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(3.5952, 98.6722),
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.delira.app',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
            
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A6B4A)),
              ),

            Positioned(
              top: 48, 
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari lokasi...',
                        hintStyle: TextStyle(color: Colors.grey.withAlpha(150), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Semua', 'Sejarah', 'Religi', 'Kuliner', 'Budaya'].map((cat) {
                        final isActive = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => _filterByCategory(cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? Colors.transparent : AppColors.border,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha( isActive ? 40 : 10),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isActive ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            Positioned(
              right: 16,
              bottom: 100,
              child: FloatingActionButton.small(
                heroTag: 'myLocBtn',
                onPressed: () async {
                  LocationPermission permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                  }
                  if (permission == LocationPermission.deniedForever) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Izin lokasi ditolak permanen. Silakan ubah di pengaturan.')),
                    );
                    return;
                  }
                  if (permission == LocationPermission.whileInUse ||
                      permission == LocationPermission.always) {
                    Position pos = await Geolocator.getCurrentPosition();
                    setState(() {
                      _userPosition = pos;
                      _buildMarkers(_allDestinasi, _allHotels);
                    });
                    _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Izin lokasi ditolak')),
                    );
                  }
                },
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A6B4A),
                elevation: 4,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
