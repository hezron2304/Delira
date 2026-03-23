import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AIGuidePage extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const AIGuidePage({super.key, this.onBackPressed});

  @override
  State<AIGuidePage> createState() => _AIGuidePageState();
}

class _AIGuidePageState extends State<AIGuidePage> {
  int _selectedTab = 1;
  bool _isARMode = true;

  static const String _geminiApiKey = 'AIzaSyBlhw6gDvdrMfd_tmwAf2UaZwdyQ3tDvIc';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent';

  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _answerBank = {
    // Tempat wisata
    'tempat terdekat': '📍 Destinasi terdekat di Medan: Masjid Raya Al-Mashun (2.3 km), Istana Maimun (2.5 km), dan Kesawan Square (3.1 km). Semua bisa ditempuh dalam 10-15 menit! 🗺️',
    'masjid raya': '🕌 Masjid Raya Al-Mashun dibangun tahun 1906 oleh Sultan Ma\'mun Al-Rasyid. Arsitekturnya memadukan gaya Timur Tengah, India, dan Spanyol. Buka setiap hari dan gratis untuk dikunjungi!',
    'istana maimun': '🏰 Istana Maimun dibangun tahun 1888 oleh Sultan Deli. Merupakan simbol kejayaan Kesultanan Melayu Deli. Tiket masuk Rp 5.000, buka 08.00-17.00 WIB.',
    'kesawan': '🏛️ Kesawan Square adalah kawasan bersejarah dengan bangunan kolonial Belanda abad ke-19. Cocok untuk wisata malam dan foto-foto! Buka 24 jam dan gratis.',
    'tjong a fie': '🏚️ Tjong A Fie Mansion dibangun tahun 1900 oleh saudagar Tionghoa legendaris. Kini menjadi museum dengan koleksi furnitur antik. Tiket Rp 35.000.',
    'gereja immanuel': '⛪ Gereja Immanuel Medan dibangun tahun 1921, salah satu gereja tertua di Medan. Arsitektur kolonial Belanda yang indah di pusat kota.',

    // Kuliner
    'kuliner': '🍜 Kuliner wajib coba di Medan: Soto Medan, Bika Ambon, Mie Gomak, Durian Ucok, dan Lemang. Jangan lupa coba Kopi Sidikalang yang legendaris! ☕',
    'bika ambon': '🍰 Bika Ambon adalah oleh-oleh khas Medan berbahan dasar kelapa dan telur. Pusat penjualannya ada di Jalan Mojopahit. Harga mulai Rp 40.000/kotak.',
    'durian': '🍈 Durian Ucok di Jalan Iskandar Muda adalah yang paling terkenal di Medan! Buka dari siang sampai malam. Harga mulai Rp 50.000/buah tergantung ukuran.',
    'soto medan': '🍲 Soto Medan berbeda dari soto lainnya karena kuahnya bersantan dan kaya rempah. Coba di Soto Kesawan atau Soto Hidayah yang legendaris!',
    'makan': '🍜 Rekomendasi kuliner Medan: Soto Medan (santan kaya rempah), Bika Ambon (oleh-oleh khas), Durian Ucok (durian premium), dan Mie Gomak (mie khas Batak)!',

    // Hotel
    'hotel': '🏨 Hotel terbaik di Medan: Grand Mercure Angkasa (bintang 5), Hotel Aryaduta (bintang 4), Novotel Medan (bintang 4). Pesan sekarang lewat fitur Hotel di app ini! 😊',
    'penginapan': '🏨 Pilihan penginapan di Medan mulai dari budget Rp 200rb/malam hingga hotel bintang 5 Rp 1 juta+/malam. Cek fitur Hotel di app ini untuk booking langsung!',

    // Transportasi
    'transportasi': '🚗 Transportasi di Medan: Grab/Gojek tersedia 24 jam, Angkot untuk rute tertentu, dan taksi Blue Bird. Untuk wisata keliling kota, sewa mobil mulai Rp 300rb/hari.',
    'dari bandara': '✈️ Dari Bandara Kualanamu ke pusat kota: Kereta Bandara (Rp 120rb, 45 menit), Grab/Gojek (Rp 80-150rb, 45-60 menit tergantung macet).',

    // Sejarah
    'sejarah medan': '📚 Medan berkembang pesat sejak abad ke-19 sebagai pusat perkebunan tembakau. Didirikan tahun 1886, Medan menjadi kota terbesar ketiga di Indonesia dengan sejarah multietnis yang kaya!',
    'sejarah': '📚 Medan didirikan tahun 1886 dan berkembang sebagai pusat perkebunan tembakau Deli. Perpaduan budaya Melayu, Batak, Tionghoa, dan kolonial Belanda membentuk karakter unik kota ini.',

    // Sapaan
    'halo': '👋 Halo! Selamat datang di MedanBot! Saya siap membantu kamu menjelajahi Kota Medan. Mau tanya tentang wisata, kuliner, hotel, atau transportasi? 😊',
    'hai': '👋 Hai! Ada yang bisa saya bantu tentang wisata Medan hari ini? 😊',
    'terima kasih': '😊 Sama-sama! Semoga perjalanan wisata kamu di Medan menyenangkan! Jangan ragu untuk bertanya lagi ya! 🗺️',
    'rekomendasi': '⭐ Rekomendasi top Medan: 1) Masjid Raya Al-Mashun 2) Istana Maimun 3) Kesawan Square 4) Tjong A Fie Mansion 5) Durian Ucok. Semuanya wajib dikunjungi! 🏆',
  };

