class IndividualBus {
  final String id;
  final String parentBusInfoId;
  final String busCode;
  final int totalPassengerCapacity;
  final int currentPassengerCount;
  final double latitude;
  final double longitude;
  final double averageSpeedKmh;
  final String status;
  final String busType;

  IndividualBus({
    required this.id,
    required this.parentBusInfoId,
    required this.busCode,
    required this.totalPassengerCapacity,
    required this.currentPassengerCount,
    required this.latitude,
    required this.longitude,
    required this.averageSpeedKmh,
    required this.status,
    required this.busType,
  });

  factory IndividualBus.fromJson(Map<String, dynamic> json) {
    return IndividualBus(
      id: json['_id'] ?? '',
      parentBusInfoId: json['parentBusInfoId'] ?? '',
      busCode: json['busCode'] ?? '',
      totalPassengerCapacity: json['totalPassengerCapacity'] ?? 0,
      currentPassengerCount: json['currentPassengerCount'] ?? 0,
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      averageSpeedKmh: (json['averageSpeedKmh'] ?? 25.0).toDouble(),
      status: json['status'] ?? 'offline',
      busType: json['busType'] ?? 'general',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'parentBusInfoId': parentBusInfoId,
      'busCode': busCode,
      'totalPassengerCapacity': totalPassengerCapacity,
      'currentPassengerCount': currentPassengerCount,
      'latitude': latitude,
      'longitude': longitude,
      'averageSpeedKmh': averageSpeedKmh,
      'status': status,
      'busType': busType,
    };
  }
}
