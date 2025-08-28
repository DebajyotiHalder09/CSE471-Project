import 'package:flutter/material.dart';
import '../services/gpay_service.dart';
import '../services/receipt_service.dart';
import '../services/trip_history_service.dart';
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
        await _createTripRecord();
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
                        onPressed: () async {
                          try {
                            final path =
                                await ReceiptService.generateAndSaveReceipt(
                              busName: widget.busName ?? '-',
                              busCode: widget.busCode ?? '-',
                              source: widget.source ?? '-',
                              destination: widget.destination ?? '-',
                              distance: widget.distance ?? 0,
                              fare: widget.fare ?? (widget.amount ?? 0),
                              date: formattedDate,
                            );
                            await ReceiptService.openReceipt(path);
                          } catch (_) {}
                        },
                        icon: Icon(Icons.download),
                        label: Text('Download Receipt'),
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
