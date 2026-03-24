import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIGuidePage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const AIGuidePage({super.key, this.onBackPressed});

  @override
  State<AIGuidePage> createState() => _AIGuidePageState();
}

class _AIGuidePageState extends State<AIGuidePage>
    with WidgetsBindingObserver {
  // ── Tab & mode state ────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0 = Scan/AR, 1 = Chat AI
  bool _isARMode = true; // true = AR, false = Scan

  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // ── AR Gemini Vision ────────────────────────────────────────────────────────
  Timer? _arTimer;
  String? _arLabel;
  bool _isARDetecting = false;

  // ── Scan / Gemini Vision ────────────────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();
  bool _isScanLoading = false;
  String? _scanResult;
  String? _capturedImagePath;

  // Chat AI
  final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  
  late final GenerativeModel _visionModel;
  late final GenerativeModel _chatModel;

  bool _isCooldown = false;
  Timer? _cooldownTimer;

  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _answerBank = {
    'tempat terdekat':
        '📍 Destinasi terdekat di Medan: Masjid Raya Al-Mashun (2.3 km), Istana Maimun (2.5 km), dan Kesawan Square (3.1 km). Semua bisa ditempuh dalam 10-15 menit! 🗺️',
    'masjid raya':
        '🕌 Masjid Raya Al-Mashun dibangun tahun 1906 oleh Sultan Ma\'mun Al-Rasyid. Arsitekturnya memadukan gaya Timur Tengah, India, dan Spanyol. Buka setiap hari dan gratis untuk dikunjungi!',
    'istana maimun':
        '🏰 Istana Maimun dibangun tahun 1888 oleh Sultan Deli. Merupakan simbol kejayaan Kesultanan Melayu Deli. Tiket masuk Rp 5.000, buka 08.00-17.00 WIB.',
    'kesawan':
        '🏛️ Kesawan Square adalah kawasan bersejarah dengan bangunan kolonial Belanda abad ke-19. Cocok untuk wisata malam dan foto-foto! Buka 24 jam dan gratis.',
    'tjong a fie':
        '🏚️ Tjong A Fie Mansion dibangun tahun 1900 oleh saudagar Tionghoa legendaris. Kini menjadi museum dengan koleksi furnitur antik. Tiket Rp 35.000.',
    'gereja immanuel':
        '⛪ Gereja Immanuel Medan dibangun tahun 1921, salah satu gereja tertua di Medan. Arsitektur kolonial Belanda yang indah di pusat kota.',
    'kuliner':
        '🍜 Kuliner wajib coba di Medan: Soto Medan, Bika Ambon, Mie Gomak, Durian Ucok, dan Lemang. Jangan lupa coba Kopi Sidikalang yang legendaris! ☕',
    'bika ambon':
        '🍰 Bika Ambon adalah oleh-oleh khas Medan berbahan dasar kelapa dan telur. Pusat penjualannya ada di Jalan Mojopahit. Harga mulai Rp 40.000/kotak.',
    'durian':
        '🍈 Durian Ucok di Jalan Iskandar Muda adalah yang paling terkenal di Medan! Buka dari siang sampai malam. Harga mulai Rp 50.000/buah tergantung ukuran.',
    'soto medan':
        '🍲 Soto Medan berbeda dari soto lainnya karena kuahnya bersantan dan kaya rempah. Coba di Soto Kesawan atau Soto Hidayah yang legendaris!',
    'makan':
        '🍜 Rekomendasi kuliner Medan: Soto Medan (santan kaya rempah), Bika Ambon (oleh-oleh khas), Durian Ucok (durian premium), dan Mie Gomak (mie khas Batak)!',
    'hotel':
        '🏨 Hotel terbaik di Medan: Grand Mercure Angkasa (bintang 5), Hotel Aryaduta (bintang 4), Novotel Medan (bintang 4). Pesan sekarang lewat fitur Hotel di app ini! 😊',
    'penginapan':
        '🏨 Pilihan penginapan di Medan mulai dari budget Rp 200rb/malam hingga hotel bintang 5 Rp 1 juta+/malam. Cek fitur Hotel di app ini untuk booking langsung!',
    'transportasi':
        '🚗 Transportasi di Medan: Grab/Gojek tersedia 24 jam, Angkot untuk rute tertentu, dan taksi Blue Bird. Untuk wisata keliling kota, sewa mobil mulai Rp 300rb/hari.',
    'dari bandara':
        '✈️ Dari Bandara Kualanamu ke pusat kota: Kereta Bandara (Rp 120rb, 45 menit), Grab/Gojek (Rp 80-150rb, 45-60 menit tergantung macet).',
    'sejarah medan':
        '📚 Medan berkembang pesat sejak abad ke-19 sebagai pusat perkebunan tembakau. Didirikan tahun 1886, Medan menjadi kota terbesar ketiga di Indonesia dengan sejarah multietnis yang kaya!',
    'sejarah':
        '📚 Medan didirikan tahun 1886 dan berkembang sebagai pusat perkebunan tembakau Deli. Perpaduan budaya Melayu, Batak, Tionghoa, dan kolonial Belanda membentuk karakter unik kota ini.',
    'halo':
        '👋 Halo! Selamat datang di MedanBot! Saya siap membantu kamu menjelajahi Kota Medan. Mau tanya tentang wisata, kuliner, hotel, atau transportasi? 😊',
    'hai': '👋 Hai! Ada yang bisa saya bantu tentang wisata Medan hari ini? 😊',
    'terima kasih':
        '😊 Sama-sama! Semoga perjalanan wisata kamu di Medan menyenangkan! Jangan ragu untuk bertanya lagi ya! 🗺️',
    'rekomendasi':
        '⭐ Rekomendasi top Medan: 1) Masjid Raya Al-Mashun 2) Istana Maimun 3) Kesawan Square 4) Tjong A Fie Mansion 5) Durian Ucok. Semuanya wajib dikunjungi! 🏆',
  };

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Gemini Models
    _visionModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
    _chatModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);

    _messages.add({
      'role': 'bot',
      'text': 'Halo! 👋 Saya MedanBot, asisten wisata Kota Medan. Ada yang bisa saya bantu? 🗺️',
    });
    _initCamera();
  }

  void _startARDetection() {
    _arTimer?.cancel();
    debugPrint('DEBUG: Memulai Timer Deteksi AR (Delay 2s)');
    
    // Beri waktu kamera benar-benar siap sebelum deteksi pertama
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !_isARMode) return;
      
      _arTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
        if (!_isARMode || !_cameraReady || _cameraController == null) return;
        if (_isARDetecting || !_cameraController!.value.isInitialized) return;
      
      _isARDetecting = true;
      if (mounted) setState(() {});
      
      try {
        debugPrint('DEBUG: Menangkap foto AR...');
        final XFile file = await _cameraController!.takePicture();
        final bytes = await File(file.path).readAsBytes();
        
        debugPrint('DEBUG: Mengirim ke Gemini Vision via Package...');
        if (_isCooldown) {
          debugPrint('DEBUG: AI sedang Cooldown, skip deteksi AR.');
          return;
        }

        final content = [
          Content.multi([
            DataPart('image/jpeg', bytes),
            TextPart('Identify major objects (landmarks, buildings, nature) in this image. Give ONLY 1 to 3 words as labels, followed by emoji. Example: "Istana Maimun 🏰". Answer in Indonesian.'),
          ])
        ];

        final response = await _visionModel.generateContent(content);
        final label = response.text;
        
        debugPrint('DEBUG: Terdeteksi: $label');
        if (label != null && label.isNotEmpty && mounted) {
          setState(() => _arLabel = label.trim());
        }
      } catch (e) {
        debugPrint('DEBUG: Error Deteksi AR: $e');
        if (e.toString().contains('429') || e.toString().contains('quota')) {
          _triggerCooldown();
        }
      } finally {
        _isARDetecting = false;
        if (mounted) setState(() {});
      }
      });
    });
  }

  void _stopARDetection() {
    _arTimer?.cancel();
    _arTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      final controller = CameraController(
        _cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
      if (_isARMode) _startARDetection();
    } catch (_) {
      setState(() => _cameraReady = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopARDetection();
    _cooldownTimer?.cancel();
    _cameraController?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Camera widget ─────────────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return SizedBox.expand(
        child: CameraPreview(_cameraController!),
      );
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text('Menyiapkan kamera...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Scan / Gemini Vision ─────────────────────────────────────────────────────

  Future<void> _captureAndAnalyze() async {
    if (!_cameraReady || _cameraController == null) return;
    try {
      final XFile file = await _cameraController!.takePicture();
      _analyzeImage(file.path);
    } catch (_) {}
  }

  Future<void> _pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (file == null) return;
    _analyzeImage(file.path);
  }

  Future<void> _analyzeImage(String path) async {
    setState(() {
      _capturedImagePath = path;
      _isScanLoading = true;
      _scanResult = null;
    });

    try {
      final bytes = await File(path).readAsBytes();
      
      final content = [
        Content.multi([
          DataPart('image/jpeg', bytes),
          TextPart(
              'Kamu adalah Pemandu Wisata Digital Medan yang ahli. Identifikasi tempat ini. Jika landmark/wisata Medan, sebutkan: 1. Nama Tempat, 2. Sejarah Singkat (2-3 kalimat), 3. Tips menarik buat pengunjung. Jika bukan wisata, identifikasi saja dengan ramah. Jawab dalam Bahasa Indonesia yang seru dan penuh emoji.'),
        ])
      ];

      final response = await _visionModel.generateContent(content);
      final result = response.text;

      if (result != null && mounted) {
        setState(() {
          _scanResult = result;
          _isScanLoading = false;
        });
      } else {
        throw Exception('No analysis result');
      }
    } catch (e) {
      debugPrint('DEBUG: Error Scan Analysis: $e');
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        _triggerCooldown();
        setState(() {
          _scanResult = '⚠️ Batas penggunaan (Quota) tercapai. AI sedang beristirahat 30 detik. Silakan coba sebentar lagi.';
          _isScanLoading = false;
        });
      } else {
        setState(() {
          _scanResult = '❌ Gagal menganalisis gambar. Silakan coba lagi.';
          _isScanLoading = false;
        });
      }
    }
  }

  void _triggerCooldown() {
    if (_isCooldown) return;
    setState(() {
      _isCooldown = true;
      _arLabel = '⏳ AI sedang beristirahat...';
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isCooldown = false;
          _arLabel = null;
        });
      }
    });
  }

  void _resetScan() {
    setState(() {
      _capturedImagePath = null;
      _scanResult = null;
      _isScanLoading = false;
    });
  }

  // ── Chat helpers ──────────────────────────────────────────────────────────────

  String? _findAnswer(String input) {
    final lower = input.toLowerCase();
    for (final key in _answerBank.keys) {
      if (lower.contains(key)) return _answerBank[key];
    }
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _textController.clear();
    _scrollToBottom();

    final bankAnswer = _findAnswer(text);
    if (bankAnswer != null) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'bot', 'text': bankAnswer});
        _isTyping = false;
      });
      _scrollToBottom();
      _saveChatHistory(text, bankAnswer);
      return;
    }

    try {
      final content = [Content.text('Kamu adalah MedanBot asisten wisata Medan. Jawab singkat dalam Bahasa Indonesia dengan emoji. Pertanyaan: $text')];
      final response = await _chatModel.generateContent(content);
      final botReply = response.text;

      if (botReply != null && mounted) {
        setState(() {
          _messages.add({'role': 'bot', 'text': botReply});
          _isTyping = false;
        });
        _scrollToBottom();
        _saveChatHistory(text, botReply);
      } else {
        throw Exception('No reply from bot');
      }
    } catch (e) {
      debugPrint('DEBUG: Error Chat: $e');
      const fallback =
          '🤔 Maaf, saya belum punya informasi tentang itu. Coba tanyakan tentang destinasi wisata, kuliner, hotel, atau transportasi di Medan ya! 😊';
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'bot', 'text': fallback});
        _isTyping = false;
      });
      _scrollToBottom();
      _saveChatHistory(text, fallback);
    }
  }

  Future<void> _saveChatHistory(String pesan, String balasan) async {
    try {
      await Supabase.instance.client.from('chat_history').insert({
        'pesan': pesan,
        'balasan': balasan,
        'role': 'user',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    } catch (_) {}
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (widget.onBackPressed != null) {
          widget.onBackPressed!();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: _selectedTab == 0
                    ? _buildCameraTab()
                    : _buildChatPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Bar (2 tab) ───────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _tabItem(Icons.camera_alt_outlined, 'Scan / AR', 0)),
          Expanded(child: _tabItem(Icons.chat_bubble_outline, 'Chat AI', 1)),
        ],
      ),
    );
  }

  Widget _tabItem(IconData icon, String label, int index) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? AppColors.primary : Colors.grey),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: active ? AppColors.primary : Colors.grey,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Camera Tab (AR + Scan) ────────────────────────────────────────────────────

  Widget _buildCameraTab() {
    // Show result screen after scan
    if (_capturedImagePath != null) {
      return _buildScanResultView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Live camera preview fills screen
        _buildCameraPreview(),

        // ── AR Mode overlay: clean, no corners, no text ──
        if (_isARMode) ...[
          // Subtle vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.transparent, Colors.black.withAlpha(80)],
              ),
            ),
          ),
          
          // AR Floating Label (Automatic Object Detection)
          if (_arLabel != null && _arLabel!.isNotEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      _arLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.location_on, color: Colors.white, size: 24),
                ],
              ),
            ),

          // Mode badge top left
          Positioned(
            top: 16,
            left: 16,
            child: _hudBadge(Icons.view_in_ar, 'AR MODE', Colors.greenAccent),
          ),
          
          // Debug info or scan status
          if (_isARDetecting)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Center(
                child: Text('AI sedang menganalisis...', 
                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 10)),
              ),
            ),
        ],

        // ── Scan Mode overlay: QRIS-style ──
        if (!_isARMode) ...[
          // Dark overlay with transparent scan window
          _buildScanOverlay(),
          // Mode badge top left
          Positioned(
            top: 16,
            left: 16,
            child: _hudBadge(Icons.qr_code_scanner, 'SCAN MODE', Colors.amberAccent),
          ),
        ],

        // ── Bottom controls ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomControls(),
        ),
      ],
    );
  }

  Widget _hudBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(160),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('AR Mode', _isARMode),
          _toggleBtn('Scan Mode', !_isARMode),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isARMode = label == 'AR Mode';
          if (_isARMode) {
            _startARDetection();
          } else {
            _stopARDetection();
            _arLabel = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white60,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Scan overlay: dark edges + transparent center box (QRIS style)
  Widget _buildScanOverlay() {
    return LayoutBuilder(builder: (context, constraints) {
      const boxSize = 240.0;
      final cx = constraints.maxWidth / 2;
      final cy = constraints.maxHeight / 2;
      final left = cx - boxSize / 2;
      final top = cy - boxSize / 2 - 40;

      return CustomPaint(
        painter: _ScanOverlayPainter(
          scanRect: Rect.fromLTWH(left, top, boxSize, boxSize),
        ),
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        ),
      );
    });
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withAlpha(200), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Mode Toggle (AR / Scan) — bottom ──
          _buildModeToggle(),

          const SizedBox(height: 20),

          // ── Shutter row (Only in Scan mode) ──
          if (!_isARMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery button
                GestureDetector(
                  onTap: _pickFromGallery,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white38),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Galeri', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),

                // Shutter button (center)
                GestureDetector(
                  onTap: _captureAndAnalyze,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 4,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),

                // Spacer to balance layout
                const SizedBox(width: 80),
              ],
            ),
          
          if (_isARMode)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Auto AR Detection Active 🟢',
                style: TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  // ── Scan result view ──────────────────────────────────────────────────────────

  Widget _buildScanResultView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Captured image
          Stack(
            children: [
              ClipRRect(
                child: Image.file(
                  File(_capturedImagePath!),
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: _resetScan,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _isScanLoading
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 14),
                        Text(
                          'AI sedang menganalisis foto...',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Hasil Identifikasi AI',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Text(
                          _scanResult ?? '',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetScan,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Scan Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat page ─────────────────────────────────────────────────────────────────

  Widget _buildChatPage() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildBubble(_messages[index]);
              },
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    'Tempat terdekat',
                    'Sejarah Medan',
                    'Rekomendasi',
                    'Hotel terbaik',
                  ].map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(chip,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.primary)),
                          onPressed: () => _sendMessage(chip),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.primary),
                          visualDensity: VisualDensity.compact,
                        ),
                      )).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        decoration: InputDecoration(
                          hintText: 'Tanyakan sesuatu...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _sendMessage(_textController.text),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight:
                isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Text(
          message['text'] ?? '',
          style: TextStyle(
              color: isUser ? Colors.white : Colors.black87, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('MedanBot sedang mengetik',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

/// Dark overlay with transparent scan window + green corner brackets
class _ScanOverlayPainter extends CustomPainter {
  final Rect scanRect;
  const _ScanOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withAlpha(140);

    // Draw 4 dark rectangles around scan window
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, scanRect.top), darkPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, scanRect.top, scanRect.left, scanRect.height), darkPaint);
    canvas.drawRect(
        Rect.fromLTWH(scanRect.right, scanRect.top,
            size.width - scanRect.right, scanRect.height),
        darkPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, scanRect.bottom, size.width, size.height - scanRect.bottom),
        darkPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;

    void drawCorner(Offset topLeft, bool flipX, bool flipY) {
      final dx = flipX ? -len : len;
      final dy = flipY ? -len : len;
      canvas.drawLine(topLeft, topLeft.translate(dx, 0), cornerPaint);
      canvas.drawLine(topLeft, topLeft.translate(0, dy), cornerPaint);
    }

    drawCorner(scanRect.topLeft, false, false);
    drawCorner(scanRect.topRight, true, false);
    drawCorner(scanRect.bottomLeft, false, true);
    drawCorner(scanRect.bottomRight, true, true);

    // Scan line
    final linePaint = Paint()
      ..color = const Color(0xFF2ECC71).withAlpha(200)
      ..strokeWidth = 1.5;
    final midY = scanRect.top + scanRect.height / 2;
    canvas.drawLine(
        Offset(scanRect.left + 8, midY), Offset(scanRect.right - 8, midY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter old) => old.scanRect != scanRect;
}
