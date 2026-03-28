import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Destinasi {
  final String? id;
  final String nama;
  final String kategori;
  final String deskripsi;
  final String jamBuka;
  final String jamTutup;
  final double latitude;
  final double longitude;
  final int hargaTiket;
  final double rating;
  final String? fotoUtamaUrl;
  final List<String> gallery;
  final bool isActive;
  final bool isFeatured;

  Destinasi({
    this.id,
    required this.nama,
    required this.kategori,
    required this.deskripsi,
    required this.jamBuka,
    required this.jamTutup,
    required this.latitude,
    required this.longitude,
    this.hargaTiket = 0,
    required this.rating,
    this.fotoUtamaUrl,
    this.gallery = const [],
    this.isActive = true,
    this.isFeatured = false,
  });

  factory Destinasi.fromMap(Map<String, dynamic> map) {
    return Destinasi(
      id: map['id']?.toString(),
      nama: map['nama'] ?? '',
      kategori: map['kategori'] ?? '',
      deskripsi: map['deskripsi'] ?? '',
      jamBuka: map['jam_buka'] ?? '00:00',
      jamTutup: map['jam_tutup'] ?? '23:59',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      hargaTiket: (map['harga_tiket'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      fotoUtamaUrl: map['foto_utama_url'],
      gallery: map['gallery'] != null 
          ? List<String>.from(map['gallery']) 
          : [],
      isActive: map['is_active'] ?? true,
      isFeatured: map['is_featured'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nama': nama,
      'kategori': kategori,
      'deskripsi': deskripsi,
      'jam_buka': jamBuka,
      'jam_tutup': jamTutup,
      'latitude': latitude,
      'longitude': longitude,
      'harga_tiket': hargaTiket,
      'rating': rating,
      'foto_utama_url': fotoUtamaUrl,
      'gallery': gallery,
      'is_active': isActive,
      'is_featured': isFeatured,
    };
  }

  /// Mengecek apakah destinasi sedang buka berdasarkan waktu sistem sekarang.
  bool isOpenNow() {
    try {
      if (jamBuka.toLowerCase().contains('24 jam')) return true;
      if (jamBuka.isEmpty || jamTutup.isEmpty) return false;

      final now = DateTime.now();
      final currentTime = now.hour * 60 + now.minute;

      final bukaParts = jamBuka.split(':');
      final tutupParts = jamTutup.split(':');

      // Mentolerir format HH:MM:SS dari postgreSQL -> ambil saja index 0 dan 1
      if (bukaParts.length < 2 || tutupParts.length < 2) return false;

      final bukaTime = int.parse(bukaParts[0]) * 60 + int.parse(bukaParts[1]);
      final tutupTime = int.parse(tutupParts[0]) * 60 + int.parse(tutupParts[1]);

      if (tutupTime < bukaTime) {
        // Handle toko yang buka lewat tengah malam (misal 18:00 - 02:00)
        return currentTime >= bukaTime || currentTime <= tutupTime;
      }

      return currentTime >= bukaTime && currentTime <= tutupTime;
    } catch (e) {
      debugPrint('Error checking isOpenNow for format jamBuka($jamBuka) / jamTutup($jamTutup): $e');
      return false;
    }
  }

  /// Mendapatkan harga tiket yang terformat (Contoh: Rp 10.000).
  String get formattedPrice {
    if (hargaTiket == 0) return 'Gratis';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(hargaTiket);
  }

  /// Mendapatkan URL lengkap gambar dari Supabase Storage.
  /// Diasumsikan menggunakan bucket 'destinasi'.
  String get fullImageUrl {
    if (fotoUtamaUrl == null || fotoUtamaUrl!.isEmpty) return '';
    if (fotoUtamaUrl!.startsWith('http')) return fotoUtamaUrl!;
    
    const baseUrl = 'https://pdhvqcbnsncxkfspasjq.supabase.co';
    return '$baseUrl/storage/v1/object/public/destinasi/$fotoUtamaUrl';
  }

  /// Mendapatkan ikon yang sesuai berdasarkan kategori destinasi.
  dynamic get categoryIcon {
    switch (kategori.toLowerCase()) {
      case 'sejarah':
        return 0xe11b; // account_balance
      case 'religi':
        return 0xe408; // mosque / place
      case 'kuliner':
        return 0xe526; // restaurant
      default:
        return 0xe4a4; // place
    }
  }

  /// Menampilkan icon data berdasarkan kategori.
  IconData get iconData {
    switch (kategori.toLowerCase()) {
      case 'sejarah':
        return 0xe00b > 0 ? Icons.account_balance : Icons.place; 
      case 'religi':
        return Icons.place;
      case 'kuliner':
        return Icons.restaurant;
      default:
        return Icons.place;
    }
  }
}
