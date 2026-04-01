import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class DetectedObject {
  final String name;
  final String description;
  final double x; // Percent 0-100
  final double y; // Percent 0-100

  DetectedObject({
    required this.name,
    required this.description,
    required this.x,
    required this.y,
  });

  factory DetectedObject.fromJson(Map<String, dynamic> json) {
    return DetectedObject(
      name: json['name'] ?? 'Objek',
      description: json['description'] ?? '',
      x: (json['x'] ?? 50).toDouble(),
      y: (json['y'] ?? 50).toDouble(),
    );
  }
}

class AIGuidePage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onHotelRequested;
  const AIGuidePage({super.key, this.onBackPressed, this.onHotelRequested});

  @override
  State<AIGuidePage> createState() => _AIGuidePageState();
}

class _AIGuidePageState extends State<AIGuidePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // ── Tab & mode state ────────────────────────────────────────────────────────
  int _selectedTab = 0; // 0 = Scan/AR, 1 = Chat AI
  bool _isARMode = true; // true = AR, false = Scan

  // ── Camera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // ── AR Gemini Vision ────────────────────────────────────────────────────────
  List<DetectedObject> _arObjects = [];
  bool _isARDetecting = false;
  bool _isAiSpeaking = false; // Track if AI is talking
  bool _isWaitingForUser = false; // Show "Scan Again" button
  late FlutterTts _flutterTts;

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

  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;

  // Animation for Scanning Effect
  late AnimationController _scanAnimController;
  late Animation<double> _scanAnimation;

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
    _visionModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _geminiApiKey,
    );
    _chatModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _geminiApiKey,
    );

    _messages.add({
      'role': 'bot',
      'text':
          'Halo! 👋 Saya MedanBot, asisten wisata Kota Medan. Ada yang bisa saya bantu? 🗺️',
    });
    _initTTS();
    _initSTT();
    _initScannerAnimation();
    _initCamera();
  }

  void _initScannerAnimation() {
    _scanAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimController, curve: Curves.easeInOut),
    );
    _scanAnimController.repeat(reverse: true);
  }

  Future<void> _initSTT() async {
    _speechToText = stt.SpeechToText();
    try {
      _speechEnabled = await _speechToText.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    await _speechToText.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _textController.text = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
            }
          });
        }
      },
      localeId: 'id-ID',
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _initTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("id-ID");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    // Track speech completion
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isAiSpeaking = false;
          _isWaitingForUser = true;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isAiSpeaking = false;
          _isWaitingForUser = true;
        });
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.stop();
    setState(() {
      _isAiSpeaking = true;
      _isWaitingForUser = false;
    });
    await _flutterTts.speak(text);
  }

  Future<void> _performARScan() async {
    if (!_isARMode || !_cameraReady || _cameraController == null) return;
    if (_isARDetecting || !_cameraController!.value.isInitialized) return;

    debugPrint('DEBUG: Memulai Deteksi AR Tunggal...');
    setState(() {
      _isARDetecting = true;
      _isWaitingForUser = false;
    });

    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await File(file.path).readAsBytes();

      if (_isCooldown) {
        debugPrint('DEBUG: AI sedang Cooldown, skip deteksi AR.');
        return;
      }

      final content = [
        Content.multi([
          DataPart('image/jpeg', bytes),
          TextPart(
            'Identifikasi objek utama (bangunan, fasilitas, atau benda unik). '
            'Respon HANYA format JSON list: [{"name": "..", "description": "..", "x": 1-100, "y": 1-100}]. '
            'PENTING: Gunakan bahasa yang sesuai konteks (ID/EN). '
            'Persona: Delira (santai & bersahabat). Tanpa emoji. Maks 2 objek.',
          ),
        ]),
      ];

      final response = await _visionModel.generateContent(content);
      final jsonText = response.text;

      debugPrint('DEBUG: Terdeteksi: $jsonText');
      if (jsonText != null && jsonText.isNotEmpty && mounted) {
        try {
          String jsonStr = jsonText.trim();
          final RegExp jsonRegex = RegExp(r'\[.*\]', dotAll: true);
          final match = jsonRegex.stringMatch(jsonStr);
          if (match == null) throw Exception('Invalid JSON format');

          final List<dynamic> list = json.decode(match);
          final List<DetectedObject> newObjects =
              list.map((item) => DetectedObject.fromJson(item)).toList();

          setState(() => _arObjects = newObjects);

          if (newObjects.isNotEmpty) {
            // Concatenate all objects info so AI speaks everything automatically
            final fullNarration = newObjects.map((obj) => "${obj.name}. ${obj.description}").join(" ");
            
            // Wait a tiny bit for the camera UI to settle before speaking
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _speak(fullNarration);
            });
            
            // Upload image to Supabase Storage
            String? imageUrl;
            try {
              imageUrl = await _uploadScanImage(file.path);
            } catch (e) {
              debugPrint('DEBUG: Error uploading AR image: $e');
            }

            // Record the most important scan (the first one) to history
            final first = newObjects.first;
            _recordScan(
              first.name.length > 50
                  ? '${first.name.substring(0, 47)}...'
                  : first.name,
              first.description,
              imageUrl,
            );
          } else {
            // No objects found, let user try again immediately
            setState(() => _isWaitingForUser = true);
          }
        } catch (e) {
          debugPrint('DEBUG: Error parsing AR JSON: $e');
          setState(() => _isWaitingForUser = true);
        }
      } else {
        setState(() => _isWaitingForUser = true);
      }
    } catch (e) {
      debugPrint('DEBUG: Error Deteksi AR: $e');
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        _triggerCooldown();
      } else {
        setState(() => _isWaitingForUser = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isARDetecting = false);
      }
    }
  }

  void _stopARDetection() {
    // Just a stub now as there is no timer
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
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
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
      if (_isARMode) _performARScan();
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
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    _scanAnimController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  // ── Camera widget ─────────────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return SizedBox.expand(child: CameraPreview(_cameraController!));
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Menyiapkan kamera...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
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
            'Identifikasi foto ini dengan santai dan bersahabat sebagai Delira. '
            'Jika WISATA: Sebut Nama, Deskripsi menarik, Hotel Terdekat & Harga, Tips Navigasi. '
            'Jika BUDAYA: Sebut Nama, Asal, Harga, Tempat Beli. '
            'PENTING: Gunakan bahasa yang sesuai dengan konteks (ID/EN). Respon harus ramah tanpa emoji.',
          ),
        ]),
      ];

      final response = await _visionModel.generateContent(content);
      final result = response.text;

      if (result != null && mounted) {
        setState(() {
          _scanResult = result;
          _isScanLoading = false;
        });

        // Speak the result automatically
        _speak(result);

        // Upload image to Supabase Storage
        String? imageUrl;
        if (_capturedImagePath != null) {
          try {
            imageUrl = await _uploadScanImage(_capturedImagePath!);
          } catch (e) {
            debugPrint('DEBUG: Error uploading Scan image: $e');
          }
        }

        // Record manual scan to history
        final scanName =
            result.split('\n').first.replaceAll(RegExp(r'[*#_]'), '').trim();
        _recordScan(
          scanName.length > 50 ? '${scanName.substring(0, 47)}...' : scanName,
          result,
          imageUrl,
        );
      } else {
        throw Exception('No analysis result');
      }
    } catch (e) {
      debugPrint('DEBUG: Error Scan Analysis: $e');
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        _triggerCooldown();
        setState(() {
          _scanResult =
              '⚠️ Batas penggunaan (Quota) tercapai. AI sedang beristirahat 30 detik. Silakan coba sebentar lagi.';
          _isScanLoading = false;
        });
      } else {
        setState(() {
          _scanResult = '❌ Gagal: $e';
          _isScanLoading = false;
        });
      }
    }
  }

  void _triggerCooldown() {
    if (_isCooldown) return;
    setState(() {
      _isCooldown = true;
      _arObjects = [
        DetectedObject(
          name: "Sistem AI Beristirahat",
          description:
              "AI sedang beristirahat sejenak untuk mendinginkan mesin.",
          x: 50,
          y: 50,
        ),
      ];
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isCooldown = false;
          _arObjects = [];
        });
      }
    });
  }

  void _resetScan() {
    _flutterTts.stop(); // Stop speaking when closing result
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

    // Check connection or basic validation
    bool isLikelyOffline = false;
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        isLikelyOffline = true;
      }
    } catch (_) {
      isLikelyOffline = true;
    }

    if (isLikelyOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koneksi internet tidak stabil. Coba lagi.'),
          backgroundColor: Colors.orange,
        ),
      );
    }

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
      final content = [
        Content.text(
          'Kamu adalah MedanBot asisten wisata Medan. Jawab secara informatif dalam Bahasa Indonesia. JANGAN gunakan emoji. Pertanyaan: $text',
        ),
      ];
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
      String errorMsg =
          '🤔 Maaf, saya sedang gangguan sebentar. Coba tanyakan lagi ya!';

      if (e.toString().contains('429') || e.toString().contains('quota')) {
        errorMsg =
            '⚠️ Wah, saya lagi ramai pengunjung! Beri saya waktu 30 detik untuk istirahat ya. 🙏';
        _triggerCooldown();
      }

      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'bot', 'text': errorMsg});
        _isTyping = false;
      });
      _scrollToBottom();
      _saveChatHistory(text, 'ERROR: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delira Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEmojiPicker() {
    final List<String> travelEmojis = [
      '🗺️',
      '📍',
      '🕌',
      '🏰',
      '⛪',
      '🍜',
      '🍲',
      '☕',
      '🍰',
      '🏨',
      '🚗',
      '✈️',
      '🏝️',
      '🎒',
      '📸',
      '🚌',
      '🛵',
      '🎟️',
      '🛍️',
      '💰',
      '⭐',
      '✅',
      '❤️',
      '👋',
      '😊',
      '😍',
      '🙌',
      '🙏',
      '✨',
      '🔥',
      ' Medan ',
      ' Kuliner ',
      ' Wisata ',
      ' Hotel ',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Emoji atau Kata Kunci',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: travelEmojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _textController.text += travelEmojis[index];
                          // Move cursor to end
                          _textController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: _textController.text.length),
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          travelEmojis[index],
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

  Future<String?> _uploadScanImage(String localPath) async {
    try {
      debugPrint('DEBUG: Attempting to upload image from: $localPath');
      final file = File(localPath);
      if (!file.existsSync()) {
        debugPrint('DEBUG: local file does not exist at $localPath');
        return null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'scans/$fileName';

      await Supabase.instance.client.storage
          .from('gambar_riwayat')
          .upload(path, file);

      final String publicUrl = Supabase.instance.client.storage
          .from('gambar_riwayat')
          .getPublicUrl(path);

      debugPrint('DEBUG: Upload success! URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('DEBUG: Upload to Supabase Storage FAILED: $e');
      return null;
    }
  }

  Future<void> _recordScan(String objectName, String description, String? imageUrl) async {
    final cleanName = objectName.trim();
    if (cleanName.isEmpty) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('DEBUG: Skip _recordScan because user is not logged in.');
        return;
      }

      debugPrint('DEBUG: Inserting record - Name: $cleanName, Desc Length: ${description.length}, Image: ${imageUrl != null ? 'Yes' : 'No'}');
      
      await Supabase.instance.client.from('riwayat_scan').insert({
        'user_id': user.id,
        'nama_objek': cleanName,
        'deskripsi_hasil': description,
        'foto_scan_url': imageUrl,
        'waktu_scan': DateTime.now().toIso8601String(),
      });
      debugPrint('DEBUG: Success recording scan for object: $cleanName');
    } catch (e) {
      debugPrint('DEBUG: Error recording scan ($cleanName). Detailed error: $e');
      // No snackbar here as it could be called frequently in AR mode
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
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
            bottom: false, // Konsisten Edge-to-Edge: Konten mentok sampai bawah
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: _selectedTab == 0 ? _buildCameraTab() : _buildChatPage(),
                ),
              ],
            ),
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
          Expanded(
            child: _tabItem(Icons.camera_alt_outlined, 'Scan / AR', 0),
          ),
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
            Icon(
              icon,
              size: 15,
              color: active ? AppColors.primary : Colors.grey,
            ),
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

          // AR Floating Markers (Multiple Objects)
          ..._arObjects.map((obj) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final xPos = (obj.x / 100) * screenWidth;
            final yPosRaw = (obj.y / 100) * screenHeight;
            final yPos = yPosRaw > screenHeight * 0.60
                ? screenHeight * 0.60
                : yPosRaw;

            return Positioned(
              left: xPos - 80,
              top: yPos - 60,
              child: SizedBox(
                width: 160,
                child: GestureDetector(
                  onTap: () {
                    _speak("${obj.name}. ${obj.description}");
                    _recordScan(obj.name, obj.description, null);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(225),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(60),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              obj.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              obj.description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // High-Tech Scanning Animation
          if (_isARDetecting) _buildScanningLaser(),

          // Mode badge top left
          Positioned(
            top: 16,
            left: 16,
            child: _hudBadge(Icons.view_in_ar, 'AR MODE', Colors.greenAccent),
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
            child: _hudBadge(
              Icons.qr_code_scanner,
              'SCAN MODE',
              Colors.amberAccent,
            ),
          ),
        ],

        // ── Bottom controls ──
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomControls()),
      ],
    );
  }

  Widget _hudBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(20),
        // REMOVED border to match the clean look requested
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
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
            _performARScan();
          } else {
            _arObjects = [];
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
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            const boxSize = 240.0;
            final cx = constraints.maxWidth / 2;
            final cy = constraints.maxHeight / 2;
            final left = cx - boxSize / 2;
            final top = cy - boxSize / 2 - 40;

            return CustomPaint(
              painter: _ScanOverlayPainter(
                scanRect: Rect.fromLTWH(left, top, boxSize, boxSize),
                animationValue: _scanAnimation.value,
              ),
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 20), // Reduced "floating" gap from 60 to 20
        // REMOVED: BoxDecoration with background, radius and shadow to make it borderless/transparent as requested
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Mode Toggle (AR / Scan) — bottom ──
          _buildModeToggle(),

          // ── AR Interaction Button (Moved from Center) ──
          if (_isWaitingForUser && !_isARDetecting && !_isAiSpeaking && _isARMode)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _performARScan,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, color: Colors.white, size: 18),
                          SizedBox(width: 10),
                          Text(
                            'Pindai Sekeliling Lagi',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Geser kamera lalu klik pindai',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),

          if (_isARDetecting && _isARMode)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'AI sedang menganalisis...',
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(80), // Switched to primary green for color harmony
                      borderRadius: BorderRadius.circular(30),
                      // REMOVED: border: Border.all(color: Colors.white38),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Galeri',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
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
                      color: AppColors.primary.withAlpha(40), // Subtle green outer ring
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary, // Solid green inner button
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),

                // Spacer to balance layout
                const SizedBox(width: 80),
              ],
            ),
        ],
      ),
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
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
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
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
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
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColors.primary,
                                size: 18,
                              ),
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
                        if (_scanResult != null &&
                            (_scanResult!.toLowerCase().contains('hotel') ||
                                _scanResult!.toLowerCase().contains('wisata') ||
                                _scanResult!.toLowerCase().contains(
                                  'landmark',
                                )))
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: widget.onHotelRequested,
                                icon: const Icon(
                                  Icons.hotel_outlined,
                                  size: 18,
                                ),
                                label: const Text('Cek Hotel Terdekat'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_scanResult != null &&
                            (_scanResult!.toLowerCase().contains('budaya') ||
                                _scanResult!.toLowerCase().contains(
                                  'kerajinan',
                                ) ||
                                _scanResult!.toLowerCase().contains(
                                  'oleh-oleh',
                                )))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Dukung Pengrajin Lokal',
                                      ),
                                      content: const Text(
                                        'Terima kasih! Dengan membeli produk ini, Anda turut melestarikan budaya Medan dan mendukung ekonomi pengrajin lokal. ❤️',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Tutup'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.favorite_border,
                                  size: 18,
                                ),
                                label: const Text('Dukung Produk Lokal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.pinkAccent.shade100,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
          color: const Color(0xFFF8F9FA), // Latar belakang abu-abu sangat muda
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.only(bottom: 32), // Lebar penuh (margin 0 di samping), melayang 32px dari bawah
              padding: const EdgeInsets.symmetric(horizontal: 4), // Padding kecil agar box tidak terlalu kaku
              decoration: BoxDecoration(
                color: Colors.white,
                // Border radius hanya di atas atau sedikit di semua sudut agar tetap terlihat modern
                borderRadius: BorderRadius.circular(16), 
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chips di dalam box tapi dengan padding sangat kecil agar tidak boros tempat
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        'Tempat terdekat',
                        'Sejarah Medan',
                        'Rekomendasi',
                        'Hotel terbaik',
                      ].map((chip) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(
                                chip,
                                style: const TextStyle(
                                  fontSize: 10, // Ukuran teks chip lebih kecil agar efisien
                                  color: AppColors.primary,
                                ),
                              ),
                              onPressed: () => _sendMessage(chip),
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.primary, width: 0.5),
                              visualDensity: VisualDensity.compact,
                            ),
                          ))
                          .toList(),
                    ),
                  ),
                  // Input Bar
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 4 : 4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (val) => _sendMessage(val),
                              decoration: InputDecoration(
                                hintText: _isListening ? 'Mendengarkan...' : 'Tanyakan sesuatu...',
                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                prefixIcon: IconButton(
                                  icon: const Icon(Icons.insert_emoticon_outlined, size: 20, color: Colors.grey),
                                  onPressed: _showEmojiPicker,
                                ),
                                suffixIcon: _speechEnabled
                                    ? IconButton(
                                        icon: Icon(
                                          _isListening ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                                          color: _isListening ? Colors.redAccent : Colors.grey[600],
                                          size: 22,
                                        ),
                                        onPressed: _isListening ? _stopListening : _startListening,
                                      )
                                    : null,
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _sendMessage(_textController.text),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Text(
          message['text'] ?? '',
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
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
            const Text(
              'MedanBot sedang mengetik',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningLaser() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top:
              MediaQuery.of(context).size.height * 0.2 +
              (MediaQuery.of(context).size.height * 0.4 * _scanAnimation.value),
          left: MediaQuery.of(context).size.width * 0.1,
          right: MediaQuery.of(context).size.width * 0.1,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withAlpha(150),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.cyanAccent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

/// Dark overlay with transparent scan window + green corner brackets
class _ScanOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final double animationValue;

  const _ScanOverlayPainter({
    required this.scanRect,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()..color = Colors.black.withAlpha(140);

    // Draw 4 dark rectangles around scan window
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, scanRect.top), darkPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, scanRect.top, scanRect.left, scanRect.height),
      darkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        scanRect.right,
        scanRect.top,
        size.width - scanRect.right,
        scanRect.height,
      ),
      darkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        scanRect.bottom,
        size.width,
        size.height - scanRect.bottom,
      ),
      darkPaint,
    );

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

    // Dynamic scan line
    final linePaint = Paint()
      ..color = const Color(0xFF2ECC71).withAlpha(200)
      ..strokeWidth = 2.0;

    final lineY = scanRect.top + (scanRect.height * animationValue);

    // Gradient glow for the moving line
    final glowPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2ECC71).withAlpha(0),
              const Color(0xFF2ECC71).withAlpha(100),
              const Color(0xFF2ECC71).withAlpha(0),
            ],
          ).createShader(
            Rect.fromLTWH(scanRect.left, lineY - 10, scanRect.width, 20),
          );

    canvas.drawRect(
      Rect.fromLTWH(scanRect.left + 4, lineY - 10, scanRect.width - 8, 20),
      glowPaint,
    );

    canvas.drawLine(
      Offset(scanRect.left + 8, lineY),
      Offset(scanRect.right - 8, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter old) =>
      old.scanRect != scanRect || old.animationValue != animationValue;
}
