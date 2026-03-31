import 'package:flutter/material.dart';
import 'package:delira/booking_history_page.dart';
import 'package:delira/notifikasi_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/login_page.dart';
import 'package:delira/saved_hotels_page.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/history_page.dart';
import 'package:delira/edit_profil_page.dart';
import 'package:delira/change_password_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _isSigningOut = false;
  int _savedCount = 0;
  int _scanCount = 0;
  int _visitCount = 0;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    await Future.wait([
      _fetchSavedCount(),
      _fetchScanCount(),
      _fetchVisitCount(),
      _fetchProfileData(),
    ]);
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

  Future<void> _fetchScanCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('riwayat_scan')
          .select('id')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _scanCount = res.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching scan count: $e');
    }
  }

  Future<void> _fetchVisitCount() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('riwayat_kunjungan')
          .select('id')
          .eq('user_id', user.id);

      if (mounted) {
        setState(() {
          _visitCount = res.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching visit count: $e');
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && res != null) {
        setState(() {
          _profileData = res;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile data: $e');
    }
  }

  String get _userName {
    if (_profileData != null && _profileData!['nama_lengkap'] != null) {
      return _profileData!['nama_lengkap'];
    }
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['nama_lengkap'] as String? ?? 'Pengguna';
  }

  String get _userEmail {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String? get _avatarUrl {
    if (_profileData != null && _profileData!['foto_url'] != null) {
      return _profileData!['foto_url'];
    }
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['avatar_url'] as String?;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal keluar: $e')));
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fitur segera hadir')));
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Bahasa',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption('Bahasa Indonesia', true),
              const SizedBox(height: 12),
              _buildLanguageOption('English (Coming Soon)', false),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(String label, bool isSelected) {
    return InkWell(
      onTap: isSelected ? () => Navigator.pop(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showAboutDelira() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(60),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/delira_logo2.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Delira v1.0.0',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Deli Rasa & Realitas',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Apa Itu Delira?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Delira adalah asisten wisata cerdas pertama yang dirancang khusus untuk mengeksplorasi keindahan dan kekayaan budaya Kota Medan. Kami percaya bahwa setiap perjalanan haruslah bermakna, informatif, dan tak terlupakan.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureInfo(
                      Icons.camera_enhance_outlined,
                      'AI Visual & AR',
                      'Gunakan kamera Anda untuk memindai landmark bersejarah, kuliner khas, atau artefak budaya di Medan. AI kami akan mengidentifikasinya seketika dan memberikan informasi mendalam melalui Augmented Reality.',
                    ),
                    _buildFeatureInfo(
                      Icons.chat_bubble_outline,
                      'MedanBot Assistant',
                      'Asisten chat pintar yang siap menjawab segala pertanyaan Anda tentang transportasi, rekomendasi hotel terbaik, hingga rute kuliner tersembunyi yang hanya diketahui warga lokal.',
                    ),
                    _buildFeatureInfo(
                      Icons.hotel_outlined,
                      'E-Booking Super Cepat',
                      'Pesan hotel favorit Anda langsung melalui aplikasi dengan proses yang mulus, pembayaran yang aman, dan e-tiket yang selalu siap di saku Anda.',
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    const Text(
                      'Misi Kami',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mempromosikan pariwisata Medan melalui inovasi teknologi tercanggih, memudahkan wisatawan lokal maupun mancanegara untuk merasakan "Deli Rasa" yang sesungguhnya di tanah Melayu Deli.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      '© 2024 Delira Team • Medan, Indonesia',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureInfo(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
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
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          const SizedBox(
            height: 60,
          ), // Space for overlapping badge + room before Aktivitas
          // Aktivitas
          _buildSectionLabel('Aktivitas'),
          const SizedBox(height: 8),
          _buildMenuItem(
            Icons.location_on_outlined,
            'Riwayat Kunjungan',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const HistoryPage(type: HistoryType.visit),
                ),
              );
              _fetchAllStats();
            },
          ),
          _buildMenuItem(
            Icons.favorite_border,
            'Tempat Tersimpan',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedHotelsPage(),
                ),
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
                MaterialPageRoute(
                  builder: (context) => const BookingHistoryPage(),
                ),
              );
            },
          ),
          _buildMenuItem(
            Icons.document_scanner_outlined,
            'Riwayat Scan AI',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const HistoryPage(type: HistoryType.scan),
                ),
              );
              _fetchAllStats();
            },
          ),

          const SizedBox(height: 16),

          // Pengaturan
          _buildSectionLabel('Pengaturan'),
          const SizedBox(height: 8),
          _buildMenuItem(
            Icons.language,
            'Bahasa',
            trailing: 'Bahasa Indonesia',
            onTap: _showLanguagePicker,
          ),
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
          _buildMenuItem(
            Icons.lock_outlined,
            'Ubah Kata Sandi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          _buildMenuItem(
            Icons.info_outlined,
            'Tentang Delira',
            onTap: _showAboutDelira,
          ),

          const SizedBox(height: 24),
          _buildSignOutButton(),
          const SizedBox(height: 46),
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
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 24.0,
            24,
            76,
          ), // extra bottom for overlap
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
                    backgroundImage: _avatarUrl != null
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null
                        ? Text(
                            _initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
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
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfilPage(),
                      ),
                    );
                    if (updated == true) {
                      _fetchAllStats(); // Comprehensive refresh
                    }
                  },
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
                _buildStat(_visitCount.toString(), 'Dikunjungi'),
                _buildVerticalDivider(),
                _buildStat(_savedCount.toString(), 'Disimpan'),
                _buildVerticalDivider(),
                _buildStat(_scanCount.toString(), 'Scan AI'),
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
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
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
      padding: const EdgeInsets.only(
        left: 24.0,
        right: 24.0,
        top: 16.0,
        bottom: 0,
      ),
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
  Widget _buildMenuItem(
    IconData icon,
    String label, {
    String? trailing,
    VoidCallback? onTap,
  }) {
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black38,
                  size: 22,
                ),
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
                child: CircularProgressIndicator(
                  color: AppColors.danger,
                  strokeWidth: 2,
                ),
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
