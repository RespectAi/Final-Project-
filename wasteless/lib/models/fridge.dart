class Fridge {
  final String id;
  final String name;
  final String? location;
  final String? inviteCode;
  final DateTime createdAt;
  final String? role; // Current user's role: 'admin', 'member', etc.

  const Fridge({
    required this.id,
    required this.name,
    this.location,
    this.inviteCode,
    required this.createdAt,
    this.role,
  });

  bool get isAdmin => role == 'admin' || role == 'owner';

  factory Fridge.fromMap(Map<String, dynamic> map) {
    // Check if fridge details are nested inside 'fridges' or directly in map
    Map<String, dynamic> source = map;
    if (map['fridges'] is Map) {
      source = Map<String, dynamic>.from(map['fridges'] as Map);
    }

    final createdAtStr = source['created_at']?.toString();
    return Fridge(
      id: (source['id'] ?? map['fridge_id'])?.toString() ?? '',
      name: source['name']?.toString() ?? 'Unnamed Fridge',
      location: source['location']?.toString(),
      inviteCode: source['invite_code']?.toString(),
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now(),
      role: map['role']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    if (inviteCode != null) 'invite_code': inviteCode,
    'created_at': createdAt.toIso8601String(),
    if (role != null) 'role': role,
  };

  @override
  String toString() => 'Fridge(id: $id, name: $name, role: $role)';
}
