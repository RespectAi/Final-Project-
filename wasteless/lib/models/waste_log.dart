class WasteLog {
  final String id;
  final String? itemId;
  final String itemName;
  final int quantity;
  final String? reason;
  final DateTime loggedAt;

  const WasteLog({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.quantity,
    this.reason,
    required this.loggedAt,
  });

  factory WasteLog.fromMap(Map<String, dynamic> map) {
    // Resolve itemName from denormalized field or joined inventory_items
    String resolvedName = map['item_name']?.toString() ?? '';
    if (resolvedName.isEmpty && map['inventory_items'] is Map) {
      resolvedName = map['inventory_items']['name']?.toString() ?? '';
    }
    if (resolvedName.isEmpty) resolvedName = 'Unknown Item';

    final loggedAtStr = map['logged_at']?.toString();
    return WasteLog(
      id: map['id']?.toString() ?? '',
      itemId: map['item_id']?.toString(),
      itemName: resolvedName,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      reason: map['reason']?.toString(),
      loggedAt: loggedAtStr != null ? DateTime.tryParse(loggedAtStr) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    if (itemId != null) 'item_id': itemId,
    'item_name': itemName,
    'quantity': quantity,
    if (reason != null) 'reason': reason,
    'logged_at': loggedAt.toIso8601String(),
  };

  @override
  String toString() => 'WasteLog(id: $id, item: $itemName, qty: $quantity)';
}
