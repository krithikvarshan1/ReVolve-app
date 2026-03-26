class Device {
  final String id;
  final String name;
  final String type;
  final bool isOnline;
  final bool relayStatus; // ON/OFF
  final double latitude;
  final double longitude;
  final DateTime lastSeen;
  final Map<String, dynamic>? specs; // Device specifications

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.isOnline,
    required this.relayStatus,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    this.specs,
  });

  // Factory from JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      isOnline: json['isOnline'] ?? false,
      relayStatus: json['relayStatus'] ?? false,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      lastSeen: DateTime.parse(json['lastSeen'] ?? DateTime.now().toIso8601String()),
      specs: json['specs'],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'isOnline': isOnline,
      'relayStatus': relayStatus,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': lastSeen.toIso8601String(),
      'specs': specs,
    };
  }

  // Copy with
  Device copyWith({
    String? id,
    String? name,
    String? type,
    bool? isOnline,
    bool? relayStatus,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    Map<String, dynamic>? specs,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isOnline: isOnline ?? this.isOnline,
      relayStatus: relayStatus ?? this.relayStatus,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      specs: specs ?? this.specs,
    );
  }
}