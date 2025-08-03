class Bus {
  final String id;
  final String busName;
  final List<String> stops;
  final String? routeNumber;
  final String? operator;
  final String? frequency;

  Bus({
    required this.id,
    required this.busName,
    required this.stops,
    this.routeNumber,
    this.operator,
    this.frequency,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['_id'] ?? '',
      busName: json['busName'] ?? '',
      stops: List<String>.from(json['stops'] ?? []),
      routeNumber: json['routeNumber'],
      operator: json['operator'],
      frequency: json['frequency'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'busName': busName,
      'stops': stops,
      'routeNumber': routeNumber,
      'operator': operator,
      'frequency': frequency,
    };
  }
} 