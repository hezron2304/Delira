import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';

class DetailPage extends StatelessWidget {
  final Map<String, dynamic> destinasi;

  const DetailPage({super.key, required this.destinasi});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageHeader(context),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildVisitInfoSection(),
                  const SizedBox(height: 24),
                  _buildGallerySection(),
                  const SizedBox(height: 24),
                  _buildReviewsSection(),
                  const SizedBox(height: 100), // Bottom bar space
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomActionBar(context),
    );
  }

  Widget _buildImageHeader(BuildContext context) {
    return Stack(
      children: [
        Image.network(
          destinasi['image_url'] ?? '',
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 300,
            color: Colors.grey[300],
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: Colors.grey[500],
            ),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 300,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A6B4A)),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.orange,
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          destinasi['nama'] ?? '',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            destinasi['filter'] ?? (destinasi['kategori'] ?? 'Wisata'),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatBox(
          Icons.star,
          destinasi['rating'].toString(),
          'Rating',
          Colors.orange,
        ),
        _buildStatBox(
          Icons.location_on,
          '${destinasi['jarak_km']} km',
          'Jarak',
          Colors.green,
        ),
        _buildStatBox(Icons.attach_money, 'Gratis', 'Tiket', Colors.teal),
        _buildStatBox(Icons.calendar_today, '1906', 'Tahun', Colors.grey),
      ],
    );
  }

  Widget _buildStatBox(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deskripsi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          '${destinasi['nama']} adalah tempat bersejarah yang sangat indah dan ikonik di Kota Medan. Merupakan perpaduan arsitektur yang megah dan memiliki nilai budaya tinggi.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 8),
        const Text(
          'Baca selengkapnya',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Info Kunjungan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(
          Icons.access_time,
          'Jam Buka',
          'Senin - Minggu: 05.00 - 21.00',
        ),
        _buildInfoRow(Icons.attach_money, 'Tiket Masuk', 'Gratis'),
        _buildInfoRow(
          Icons.checkroom,
          'Dress Code',
          'Berpakaian sopan dan menutup aurat',
        ),
        _buildInfoRow(
          Icons.location_on_outlined,
          'Alamat',
          'Jl. Sisingamangaraja, Medan Kota, Medan',
        ),
        _buildInfoRow(Icons.phone_outlined, 'Kontak', '+62 61 4514441'),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Galeri Foto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(destinasi['image_url'] ?? ''),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ulasan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildReviewCard('Ahmad Rizki'),
        const SizedBox(height: 12),
        _buildReviewCard('Siti Aminah'),
      ],
    );
  }

  Widget _buildReviewCard(String name) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(
                      5,
                      (i) => const Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tempat yang sangat indah dan bersejarah. Arsitekturnya luar biasa!',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // AI Guide Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: Color(0xFF1A6B4A),
                ),
                label: const Text(
                  'AI Guide',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A6B4A),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A6B4A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Hotel Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'GO_TO_HOTEL');
                },
                icon: const Icon(
                  Icons.hotel_outlined,
                  size: 16,
                  color: Color(0xFF1A6B4A),
                ),
                label: const Text(
                  'Hotel Dekat',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A6B4A),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A6B4A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Navigasi Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.explore, size: 16, color: Colors.white),
                label: const Text(
                  'Navigasi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A6B4A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
