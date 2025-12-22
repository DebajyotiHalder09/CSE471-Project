import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/gpay_service.dart';
import '../services/trip_history_service.dart';
import '../services/auth_service.dart';
import 'recharge.dart';

class GpayScreen extends StatefulWidget {
  final double balance;
  final String displayCode;
  final double? amount;
  final String? busName;
  final String? busCode;
  final String? source;
  final String? destination;
  final double? distance;
  final double? fare;
  final bool isBoarding;
  final String? busId;

  const GpayScreen({
    super.key,
    required this.balance,
    required this.displayCode,
    this.amount,
    this.busName,
    this.busCode,
    this.source,
    this.destination,
    this.distance,
    this.fare,
    this.isBoarding = false,
    this.busId,
  });

  @override
  State<GpayScreen> createState() => _GpayScreenState();
}

class _GpayScreenState extends State<GpayScreen> {
  bool _isProcessingPayment = false;

  Future<void> _processPayment() async {
    if (widget.amount == null) {
      _showInfo('No pending payment amount.');
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final result = await GpayService.deductFromGpay(widget.amount!);

      if (result['success']) {
        if (widget.isBoarding && widget.busId != null) {
          await _endTripAndCreateRecord();
        } else {
        await _createTripRecord();
        }
        _showPaymentSuccessDialog();
      } else {
        _showError(result['message'] ?? 'Payment failed');
      }
    } catch (e) {
      _showError('Payment failed: $e');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<void> _endTripAndCreateRecord() async {
    try {
      final token = await AuthService.getToken();
      if (token == null || widget.busId == null) return;

      // Call end-trip API first
      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/end-trip');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': widget.busId,
        }),
      );

      if (response.statusCode == 200) {
        // Then create trip record
        await _createTripRecord();
      }
    } catch (e) {
      print('Error ending trip: $e');
    }
  }

  Future<void> _createTripRecord() async {
    try {
      final result = await TripHistoryService.addTrip(
        busId: widget.busCode ?? 'unknown',
        busName: widget.busName ?? 'Unknown Bus',
        distance: widget.distance ?? 0.0,
        fare: widget.amount ?? 0.0,
        source: widget.source ?? 'Unknown',
        destination: widget.destination ?? 'Unknown',
      );

      if (result['success']) {
        print('Trip record created successfully from GPay payment');
      } else {
        print(
            'Failed to create trip record from GPay payment: ${result['message']}');
      }
    } catch (e) {
      print('Error creating trip record from GPay payment: $e');
    }
  }

  void _showReceiptModal(String formattedDate) {
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 500, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SmartCommute Dhaka',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Payment Receipt',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            'PAYMENT RECEIPT',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        SizedBox(height: 30),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildReceiptRowMultiline('Receipt Date:', formattedDate),
                              SizedBox(height: 12),
                              _buildReceiptRowMultiline('Transaction ID:', transactionId),
                              SizedBox(height: 12),
                              _buildReceiptRow('Bus Name:', widget.busName ?? '-', color: Colors.blue[700]),
                              SizedBox(height: 12),
                              _buildReceiptRow('Bus Code:', widget.busCode ?? '-', color: Colors.blue[700]),
                              SizedBox(height: 12),
                              _buildReceiptRow('Source:', widget.source ?? '-', color: Colors.green[700]),
                              SizedBox(height: 12),
                              _buildReceiptRow('Destination:', widget.destination ?? '-', color: Colors.red[700]),
                              SizedBox(height: 12),
                              _buildReceiptRow('Distance:', '${(widget.distance ?? 0).toStringAsFixed(1)} km', color: Colors.orange[700]),
                              SizedBox(height: 20),
                              Divider(color: Colors.grey[400], thickness: 2),
                              SizedBox(height: 20),
                              _buildReceiptRow('Total Fare:', '৳${(widget.fare ?? widget.amount ?? 0).toStringAsFixed(0)}', color: Colors.green[700], isTotal: true),
                              SizedBox(height: 12),
                              _buildReceiptRow('Payment Method:', 'Gpay'),
                              SizedBox(height: 12),
                              _buildReceiptRow('Status:', 'PAID', color: Colors.green[700]),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Divider(color: Colors.grey[400]),
                              SizedBox(height: 16),
                              Text(
                                'Thank you for using our service!',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'This is an official receipt for your bus journey.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer button
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? color, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRowMultiline(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  void _showPaymentSuccessDialog() {
    final currentDate = DateTime.now();
    final formattedDate =
        '${currentDate.day}/${currentDate.month}/${currentDate.year} at ${currentDate.hour}:${currentDate.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green[600],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Paid ৳${(widget.amount ?? 0).toStringAsFixed(0)} with Gpay',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReceiptModal(formattedDate),
                        icon: Icon(Icons.receipt_long),
                        label: Text('Show Receipt'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _createTripRecord();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Gpay',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
            SizedBox(height: 32),
            _buildAccountInfo(),
            SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.payment,
              size: 32,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Welcome to Gpay',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Fast, secure, and convenient payments',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet,
              size: 32,
              color: Colors.purple[600],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Account Balance',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            '৳${widget.balance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.purple[600],
            ),
          ),
          SizedBox(height: 20),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pin, color: Colors.grey[600], size: 20),
                SizedBox(width: 8),
                Text(
                  'PIN: ${widget.displayCode}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/recharge');
            },
            icon: Icon(Icons.add_circle_outline),
            label: Text(
              'Recharge',
              style: TextStyle(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isProcessingPayment ? null : _processPayment,
            icon: Icon(Icons.payment),
            label: Text(
              widget.amount != null
                  ? 'Pay ৳${widget.amount!.toStringAsFixed(0)}'
                  : 'Pay',
              style: TextStyle(fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[600],
              side: BorderSide(color: Colors.blue[600]!),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
