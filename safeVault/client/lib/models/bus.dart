class Bus {
  final String id;
  final String busName;
  final List<BusStop> stops;
  final String? routeNumber;
  final String? operator;
  final String? frequency;
  final double baseFare;
  final double perKmFare;

  Bus({
    required this.id,
    required this.busName,
    required this.stops,
    this.routeNumber,
    this.operator,
    this.frequency,
    required this.baseFare,
    required this.perKmFare,
  });

  List<String> get stopNames => stops.map((stop) => stop.name).toList();

  double calculateFare(double distanceInKm) {
    return baseFare + (distanceInKm * perKmFare);
  }

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['_id'] ?? '',
      busName: json['busName'] ?? '',
      stops: (json['stops'] as List<dynamic>?)
              ?.map((stop) => BusStop.fromJson(stop))
              .toList() ??
          [],
      routeNumber: json['routeNumber'],
      operator: json['operator'],
      frequency: json['frequency'],
      baseFare: (json['base_fare'] ?? 0.0).toDouble(),
      perKmFare: (json['per_km_fare'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'busName': busName,
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'routeNumber': routeNumber,
      'operator': operator,
      'frequency': frequency,
      'base_fare': baseFare,
      'per_km_fare': perKmFare,
    };
  }
}

class BusStop {
  final String name;
  final double latitude;
  final double longitude;

  BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      name: json['name'] ?? '',
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['lng'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': latitude,
      'lng': longitude,
    };
  }
}
