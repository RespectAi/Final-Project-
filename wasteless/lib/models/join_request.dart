class JoinRequest {
  final String id;
  final String requesterId;
  final String fridgeId;
  final String status; // 'pending', 'approved', 'rejected'
  final String? message;
  final DateTime createdAt;
  final String requesterName;
  final String fridgeName;

  const JoinRequest({
    required this.id,
    required this.requesterId,
    required this.fridgeId,
    required this.status,
    this.message,
    required this.createdAt,
    this.requesterName = 'User',
    this.fridgeName = 'Unknown Fridge',
  });

  bool get isPending => status == 'pending';

  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    final createdAtStr = map['created_at']?.toString();
    return JoinRequest(
      id: map['id']?.toString() ?? '',
      requesterId: map['requester_id']?.toString() ?? '',
      fridgeId: map['fridge_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      message: map['message']?.toString(),
      createdAt: createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now(),
      requesterName: map['requester_name']?.toString() ?? 'User',
      fridgeName: map['fridge_name']?.toString() ?? 'Unknown Fridge',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'requester_id': requesterId,
    'fridge_id': fridgeId,
    'status': status,
    if (message != null) 'message': message,
    'created_at': createdAt.toIso8601String(),
    'requester_name': requesterName,
    'fridge_name': fridgeName,
  };

  @override
  String toString() => 'JoinRequest(id: $id, requester: $requesterName, fridge: $fridgeName)';
}