  String? _findAnswer(String input) {
    final lower = input.toLowerCase();
    for (final key in _answerBank.keys) {
      if (lower.contains(key)) {
        return _answerBank[key];
      }
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

  @override
  void initState() {
    super.initState();

    _messages.add({
      'role': 'bot',
      'text':
          'Halo! 👋 Saya MedanBot, asisten wisata Kota Medan. Ada yang bisa saya bantu? 🗺️',
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

    // Step 1: Check answer bank first
    final bankAnswer = _findAnswer(text);
    if (bankAnswer != null) {
      await Future.delayed(const Duration(milliseconds: 800)); // natural delay
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'bot', 'text': bankAnswer});
        _isTyping = false;
      });
      _scrollToBottom();
      
      // Save to Supabase chat history
      await Supabase.instance.client.from('chat_history').insert({
        'pesan': text,
        'balasan': bankAnswer,
        'role': 'user',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      return;
    }

    // Step 2: Try Gemini API
    try {
      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [{'text': 'Kamu adalah MedanBot asisten wisata Medan. Jawab singkat dalam Bahasa Indonesia dengan emoji. Pertanyaan: $text'}]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 300,
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botReply = data['candidates'][0]['content']['parts'][0]['text'] as String;
        if (!mounted) return;
        setState(() {
          _messages.add({'role': 'bot', 'text': botReply});
          _isTyping = false;
        });
        _scrollToBottom();
        
        // Save to Supabase chat history
        await Supabase.instance.client.from('chat_history').insert({
          'pesan': text,
          'balasan': botReply,
          'role': 'user',
          'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
        });
      } else {
        throw Exception('API error: ${response.body}');
      }
    } catch (e) {
      // MedanBot fallback triggered: $e
      // Step 3: Default fallback answer
      if (!mounted) return;
      const fallbackReply = '🤔 Maaf, saya belum punya informasi tentang itu. Coba tanyakan tentang destinasi wisata, kuliner, hotel, atau transportasi di Medan ya! 😊';
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': fallbackReply
        });
        _isTyping = false;
      });
      _scrollToBottom();
      
      // Save fallback to Supabase chat history
      await Supabase.instance.client.from('chat_history').insert({
        'pesan': text,
        'balasan': fallbackReply,
        'role': 'user',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Tab bar
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  if (widget.onBackPressed != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1A6B4A)),
                      onPressed: widget.onBackPressed,
                    ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTab == 0 ? const Color(0xFF1A6B4A) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                              size: 16,
                              color: _selectedTab == 0 ? const Color(0xFF1A6B4A) : Colors.grey),
                            const SizedBox(width: 6),
                            Text('Scan / AR',
                              style: TextStyle(
                                color: _selectedTab == 0 ? const Color(0xFF1A6B4A) : Colors.grey,
                                fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                              )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _selectedTab == 1 ? const Color(0xFF1A6B4A) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                              size: 16,
                              color: _selectedTab == 1 ? const Color(0xFF1A6B4A) : Colors.grey),
                            const SizedBox(width: 6),
                            Text('Chat AI',
                              style: TextStyle(
                                color: _selectedTab == 1 ? const Color(0xFF1A6B4A) : Colors.grey,
                                fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                              )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: _selectedTab == 0
                ? _buildScanARView()
                : _buildChatPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanARView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Camera View Simulation Box
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 480,
                color: const Color(0xFF0F2E23),
              ),

              // Mode Badge (Top Left inside camera)
              Positioned(
                top: 24,
                left: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        color: Colors.pinkAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isARMode ? 'AR Mode' : 'Scan Mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Scanning Markers (Center)
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: Stack(
                      children: [
                        _buildCorner(Alignment.topLeft),
                        _buildCorner(Alignment.topRight),
                        _buildCorner(Alignment.bottomLeft),
                        _buildCorner(Alignment.bottomRight),

                        // Scanning Line
                        Center(
                          child: Container(
                            height: 2,
                            width: 220,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(200),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(120),
                                  blurRadius: 10,
                                  spreadRadius: 2,
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

              // Info Card (Bottom center inside camera)
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(200),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withAlpha(100)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Masjid Raya Al-Mashun',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Masjid bersejarah yang dibangun tahun 1906 dengan arsitektur perpaduan Timur Tengah dan Eropa.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Navigation Toggle (Below camera)
          _buildModeToggle(),

          const SizedBox(height: 32),

          // Capture Button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withAlpha(20),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Hint Text
          const Text(
            'Arahkan ke objek atau marker wisata',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 40), // Extra space for padding
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F3),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn('AR Mode', _isARMode),
          _buildToggleBtn('Scan Mode', !_isARMode),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _isARMode = label == 'AR Mode'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top:
                alignment == Alignment.topLeft ||
                    alignment == Alignment.topRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            bottom:
                alignment == Alignment.bottomLeft ||
                    alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            left:
                alignment == Alignment.topLeft ||
                    alignment == Alignment.bottomLeft
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
            right:
                alignment == Alignment.topRight ||
                    alignment == Alignment.bottomRight
                ? const BorderSide(color: AppColors.primary, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChatPage() {
    return Column(
      children: [
        // Messages
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
              // Quick chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: ['Tempat terdekat', 'Sejarah Medan', 'Rekomendasi', 'Hotel terbaik']
                    .map((chip) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(chip, style: const TextStyle(fontSize: 11, color: Color(0xFF1A6B4A))),
                        onPressed: () => _sendMessage(chip),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF1A6B4A)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )).toList(),
                ),
              ),
              // Input field
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
                          color: const Color(0xFF1A6B4A),
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1A6B4A) : const Color(0xFFF0F0F0),
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
        margin: const EdgeInsets.symmetric(vertical: 4),
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
                color: Color(0xFF1A6B4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
