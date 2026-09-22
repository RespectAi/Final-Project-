class LocalUser {
  final String id;
  final String name;
  final DateTime createdAt;

  const LocalUser({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    final createdAtStr = map['created_at']?.toString();
    return LocalUser(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalUser &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'LocalUser(id: $id, name: $name)';
}
