import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabaseUrl = 'https://pdhvqcbnsncxkfspasjq.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkaHZxY2Juc25jeGtmc3Bhc2pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzU4MDAsImV4cCI6MjA4OTQxMTgwMH0.jnKXzrsmsKQ5bq8cvl9FAK70TfggD8XbJuAmgXj6rq8';
  
  final client = SupabaseClient(supabaseUrl, supabaseKey);
  
  final data = [
    {
      'nama': 'Masjid Raya Al-Mashun',
      'kategori': 'Religi',
      'deskripsi': 'Masjid bersejarah peninggalan Kesultanan Deli, dibangun tahun 1906',
      'latitude': 3.5752,
      'longitude': 98.6837,
      'rating': 4.8,
      'is_active': true,
      'is_featured': true
    },
    {
      'nama': 'Istana Maimun',
      'kategori': 'Sejarah',
      'deskripsi': 'Istana Kesultanan Deli yang megah, dibangun tahun 1888',
      'latitude': 3.5752,
      'longitude': 98.6817,
      'rating': 4.7,
      'is_active': true,
      'is_featured': true
    },
    {
      'nama': 'Kesawan Square',
      'kategori': 'Sejarah',
      'deskripsi': 'Kawasan bersejarah dengan bangunan kolonial Belanda',
      'latitude': 3.5891,
      'longitude': 98.6739,
      'rating': 4.5,
      'is_active': true,
      'is_featured': false
    },
    {
      'nama': 'Tjong A Fie Mansion',
      'kategori': 'Sejarah',
      'deskripsi': 'Rumah bersejarah milik saudagar Tionghoa Tjong A Fie',
      'latitude': 3.5889,
      'longitude': 98.6741,
      'rating': 4.6,
      'is_active': true,
      'is_featured': false
    },
    {
      'nama': 'Gereja Immanuel',
      'kategori': 'Religi',
      'deskripsi': 'Gereja tertua di Medan, dibangun tahun 1921',
      'latitude': 3.5872,
      'longitude': 98.6756,
      'rating': 4.6,
      'is_active': true,
      'is_featured': false
    }
  ];
  
  try {
    debugPrint('Menjalankan Insert ke Supabase...');
    await client.from('destinasi').insert(data);
    debugPrint('Destinasi berhasil ditambahkan!');
  } catch (e) {
    debugPrint('Gagal: $e');
  }
}
