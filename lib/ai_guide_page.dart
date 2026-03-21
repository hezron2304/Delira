import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';

class AIGuidePage extends StatefulWidget {
  const AIGuidePage({super.key});

  @override
  State<AIGuidePage> createState() => _AIGuidePageState();
}

class _AIGuidePageState extends State<AIGuidePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isARMode = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildScanARView(),
              _buildChatAIView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 24),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 20),
                SizedBox(width: 8),
                Text('Scan / AR', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 20),
                SizedBox(width: 8),
                Text('Chat AI', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: Colors.pinkAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isARMode ? 'AR Mode' : 'Scan Mode',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // Scanning Markers (Center)
              Positioned.fill(
                child: Center(
                  child: Container(
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
                                BoxShadow(color: AppColors.primary.withAlpha(120), blurRadius: 10, spreadRadius: 2),
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
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Masjid bersejarah yang dibangun tahun 1906 dengan arsitektur perpaduan Timur Tengah dan Eropa.',
                        style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
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
                  BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withAlpha(20), width: 1),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Hint Text
          const Text(
            'Arahkan ke objek atau marker wisata',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
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
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight 
                ? const BorderSide(color: AppColors.primary, width: 4) 
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight 
                ? const BorderSide(color: AppColors.primary, width: 4) 
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft 
                ? const BorderSide(color: AppColors.primary, width: 4) 
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight 
                ? const BorderSide(color: AppColors.primary, width: 4) 
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildChatAIView() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildAIMessage('Halo! Saya MedanBot 🤖 Arahkan kamera ke objek bersejarah atau tanyakan apapun tentang Medan!', '10:30'),
                _buildUserMessage('Scan ini bangunan apa?', '10:31'),
                _buildAIMessage('📷 Masjid Raya Al-Mashun terdeteksi! Dibangun 1906 oleh Sultan Ma\'mun Al-Rasyid. Masjid ini merupakan perpaduan arsitektur Timur Tengah, India, dan Spanyol.', '10:31'),
                _buildUserMessage('Apakah barang antik di sana berharga?', '10:32'),
              ],
            ),
          ),
          
          // Quick Action Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildActionChip('Tempat terdekat'),
                const SizedBox(width: 12),
                _buildActionChip('Sejarah Medan'),
                const SizedBox(width: 12),
                _buildActionChip('Rekomendasi'),
              ],
            ),
          ),
          
          // Input Field
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Tanyakan sesuatu...',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.send_outlined, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMessage(String message, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F3),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildUserMessage(String message, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 250),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
