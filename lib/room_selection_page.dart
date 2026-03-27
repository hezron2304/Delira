import 'package:flutter/material.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/checkout_page.dart';

class RoomSelectionPage extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final Map<String, dynamic>? selectedKamar;

  const RoomSelectionPage({
    super.key,
    required this.hotel,
    this.selectedKamar,
  });

  @override
  State<RoomSelectionPage> createState() => _RoomSelectionPageState();
}

class _RoomSelectionPageState extends State<RoomSelectionPage> {
  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 3));
  int _roomsCount = 1;
  int _adultsCount = 2;
  int _childrenCount = 0;

  // ----- Computed Helpers -----
  int get _nightCount => _checkOut.difference(_checkIn).inDays.abs().clamp(1, 365);

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String get _guestSummary =>
      '$_roomsCount Kamar, $_adultsCount Dewasa, $_childrenCount Anak';

  // ----- Room Data (from Supabase kamar join or dummy fallback) -----
  List<Map<String, dynamic>> get _rooms {
    final raw = widget.hotel['kamar'];
    if (raw is List && raw.isNotEmpty) {
      return List<Map<String, dynamic>>.from(raw).map((k) {
        final harga = int.tryParse(k['harga_per_malam'].toString()) ?? 0;
        final kamarId = k['id']?.toString() ?? '';
        final hargaFormatted = harga > 0
            ? harga.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')
            : '0';
        return {
          'id': kamarId,
          'name': k['tipe_kamar'] ?? 'Kamar',
          'price': 'Rp $hargaFormatted',
          'rawPrice': harga,
          'size': k['deskripsi'] ?? '',
          'bed': (k['fasilitas'] is List && (k['fasilitas'] as List).isNotEmpty) ? (k['fasilitas'] as List).first.toString() : 'Standard',
          'feature': 'WiFi',
          'left': int.tryParse(k['stok'].toString()) ?? 3,
          'tipe_kamar': k['tipe_kamar'] ?? 'Kamar',
          'harga_per_malam': harga,
          'foto_url': k['foto_url']?.toString() ?? '',
        };
      }).toList();
    }
    // Dummy fallback jika belum ada data
    return [
      {'name': 'Deluxe Double', 'price': 'Rp 850.000', 'rawPrice': 850000, 'size': '28 m²', 'bed': 'King Bed', 'feature': 'Bathtub', 'left': 3},
      {'name': 'Superior Twin', 'price': 'Rp 720.000', 'rawPrice': 720000, 'size': '24 m²', 'bed': 'Twin Bed', 'feature': 'Shower', 'left': 0},
    ];
  }

  // ================================================================
  //  DATE PICKER DIALOG
  // ================================================================
  void _openDatePicker() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => _DatePickerDialog(
        initialCheckIn: _checkIn,
        initialCheckOut: _checkOut,
        onConfirm: (ci, co) {
          setState(() {
            _checkIn = ci;
            _checkOut = co;
          });
        },
      ),
    );
  }

  // ================================================================
  //  GUEST PICKER DIALOG
  // ================================================================
  void _openGuestPicker() {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => _GuestPickerDialog(
        initialRooms: _roomsCount,
        initialAdults: _adultsCount,
        initialChildren: _childrenCount,
        onConfirm: (rooms, adults, children) {
          setState(() {
            _roomsCount = rooms;
            _adultsCount = adults;
            _childrenCount = children;
          });
        },
      ),
    );
  }

  // ================================================================
  //  BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Kamar',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
            Text(
              widget.hotel['nama'] ?? widget.hotel['name'] ?? 'Hotel',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.normal),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // ---- Summary Card ----
            _buildSummaryCard(),
            const SizedBox(height: 28),
            // ---- Room Cards ----
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rooms.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 20),
              itemBuilder: (context, index) =>
                  _buildRoomCard(_rooms[index]),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ---- Summary Card (Date Row + Guest Row) ----
  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Date Row
          InkWell(
            onTap: _openDatePicker,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tanggal Menginap',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _formatDate(_checkIn),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.swap_horiz,
                                  color: AppColors.textSecondary,
                                  size: 18),
                            ),
                            Flexible(
                              child: Text(
                                _formatDate(_checkOut),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_nightCount malam',
                      style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          // Guest Row
          InkWell(
            onTap: _openGuestPicker,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.people_alt_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tamu & Kamar',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          _guestSummary,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Room Card ----
  Widget _buildRoomCard(Map<String, dynamic> room) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          () {
            final fotoUrl = room['foto_url']?.toString() ?? '';
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19)),
              child: fotoUrl.isNotEmpty
                  ? Image.network(
                      fotoUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(Icons.hotel,
                              color: AppColors.primary, size: 48),
                        ),
                      ),
                    )
                  : Container(
                      height: 120,
                      color: AppColors.surface,
                      child: const Center(
                        child: Icon(Icons.hotel,
                            color: AppColors.primary, size: 48),
                      ),
                    ),
            );
          }(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        room['name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          room['price'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.primaryDark),
                        ),
                        const Text('/malam',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(room['size'],
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSmallChip(
                        Icons.hotel_outlined, room['bed']),
                    _buildSmallChip(
                        Icons.bathtub_outlined, room['feature']),
                    _buildSmallChip(Icons.wifi, 'WiFi'),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (room['left'] > 0)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: Text(
                            '${room['left']} kamar tersisa',
                            style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      )
                    else
                      const SizedBox(),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final rawPrice = (room['rawPrice'] as int?) ?? (() {
                          final s = room['price'] as String? ?? '';
                          return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                        })();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutPage(
                              hotelName: widget.hotel['nama'] ?? widget.hotel['name'] ?? 'Hotel',
                              roomType: room['tipe_kamar'] ?? room['name'] ?? 'Kamar',
                              roomPrice: rawPrice,
                              checkIn: _checkIn,
                              checkOut: _checkOut,
                              nights: _nightCount,
                              rooms: _roomsCount,
                              adults: _adultsCount,
                              children: _childrenCount,
                              hotelId: widget.hotel['id']?.toString() ?? '',
                              kamarId: room['id']?.toString() ?? '',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Pilih',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ================================================================
//  DATE PICKER DIALOG
// ================================================================
class _DatePickerDialog extends StatefulWidget {
  final DateTime initialCheckIn;
  final DateTime initialCheckOut;
  final void Function(DateTime checkIn, DateTime checkOut) onConfirm;

  const _DatePickerDialog({
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.onConfirm,
  });

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _checkIn;
  DateTime? _checkOut;
  late DateTime _displayMonth;

  // Selecting phase: 0 = picking check-in, 1 = picking check-out
  int _phase = 0;

  static const _weekLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _checkIn = widget.initialCheckIn;
    _checkOut = widget.initialCheckOut;
    _displayMonth = DateTime(_checkIn.year, _checkIn.month, 1);
  }

  String _formatFull(DateTime? d) {
    if (d == null) return 'Pilih tanggal';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  int get _nightCount => _checkOut == null ? 0 : _checkOut!.difference(_checkIn).inDays.abs().clamp(0, 365);

  void _onDayTap(DateTime day) {
    setState(() {
      if (_phase == 0) {
        // State 1: Selecting Check-In
        _checkIn = day;
        _checkOut = null;
        _phase = 1;
      } else {
        // State 2: Selecting Check-Out
        if (day.isAfter(_checkIn)) {
          _checkOut = day;
          _phase = 0;
        } else {
          // Tapped before or equal to check-in -> treat as new check-in
          _checkIn = day;
          _checkOut = null;
          _phase = 1;
        }
      }
    });
  }

  bool _isSameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime d) {
    if (_checkOut == null) return false;
    return d.isAfter(_checkIn) && d.isBefore(_checkOut!);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Calculate calendar grid
    // Week starts Monday (weekday 1). Dart: Mon=1 … Sun=7
    final firstDay = _displayMonth;
    final daysInMonth = DateUtils.getDaysInMonth(firstDay.year, firstDay.month);
    int startOffset = firstDay.weekday - 1; // 0 = Mon offset

    final List<DateTime?> calCells = [];
    for (int i = 0; i < startOffset; i++) { calCells.add(null); }
    for (int d = 1; d <= daysInMonth; d++) {
      calCells.add(DateTime(firstDay.year, firstDay.month, d));
    }
    // Pad to complete rows
    while (calCells.length % 7 != 0) { calCells.add(null); }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Tanggal Menginap',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
            ),

            // Month nav
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPrimary, size: 18),
                    onPressed: () => setState(() => _displayMonth =
                        DateTime(_displayMonth.year, _displayMonth.month - 1, 1)),
                  ),
                  Text(
                    '${_monthNames[_displayMonth.month]} ${_displayMonth.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios,
                        color: AppColors.textPrimary, size: 18),
                    onPressed: () => setState(() => _displayMonth =
                        DateTime(_displayMonth.year, _displayMonth.month + 1, 1)),
                  ),
                ],
              ),
            ),

            // Day-of-week headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _weekLabels
                    .map((lbl) => Expanded(
                          child: Center(
                            child: Text(lbl,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Calendar grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: calCells.length,
                  itemBuilder: (ctx, i) {
                    final day = calCells[i];
                    if (day == null) return const SizedBox();

                    final isCheckIn = _isSameDay(day, _checkIn);
                    final isCheckOut = _isSameDay(day, _checkOut);
                    final inRange = _isInRange(day);
                    final isToday = _isSameDay(day, today);
                    final isPast = day.isBefore(DateTime(today.year, today.month, today.day));

                    Color bgColor = Colors.transparent;
                    Color textColor = isPast
                        ? AppColors.textSecondary.withAlpha(100)
                        : AppColors.textPrimary;
                    FontWeight fw = FontWeight.normal;

                    if (isCheckIn || isCheckOut) {
                      bgColor = AppColors.primary;
                      textColor = Colors.white;
                      fw = FontWeight.bold;
                    } else if (inRange) {
                      bgColor = AppColors.primaryLight;
                      textColor = AppColors.primaryDark;
                    }

                    return GestureDetector(
                      onTap: isPast ? null : () => _onDayTap(day),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: fw,
                                    color: textColor),
                              ),
                              if (isToday && !isCheckIn && !isCheckOut)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: inRange
                                        ? AppColors.primaryDark
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Hari ini',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom Summary + Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 12,
                      offset: const Offset(0, -4))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDateSummaryBox(
                          'Check-in', _formatFull(_checkIn), false),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            const Icon(Icons.arrow_forward,
                                color: AppColors.textSecondary, size: 18),
                            Text(_checkOut == null ? '-' : '$_nightCount malam',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      _buildDateSummaryBox(
                          'Check-out', _formatFull(_checkOut), _checkOut == null),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _checkOut == null ? null : () {
                        widget.onConfirm(_checkIn, _checkOut!);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textSecondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Lanjutkan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSummaryBox(String label, String value, bool isGreyedOut) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isGreyedOut ? AppColors.textSecondary : AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ================================================================
//  GUEST PICKER DIALOG
// ================================================================
class _GuestPickerDialog extends StatefulWidget {
  final int initialRooms;
  final int initialAdults;
  final int initialChildren;
  final void Function(int rooms, int adults, int children) onConfirm;

  const _GuestPickerDialog({
    required this.initialRooms,
    required this.initialAdults,
    required this.initialChildren,
    required this.onConfirm,
  });

  @override
  State<_GuestPickerDialog> createState() => _GuestPickerDialogState();
}

class _GuestPickerDialogState extends State<_GuestPickerDialog> {
  late int _rooms;
  late int _adults;
  late int _children;

  @override
  void initState() {
    super.initState();
    _rooms = widget.initialRooms;
    _adults = widget.initialAdults;
    _children = widget.initialChildren;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Tambahkan Tamu & Kamar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Stepper rows
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildStepperRow(
                      icon: Icons.meeting_room_outlined,
                      label: 'Kamar',
                      subtitle: null,
                      value: _rooms,
                      onDecrement: () {
                        if (_rooms > 1) setState(() => _rooms--);
                      },
                      onIncrement: () =>
                          setState(() => _rooms = (_rooms + 1).clamp(1, 20)),
                    ),
                    const Divider(height: 32, color: AppColors.border),
                    _buildStepperRow(
                      icon: Icons.person_outline,
                      label: 'Dewasa',
                      subtitle: null,
                      value: _adults,
                      onDecrement: () {
                        if (_adults > 1) setState(() => _adults--);
                      },
                      onIncrement: () =>
                          setState(() => _adults = (_adults + 1).clamp(1, 20)),
                    ),
                    const Divider(height: 32, color: AppColors.border),
                    _buildStepperRow(
                      icon: Icons.child_care_outlined,
                      label: 'Anak',
                      subtitle: 'Maksimal 17 tahun',
                      value: _children,
                      onDecrement: () {
                        if (_children > 0) setState(() => _children--);
                      },
                      onIncrement: () =>
                          setState(() => _children = (_children + 1).clamp(0, 10)),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onConfirm(_rooms, _adults, _children);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Terapkan',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required String label,
    required String? subtitle,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ],
          ),
        ),
        // Stepper control
        Row(
          children: [
            _stepBtn(Icons.remove, onDecrement, value <= (label == 'Anak' ? 0 : 1)),
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  '$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary),
                ),
              ),
            ),
            _stepBtn(Icons.add, onIncrement, false),
          ],
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, bool disabled) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(
              color: disabled ? AppColors.border : AppColors.primary,
              width: 1.5),
          shape: BoxShape.circle,
          color: disabled ? AppColors.surface : Colors.white,
        ),
        child: Icon(icon,
            size: 18,
            color:
                disabled ? AppColors.textSecondary : AppColors.primary),
      ),
    );
  }
}
