import 'package:flutter/material.dart';
import '../models/offers.dart';
import '../services/offers_service.dart';
import '../services/auth_service.dart';

class OffersScreen extends StatefulWidget {
  static const routeName = '/offers';

  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  Offers? _userOffers;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserOffers();
  }

  Future<void> _loadUserOffers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await AuthService.getToken();
      if (token != null) {
        final offers = await OffersService.getUserOffers(token);
        setState(() {
          _userOffers = offers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Authentication required';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error in _loadUserOffers: $e');
      print('DEBUG: Error type: ${e.runtimeType}');
      setState(() {
        _error = 'Failed to load offers: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
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
              'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
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
              onPressed: _loadUserOffers,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_userOffers == null) {
      return _buildEmptyState();
    }

    return _buildUserOffers();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_offer_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Offers Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for exciting offers and promotions!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUserOffers() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildCashbackCard(),
        SizedBox(height: 16),
        _buildCouponCard(),
        SizedBox(height: 16),
        _buildDiscountCard(),
      ],
    );
  }

  Widget _buildCashbackCard() {
    final hasCashback =
        _userOffers?.cashback != null && _userOffers!.cashback > 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                  color: hasCashback ? Colors.green[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.monetization_on,
                  color: hasCashback ? Colors.green[600] : Colors.grey[400],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Cashback Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasCashback
                                ? Colors.green[100]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasCashback
                                  ? Colors.green[300]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            hasCashback ? 'Available' : 'Not Available',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasCashback
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      hasCashback
                          ? 'Cashback available to use on rides'
                          : 'No cashback available',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            hasCashback ? Colors.green[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '৳${_userOffers?.cashback.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: hasCashback ? Colors.green[600] : Colors.grey[400],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: hasCashback ? () => _useCashback() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasCashback ? Colors.green[600] : Colors.grey[300],
                    foregroundColor:
                        hasCashback ? Colors.white : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(hasCashback ? 'Use Cashback' : 'No Cashback'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard() {
    final hasCoupon = _userOffers?.coupon != null && _userOffers!.coupon > 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                  color: hasCoupon ? Colors.blue[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.confirmation_number,
                  color: hasCoupon ? Colors.blue[600] : Colors.grey[400],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Coupon Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                hasCoupon ? Colors.blue[100] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasCoupon
                                  ? Colors.blue[300]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            hasCoupon ? 'Available' : 'Not Available',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasCoupon
                                  ? Colors.blue[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      hasCoupon
                          ? 'Coupon available to use on rides'
                          : 'No coupon available',
                      style: TextStyle(
                        fontSize: 14,
                        color: hasCoupon ? Colors.blue[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '৳${_userOffers?.coupon.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: hasCoupon ? Colors.blue[600] : Colors.grey[400],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: hasCoupon ? () => _useCoupon() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasCoupon ? Colors.blue[600] : Colors.grey[300],
                    foregroundColor:
                        hasCoupon ? Colors.white : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(hasCoupon ? 'Use Coupon' : 'No Coupon'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard() {
    final hasDiscount =
        _userOffers?.discount != null && _userOffers!.discount > 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                  color: hasDiscount ? Colors.orange[100] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.discount,
                  color: hasDiscount ? Colors.orange[600] : Colors.grey[400],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Discount Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hasDiscount
                                ? Colors.orange[100]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hasDiscount
                                  ? Colors.orange[300]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            hasDiscount ? 'Available' : 'Not Available',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: hasDiscount
                                  ? Colors.orange[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      hasDiscount
                          ? 'Discount available to use on rides'
                          : 'No discount available',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            hasDiscount ? Colors.orange[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            '৳${_userOffers?.discount.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: hasDiscount ? Colors.orange[600] : Colors.grey[400],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: hasDiscount ? () => _useDiscount() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasDiscount ? Colors.orange[600] : Colors.grey[300],
                    foregroundColor:
                        hasDiscount ? Colors.white : Colors.grey[600],
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(hasDiscount ? 'Use Discount' : 'No Discount'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _useCashback() {
    _showUseDialog('Cashback', _userOffers?.cashback ?? 0, Colors.green[600]!);
  }

  void _useCoupon() {
    _showUseDialog('Coupon', _userOffers?.coupon ?? 0, Colors.blue[600]!);
  }

  void _useDiscount() {
    _showUseDialog('Discount', _userOffers?.discount ?? 0, Colors.orange[600]!);
  }

  void _showUseDialog(String type, double amount, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                type == 'Cashback'
                    ? Icons.monetization_on
                    : type == 'Coupon'
                        ? Icons.confirmation_number
                        : Icons.discount,
                color: color,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Use $type',
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
                'How much $type would you like to use?',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: color,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Available: ৳${amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
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
                _showSuccessDialog(type, color);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Use $type',
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

  void _showSuccessDialog(String type, Color color) {
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
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '✓',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '$type Applied!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Your $type has been applied to your next ride.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Great!',
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
          'Offers & Promotions',
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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  String _buildOffersSummary() {
    if (_userOffers == null) {
      return 'Loading your offers...';
    }

    final hasCashback = _userOffers!.cashback > 0;
    final hasCoupon = _userOffers!.coupon > 0;
    final hasDiscount = _userOffers!.discount > 0;

    if (!hasCashback && !hasCoupon && !hasDiscount) {
      return 'No offers available at the moment';
    }

    final availableOffers = <String>[];
    if (hasCashback) availableOffers.add('Cashback');
    if (hasCoupon) availableOffers.add('Coupon');
    if (hasDiscount) availableOffers.add('Discount');

    if (availableOffers.length == 1) {
      return '${availableOffers.first} available to use';
    } else if (availableOffers.length == 2) {
      return '${availableOffers.first} & ${availableOffers.last} available';
    } else {
      return '${availableOffers.take(2).join(', ')} & more available';
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Special Offers Available!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _buildOffersSummary(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
