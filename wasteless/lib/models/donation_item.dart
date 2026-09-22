class DonationItem {
  final String id;
  final String? itemId;
  final String itemName;
  final String recipientInfo;
  final DateTime offeredAt;

  const DonationItem({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.recipientInfo,
    required this.offeredAt,
  });

  factory DonationItem.fromMap(Map<String, dynamic> map) {
    String resolvedName = map['item_name']?.toString() ?? '';
    if (resolvedName.isEmpty && map['inventory_items'] is Map) {
      resolvedName = map['inventory_items']['name']?.toString() ?? '';
    }
    if (resolvedName.isEmpty) resolvedName = 'Unknown Item';

    final offeredAtStr = map['offered_at']?.toString();
    return DonationItem(
      id: map['id']?.toString() ?? '',
      itemId: map['item_id']?.toString(),
      itemName: resolvedName,
      recipientInfo: map['recipient_info']?.toString() ?? '',
      offeredAt: offeredAtStr != null ? DateTime.tryParse(offeredAtStr) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    if (itemId != null) 'item_id': itemId,
    'item_name': itemName,
    'recipient_info': recipientInfo,
    'offered_at': offeredAt.toIso8601String(),
  };

  @override
  String toString() => 'DonationItem(id: $id, item: $itemName, recipient: $recipientInfo)';
}
