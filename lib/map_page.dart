import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:delira/detail_page.dart';

class MapPage extends StatefulWidget {
  final VoidCallback? onHotelRequested;
  const MapPage({super.key, this.onHotelRequested});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _allDestinasi = [];
  List<Marker> _markers = [];
  bool _isLoading = true;
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Check if user session exists
      final session = supabase.auth.currentSession;
      print('Session: $session');

      final response = await supabase
          .from('destinasi')
          .select('id, nama, kategori, deskripsi, latitude, longitude, rating, foto_utama_url')
          .eq('is_active', true);

      print('Response: $response');
      print('Count: ${response.length}');

      if (response.isEmpty) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Belum ada destinasi tersedia')));
        }
        return;
      }

      final List<Map<String, dynamic>> data =
          List<Map<String, dynamic>>.from(response);

      setState(() {
        _allDestinasi = data;
        _buildMarkers(data);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading markers: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _buildMarkers(List<Map<String, dynamic>> data) {
    _markers = data.map((dest) {
      return Marker(
        point: LatLng(
            (dest['latitude'] as num?)?.toDouble() ?? 0.0,
            (dest['longitude'] as num?)?.toDouble() ?? 0.0),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showBottomSheet(dest),
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
      _buildMarkers(_allDestinasi);
    } else {
      final filtered = _allDestinasi
          .where((d) => d['kategori'] == category)
          .toList();
      _buildMarkers(filtered);
    }
  }

  void _showBottomSheet(Map<String, dynamic> dest) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
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
                  child: dest['foto_utama_url'] != null
                      ? Image.network(
                          dest['foto_utama_url'],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFE8F5EE),
                            child: const Icon(Icons.place, color: Color(0xFF1A6B4A), size: 40),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: const Color(0xFFE8F5EE),
                          child: const Icon(Icons.place, color: Color(0xFF1A6B4A), size: 40),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest['nama'] ?? '',
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
                              dest['kategori'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF1A6B4A)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          Text(
                            ' ${dest['rating'] ?? 0}',
                            style: const TextStyle(fontSize: 12),
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
                        // Pass adapted destinasi map to old DetailPage format
                        // Using empty string for image since it's not present here
                        dest['image_url'] = dest['foto_utama_url'] ?? '';
                        dest['jarak_km'] = '2.3';
                        dest['filter'] = dest['kategori'];
                        
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
                          (dest['latitude'] as num).toDouble(),
                          (dest['longitude'] as num).toDouble(),
                          dest['nama'] ?? '',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            top: 48, // slightly lower to account for status bar since no appbar
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari lokasi...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF1A6B4A)),
                      suffixIcon: Icon(Icons.tune, color: Color(0xFF1A6B4A)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Category chips horizontal scroll
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Semua', 'Sejarah', 'Religi', 'Kuliner', 'Budaya'].map((cat) {
                      final isActive = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isActive,
                          onSelected: (_) => _filterByCategory(cat),
                          selectedColor: const Color(0xFF1A6B4A),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isActive ? Colors.white : const Color(0xFF1A6B4A),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: const BorderSide(color: Color(0xFF1A6B4A)),
                          showCheckmark: false,
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
    );
  }
}
