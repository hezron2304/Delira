import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/login_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _isSigningOut = false;

  static const primaryGreen = Color(0xFF1A6B4A);
  static const darkGreen = Color(0xFF145238);

  String get _userName {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['nama_lengkap'] as String? ?? 'Pengguna';
  }

  String get _userEmail {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String get _initials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'P';
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal keluar: $e')),
        );
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur segera hadir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildTopCard(),
          const SizedBox(height: 16),
          _buildStatsCard(),
          const SizedBox(height: 16),
          _buildSectionLabel('Aktivitas'),
          _buildMenuCard([
            _buildTile(Icons.location_on_outlined, 'Riwayat Kunjungan'),
            _buildTile(Icons.favorite_border, 'Tempat Tersimpan'),
            _buildTile(Icons.receipt_long_outlined, 'Riwayat Pemesanan'),
            _buildTile(Icons.document_scanner_outlined, 'Riwayat Scan AI'),
          ]),
          const SizedBox(height: 16),
          _buildSectionLabel('Pengaturan'),
          _buildMenuCard([
            _buildTile(Icons.language, 'Bahasa', trailing: 'Bahasa Indonesia'),
            _buildTile(Icons.notifications_outlined, 'Notifikasi'),
            _buildTile(Icons.lock_outlined, 'Ubah Kata Sandi'),
            _buildTile(Icons.info_outlined, 'Tentang Delira'),
          ]),
          const SizedBox(height: 24),
          _buildSignOutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      decoration: const BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: darkGreen,
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _showComingSoon,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white, width: 1.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            ),
            child: const Text(
              'Edit Profil',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
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
        child: Row(
          children: [
            _buildStat('12', 'Dikunjungi'),
            _buildVerticalDivider(),
            _buildStat('5', 'Disimpan'),
            _buildVerticalDivider(),
            _buildStat('8', 'Scan AI'),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> tiles) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Column(
          children: tiles
              .asMap()
              .entries
              .map((e) => Column(
                    children: [
                      e.value,
                      if (e.key < tiles.length - 1)
                        Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String label, {String? trailing}) {
    return ListTile(
      onTap: _showComingSoon,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: primaryGreen.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryGreen, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.black38, size: 20),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _isSigningOut ? null : _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        label: const Text(
          'Keluar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
