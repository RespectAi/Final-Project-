class FridgeMember {
  final String id;
  final String userId;
  final String fridgeId;
  final String role; // 'admin' or 'member'
  final DateTime joinedAt;
  final String userName;
  final String fridgeName;

  const FridgeMember({
    required this.id,
    required this.userId,
    required this.fridgeId,
    required this.role,
    required this.joinedAt,
    this.userName = 'Member',
    this.fridgeName = 'Unknown Fridge',
  });

  bool get isAdmin => role == 'admin';

  factory FridgeMember.fromMap(Map<String, dynamic> map) {
    final joinedAtStr = map['joined_at']?.toString();
    return FridgeMember(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      fridgeId: map['fridge_id']?.toString() ?? '',
      role: map['role']?.toString() ?? 'member',
      joinedAt: joinedAtStr != null ? DateTime.tryParse(joinedAtStr) ?? DateTime.now() : DateTime.now(),
      userName: map['user_name']?.toString() ?? 'Member',
      fridgeName: map['fridge_name']?.toString() ?? 'Unknown Fridge',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'fridge_id': fridgeId,
    'role': role,
    'joined_at': joinedAt.toIso8601String(),
    'user_name': userName,
    'fridge_name': fridgeName,
  };

  @override
  String toString() => 'FridgeMember(user: $userName, role: $role, fridge: $fridgeName)';
}
