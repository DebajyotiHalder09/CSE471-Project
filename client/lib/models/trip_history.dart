class TripHistory {
  final String id;
  final String userId;
  final String busId;
  final String busName;
  final double distance;
  final double fare;
  final String source;
  final String destination;
  final DateTime createdAt;

  TripHistory({
    required this.id,
    required this.userId,
    required this.busId,
    required this.busName,
    required this.distance,
    required this.fare,
    required this.source,
    required this.destination,
    required this.createdAt,
  });

  factory TripHistory.fromJson(Map<String, dynamic> json) {
    return TripHistory(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      busId: json['busId'] ?? '',
      busName: json['busName'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      fare: json['fare'] is double
          ? json['fare']
          : (json['fare'] is int
              ? json['fare'].toDouble()
              : double.tryParse(json['fare'].toString()) ?? 0.0),
      source: json['source'] ?? '',
      destination: json['destination'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'busId': busId,
      'busName': busName,
      'distance': distance,
      'fare': fare,
      'source': source,
      'destination': destination,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
