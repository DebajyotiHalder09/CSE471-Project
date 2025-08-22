import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bus.dart';
import '../models/individual_bus.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../services/receipt_service.dart';
import '../services/offers_service.dart';
import '../models/offers.dart';
import 'gpayreglog.dart';

class PayScreen extends StatefulWidget {
  final IndividualBus bus;
  final Bus busInfo;
  final String source;
  final String destination;
  final double distance;
  final double fare;

  const PayScreen({
    super.key,
    required this.bus,
    required this.busInfo,
    required this.source,
    required this.destination,
    required this.distance,
    required this.fare,
  });

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _isDownloadingReceipt = false;
  double _walletBalance = 0.0;
  int _gems = 0;
  String? _error;
  bool _insufficientBalance = false;
  Offers? _userOffers;
  double _discountAmount = 0.0;
  double _payableAmount = 0.0;
  bool _isLoadingOffers = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _loadUserOffers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await WalletService.getWalletBalance();
      if (result['success']) {
        setState(() {
          _walletBalance = result['balance'];
          _gems = result['gems'];
          _insufficientBalance = _walletBalance < _payableAmount;
        });
      } else {
        setState(() {
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load wallet data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshWalletData() async {
    await _loadWalletData();
  }

  Future<void> _loadUserOffers() async {
    try {
      setState(() {
        _isLoadingOffers = true;
      });

      final token = await AuthService.getToken();
      if (token == null) return;

      final offers = await OffersService.getUserOffers(token);
      setState(() {
        _userOffers = offers;
        _discountAmount = offers.discount ?? 0.0;
        _payableAmount = widget.fare - _discountAmount;
        if (_payableAmount < 0) _payableAmount = 0.0;
        _isLoadingOffers = false;
      });
    } catch (e) {
      setState(() {
        _userOffers = null;
        _discountAmount = 0.0;
        _payableAmount = widget.fare;
        _isLoadingOffers = false;
      });
    }
  }

  Future<void> _downloadReceipt() async {
    setState(() {
      _isDownloadingReceipt = true;
    });

    try {
      final currentDate = DateTime.now();
      final formattedDate =
          '${currentDate.day}/${currentDate.month}/${currentDate.year} at ${currentDate.hour}:${currentDate.minute.toString().padLeft(2, '0')}';

      final receiptPath = await ReceiptService.generateAndSaveReceipt(
        busName: widget.busInfo.busName,
        busCode: widget.bus.busCode,
        source: widget.source,
        destination: widget.destination,
        distance: widget.distance,
        fare: widget.fare,
        date: formattedDate,
      );

      final fileName = receiptPath.split('/').last;

      await ReceiptService.openReceipt(receiptPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Receipt downloaded successfully!'),
              Text(
                'File: $fileName',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download receipt: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isDownloadingReceipt = false;
      });
    }
  }

  Future<void> _processPayment() async {
    if (_insufficientBalance) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _showError('Authentication required');
        return;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/board');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': widget.bus.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final deductionResult = await _deductFare();
          if (deductionResult) {
            await _loadWalletData();
            await _applyDiscount();
            _showSuccessDialog();
          } else {
            _showError(
                'Payment processed but wallet deduction failed. Please contact support.');
          }
        } else {
          _showError(data['message'] ?? 'Failed to board bus');
        }
      } else {
        _showError('Failed to board bus');
      }
    } catch (e) {
      _showError('Error processing payment');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<void> _processPaymentWithWallet() async {
    if (_insufficientBalance) {
      _showInsufficientBalanceDialog();
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _showError('Authentication required');
        return;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/board');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': widget.bus.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final deductionResult = await _deductFare();
          if (deductionResult) {
            await _loadWalletData();
            await _applyDiscount();
            _showSuccessDialog();
          } else {
            _showError(
                'Payment processed but wallet deduction failed. Please contact support.');
          }
        } else {
          _showError(data['message'] ?? 'Failed to board bus');
        }
      } else {
        _showError('Failed to board bus');
      }
    } catch (e) {
      _showError('Error processing payment');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<void> _processPaymentWithGpay() async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _showError('Authentication required');
        return;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/individual-bus/board');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'busId': widget.bus.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          await _applyDiscount();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => GpayRegLogScreen(
                amount: _payableAmount,
                busName: widget.busInfo.busName,
                busCode: widget.bus.busCode,
                source: widget.source,
                destination: widget.destination,
                distance: widget.distance,
                fare: widget.fare,
              ),
            ),
          );
        } else {
          _showError(data['message'] ?? 'Failed to board bus');
        }
      } else {
        _showError('Failed to board bus');
      }
    } catch (e) {
      _showError('Error processing payment');
    } finally {
      setState(() {
        _isProcessingPayment = false;
      });
    }
  }

  Future<bool> _deductFare() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return false;

      final uri = Uri.parse('${AuthService.baseUrl}/wallet/deduct');
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': _payableAmount,
          'description': 'Bus fare for ${widget.busInfo.busName}',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            _walletBalance = (data['newBalance'] ?? _walletBalance).toDouble();
            _insufficientBalance = _walletBalance < _payableAmount;
          });
          return true;
        } else {
          _showError(data['message'] ?? 'Failed to deduct fare from wallet');
          return false;
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        if (data['message'] == 'Insufficient balance') {
          setState(() {
            _insufficientBalance = true;
          });
          _showError('Insufficient balance in wallet');
          return false;
        } else {
          _showError(data['message'] ?? 'Failed to deduct fare from wallet');
          return false;
        }
      } else {
        _showError('Failed to deduct fare from wallet');
        return false;
      }
    } catch (e) {
      _showError('Error deducting fare from wallet');
      return false;
    }
  }

  Future<void> _applyDiscount() async {
    if (_discountAmount <= 0 || _userOffers == null) return;

    try {
      final token = await AuthService.getToken();
      if (token == null) return;

      final result = await OffersService.useDiscount(token, _discountAmount);
      if (result['success'] != null) {
        setState(() {
          _discountAmount = 0.0;
          _payableAmount = widget.fare;
        });
      }
    } catch (e) {
      print('Error applying discount: $e');
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600], size: 28),
              SizedBox(width: 12),
              Text(
                'Insufficient Balance',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your current wallet balance is insufficient to pay for this trip.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.red[600]),
                    SizedBox(width: 8),
                    Text(
                      'Required: ৳${_payableAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.blue[600]),
                    SizedBox(width: 8),
                    Text(
                      'Available: ৳${_walletBalance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showTopUpOptions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Top Up Wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTopUpOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Top Up Options',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.account_balance, color: Colors.green[600]),
                title: Text('Bank Transfer'),
                subtitle: Text('Transfer from your bank account'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon('Bank Transfer');
                },
              ),
              ListTile(
                leading: Icon(Icons.credit_card, color: Colors.blue[600]),
                title: Text('Credit/Debit Card'),
                subtitle: Text('Pay with your card'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon('Credit/Debit Card');
                },
              ),
              ListTile(
                leading: Icon(Icons.mobile_friendly, color: Colors.orange[600]),
                title: Text('Mobile Banking'),
                subtitle: Text('bKash, Nagad, Rocket'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showComingSoon('Mobile Banking');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoon(String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$method payment method coming soon!'),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
                SizedBox(height: 20),
                Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'You have successfully boarded the bus',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Transaction Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Fare:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '৳${widget.fare.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (_discountAmount > 0) ...[
                        SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '-৳${_discountAmount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount Paid:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '৳${_payableAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Balance:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '৳${_walletBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isDownloadingReceipt ? null : _downloadReceipt,
                    icon: _isDownloadingReceipt
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.download, size: 20),
                    label: Text(
                      _isDownloadingReceipt
                          ? 'Generating Receipt...'
                          : 'Download Receipt (PDF)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDownloadingReceipt
                          ? Colors.grey[400]
                          : Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Payment',
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadWalletData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTripSummaryCard(),
                      SizedBox(height: 16),
                      _buildWalletCard(),
                      SizedBox(height: 16),
                      _buildPaymentButton(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: Colors.blue[600],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.busInfo.busName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    Text(
                      'Bus Code: ${widget.bus.busCode}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildInfoRow(
            Icons.location_on,
            'From',
            widget.source,
            Colors.green[600]!,
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            Icons.flag,
            'To',
            widget.destination,
            Colors.red[600]!,
          ),
          SizedBox(height: 16),
          Divider(height: 1),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  Icons.straighten,
                  'Distance',
                  '${widget.distance.toStringAsFixed(1)} km',
                  Colors.blue[600]!,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  Icons.payment,
                  'Total Fare',
                  '৳${widget.fare.toStringAsFixed(0)}',
                  Colors.green[600]!,
                ),
              ),
            ],
          ),
          if (_isLoadingOffers) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading offers...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_discountAmount > 0) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.discount,
                    color: Colors.orange[600],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discount Applied',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                        Text(
                          '৳${_discountAmount.toStringAsFixed(0)} off',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'SAVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payable Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    '৳${_payableAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.green[600],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              IconButton(
                onPressed: _refreshWalletData,
                icon: Icon(
                  Icons.refresh,
                  color: Colors.blue[600],
                  size: 20,
                ),
                tooltip: 'Refresh wallet balance',
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBalanceCard(
                  'Available Balance',
                  '৳${_walletBalance.toStringAsFixed(0)}',
                  _insufficientBalance ? Colors.red[600]! : Colors.green[600]!,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildBalanceCard(
                  'Gems',
                  '$_gems',
                  Colors.orange[600]!,
                ),
              ),
            ],
          ),
          if (_insufficientBalance) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insufficient balance. You need ৳${(_payableAmount - _walletBalance).toStringAsFixed(0)} more.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Column(
      children: [
        if (_insufficientBalance) ...[
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[400],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                'Insufficient Balance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isProcessingPayment ? null : _processPaymentWithWallet,
              icon: Icon(Icons.account_balance_wallet, size: 24),
              label: Text(
                'Use Wallet - ৳${_payableAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingPayment ? null : _processPaymentWithGpay,
              icon: Icon(Icons.payment, size: 24),
              label: Text(
                'Pay with Gpay - ৳${_payableAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
        if (_isProcessingPayment) ...[
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Processing Payment...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
