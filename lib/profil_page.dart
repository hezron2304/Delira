import 'package:flutter/material.dart';
import 'package:delira/booking_history_page.dart';
import 'package:delira/notifikasi_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/login_page.dart';
import 'package:delira/saved_hotels_page.dart';
import 'package:delira/theme/app_colors.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _isSigningOut = false;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSavedCount();
  }

  Future<void> _fetchSavedCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('favorit')
          .select('id')
          .eq('user_id', user.id);
      
      if (mounted) {
        setState(() {
          _savedCount = res.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching saved count: $e');
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header green + overlapping stats
          _buildHeaderWithStats(),
          const SizedBox(height: 60), // Space for overlapping badge + room before Aktivitas

          // Aktivitas
          _buildSectionLabel('Aktivitas'),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.location_on_outlined, 'Riwayat Kunjungan'),
          _buildMenuItem(
            Icons.favorite_border,
            'Tempat Tersimpan',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedHotelsPage()),
              );
              _fetchSavedCount(); // Refresh count when coming back
            },
          ),
          _buildMenuItem(
            Icons.receipt_long_outlined, 
            'Riwayat Pemesanan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookingHistoryPage()),
              );
            },
          ),
          _buildMenuItem(Icons.document_scanner_outlined, 'Riwayat Scan AI'),

          const SizedBox(height: 16),

          // Pengaturan
          _buildSectionLabel('Pengaturan'),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.language, 'Bahasa', trailing: 'Bahasa Indonesia'),
          _buildMenuItem(
            Icons.notifications_outlined,
            'Notifikasi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotifikasiPage()),
              );
            },
          ),
          _buildMenuItem(Icons.lock_outlined, 'Ubah Kata Sandi'),
          _buildMenuItem(Icons.info_outlined, 'Tentang Delira'),

          const SizedBox(height: 24),
          _buildSignOutButton(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Green header with avatar LEFT, name/email RIGHT, Edit Profil button,
  /// and stats badge overlapping the bottom edge.
  Widget _buildHeaderWithStats() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Green container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 76), // extra bottom for overlap
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Row: Avatar left, Name+Email right
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withAlpha(60),
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userEmail,
                          style: TextStyle(
                            color: Colors.white.withAlpha(190),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Edit Profil button — full width
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showComingSoon,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Edit Profil',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Stats badge — overlapping bottom of green header
        Positioned(
          bottom: -47,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildStat('12', 'Dikunjungi'),
                _buildVerticalDivider(),
                _buildStat(_savedCount.toString(), 'Disimpan'),
                _buildVerticalDivider(),
                _buildStat('8', 'Scan AI'),
              ],
            ),
          ),
        ),
      ],
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
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 16.0, bottom: 0),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  /// Each menu item is its own rounded card with spacing
  Widget _buildMenuItem(IconData icon, String label, {String? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap ?? _showComingSoon,
          splashColor: AppColors.primaryLight,
          highlightColor: AppColors.primaryLight.withAlpha(120),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right, color: Colors.black38, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _isSigningOut ? null : _signOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: _isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2),
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
