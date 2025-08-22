import 'wallet.dart';

class Offers {
  final String id;
  final String userId;
  final Wallet wallet;
  final double cashback;
  final double coupon;
  final double discount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Offers({
    required this.id,
    required this.userId,
    required this.wallet,
    required this.cashback,
    required this.coupon,
    required this.discount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Offers.fromJson(Map<String, dynamic> json) {
    // Handle the case where walletId might be a populated object or just an ID
    Wallet wallet;
    if (json['walletId'] is Map<String, dynamic>) {
      wallet = Wallet.fromJson(json['walletId']);
    } else {
      // Create a default wallet if walletId is just a string ID
      wallet = Wallet(
        id: json['walletId']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        balance: 0,
        gems: 0,
        currency: 'BDT',
        lastUpdated: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return Offers(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId']?.toString() ?? '',
      wallet: wallet,
      cashback: (json['cashback'] ?? 0).toDouble(),
      coupon: (json['coupon'] ?? 0).toDouble(),
      discount: (json['discount'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'walletId': wallet.toJson(),
      'cashback': cashback,
      'coupon': coupon,
      'discount': discount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Offers copyWith({
    String? id,
    String? userId,
    Wallet? wallet,
    double? cashback,
    double? coupon,
    double? discount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Offers(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      wallet: wallet ?? this.wallet,
      cashback: cashback ?? this.cashback,
      coupon: coupon ?? this.coupon,
      discount: discount ?? this.discount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
