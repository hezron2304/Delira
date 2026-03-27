import 'package:geolocator/geolocator.dart';

class LocationUtils {
  /// Mendapatkan posisi saat ini dengan penanganan izin
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Cek apakah layanan lokasi aktif
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Menghitung jarak antara dua koordinat dan memformatnya
  static String calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    double distanceInMeters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );

    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      double distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  /// Helper untuk memformat objek hotel/destinasi dengan jarak dinamis
  static String getDisplayDistance(Map<String, dynamic> data, Position? userPos) {
    if (userPos == null) return '${data['jarak_km'] ?? '0.0'} km';

    final double? itemLat = (data['latitude'] as num?)?.toDouble();
    final double? itemLng = (data['longitude'] as num?)?.toDouble();

    if (itemLat == null || itemLng == null) {
      return '${data['jarak_km'] ?? '0.0'} km';
    }

    return calculateDistance(
      userPos.latitude,
      userPos.longitude,
      itemLat,
      itemLng,
    );
  }
}
