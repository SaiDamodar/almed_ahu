/// Hospital model representing a hospital site with rooms and AHUs
class Hospital {
  final String id; // e.g., "hospitalA"
  final String name; // Display name
  final Map<String, List<AhuDevice>> rooms; // room -> list of AHUs

  Hospital({
    required this.id,
    required this.name,
    required this.rooms,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    final rooms = <String, List<AhuDevice>>{};
    
    // Parse rooms structure from API response
    if (json['rooms'] != null) {
      final roomsData = json['rooms'] as Map<String, dynamic>;
      roomsData.forEach((roomId, devices) {
        if (devices is List) {
          rooms[roomId] = (devices as List)
              .map((d) => AhuDevice.fromJson(d))
              .toList();
        }
      });
    }
    
    return Hospital(
      id: json['id'] as String? ?? json['site'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      rooms: rooms,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rooms': rooms.map((key, value) => MapEntry(key, value.map((e) => e.toJson()).toList())),
    };
  }
  
  /// Get total number of AHUs across all rooms
  int get totalAhus {
    return rooms.values.fold(0, (sum, ahus) => sum + ahus.length);
  }
  
  /// Get all AHUs in a flat list
  List<AhuDevice> get allAhus {
    return rooms.values.expand((ahus) => ahus).toList();
  }
}

/// AHU Device model
class AhuDevice {
  final String id;
  final String name;
  final String site;
  final String room;
  final DateTime? lastSeen;
  final String? status; // 'online' or 'offline'

  AhuDevice({
    required this.id,
    required this.name,
    required this.site,
    required this.room,
    this.lastSeen,
    this.status,
  });

  factory AhuDevice.fromJson(Map<String, dynamic> json) {
    DateTime? lastSeen;
    if (json['last_seen'] != null) {
      if (json['last_seen'] is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(json['last_seen'] * 1000);
      } else if (json['last_seen'] is String) {
        lastSeen = DateTime.tryParse(json['last_seen']);
      }
    }
    
    return AhuDevice(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      site: json['site'] as String? ?? 'hospitalA',
      room: json['room'] as String? ?? 'room1',
      lastSeen: lastSeen,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'site': site,
      'room': room,
      'last_seen': lastSeen?.millisecondsSinceEpoch,
      'status': status,
    };
  }
  
  bool get isOnline => status == 'online';
}

