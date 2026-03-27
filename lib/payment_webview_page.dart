import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/payment_success_page.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String orderId;
  final String hotelName;
  final String roomType;
  final DateTime checkIn;
  final DateTime checkOut;
  final String guestName;
  final int totalAmount;
  final String email;

  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    required this.hotelName,
    required this.roomType,
    required this.checkIn,
    required this.checkOut,
    required this.guestName,
    required this.totalAmount,
    required this.email,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  StreamSubscription<List<Map<String, dynamic>>>? _bookingStreamSubscription;
  bool _isSuccessTriggered = false;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.paymentUrl));

    _startStreamListener();
  }

  void _startStreamListener() {
    _bookingStreamSubscription = Supabase.instance.client
        .schema('public')
        .from('booking')
        .stream(primaryKey: ['id'])
        .eq('kode_booking', widget.orderId.trim())
        .listen((data) async {
      if (data.isNotEmpty) {
        final status = data.first['status']?.toString().toLowerCase();
        if (status == 'paid' || status == 'completed') {
          if (!_isSuccessTriggered) {
            _isSuccessTriggered = true;
            _bookingStreamSubscription?.cancel();
            
            // Memberikan sedikit jeda animasi
            await Future.delayed(const Duration(milliseconds: 300));
            
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentSuccessPage(
                    hotelName: widget.hotelName,
                    roomType: widget.roomType,
                    checkIn: widget.checkIn,
                    checkOut: widget.checkOut,
                    orderId: widget.orderId,
                    guestName: widget.guestName,
                    totalAmount: widget.totalAmount,
                    email: widget.email,
                  ),
                ),
                (route) => route.isFirst,
              );
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _bookingStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran Pakasir', style: TextStyle(color: Colors.black, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
