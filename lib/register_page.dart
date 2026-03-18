import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;
  bool _obscureRepeatPassword = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController = TextEditingController();

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final nama = _namaController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final repeatPassword = _repeatPasswordController.text.trim();

    if (nama.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua kolom harus diisi')));
      return;
    }

    if (password != repeatPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kata sandi tidak cocok')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nama_lengkap': nama,
          'nomor_hp': '+62$phone',
          'role': 'user',
        },
      );
      final user = res.user;
      if (user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pendaftaran berhasil!')));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mendaftar: ${error.message}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2D7A4F);
    const darkGreen = Color(0xFF1E6B4A);
    const inputFillColor = Color(0xFFF0F0F0); // light gray
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 24),
              
              // Headings
              const Text(
                'Buat Akun Baru',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bergabung dan mulai jelajahi Medan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              
              // Name Input
              _buildTextField(
                controller: _namaController,
                hintText: 'Nama lengkap kamu',
                prefixIcon: Icons.person_outline,
                fillColor: inputFillColor,
              ),
              const SizedBox(height: 16),
              
              // Email Input
              _buildTextField(
                controller: _emailController,
                hintText: 'Alamat email aktif',
                prefixIcon: Icons.email_outlined,
                fillColor: inputFillColor,
              ),
              const SizedBox(height: 16),
              
              // Phone Input
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: '8xx-xxxx-xxxx',
                  hintStyle: const TextStyle(color: Colors.black38),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.black54),
                  prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  prefix: const Padding(
                    padding: EdgeInsets.only(right: 8.0, left: 8.0),
                    child: Text('+62', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              
              // Password Input
              _buildPasswordField(
                controller: _passwordController,
                hintText: 'Buat kata sandi (min. 8 karakter)',
                prefixIcon: Icons.lock_outline,
                obscure: _obscurePassword,
                fillColor: inputFillColor,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Repeat Password Input
              _buildPasswordField(
                controller: _repeatPasswordController,
                hintText: 'Ulangi kata sandi',
                prefixIcon: Icons.shield_outlined,
                obscure: _obscureRepeatPassword,
                fillColor: inputFillColor,
                onToggleVisibility: () {
                  setState(() {
                    _obscureRepeatPassword = !_obscureRepeatPassword;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Checkbox and Terms
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: primaryGreen,
                      onChanged: (val) {
                        setState(() { _agreedToTerms = val ?? false; });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'Saya setuju dengan ',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' dan '),
                          TextSpan(
                            text: 'Kebijakan Privasi',
                            style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Primary Button
              ElevatedButton(
                onPressed: (_agreedToTerms && !_isLoading) ? _signUp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: primaryGreen, strokeWidth: 2))
                    : const Text(
                        'Daftar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 32),
              
              // Bottom Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sudah punya akun? ',
                    style: TextStyle(color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Masuk',
                      style: TextStyle(
                        color: darkGreen,
                        fontWeight: FontWeight.bold,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required Color fillColor,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        prefixIcon: Icon(prefixIcon, color: Colors.black54),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    required bool obscure,
    required VoidCallback onToggleVisibility,
    required Color fillColor,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38),
        prefixIcon: Icon(prefixIcon, color: Colors.black54),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.black54,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
