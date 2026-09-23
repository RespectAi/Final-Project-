// lib/models/donation_item.dart
import 'dart:convert';

class DonationItem {
  final String id;
  final String? itemId;
  final String itemName;
  final String recipientInfo;
  final DateTime offeredAt;
  final String status; // 'pending', 'scheduled', 'completed', 'cancelled'
  final String? charityId;

  // Rich metadata decoded from recipient_info (or direct fields)
  final String charityName;
  final String? charityPhone;
  final String? charityCategory;
  final String logisticsType; // 'pickup' or 'drop_off'
  final String? address;
  final String? timeWindow;
  final String? donorPhone;
  final String? notes;
  final DateTime? itemExpiry;
  final int quantity;

  const DonationItem({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.recipientInfo,
    required this.offeredAt,
    this.status = 'pending',
    this.charityId,
    required this.charityName,
    this.charityPhone,
    this.charityCategory,
    this.logisticsType = 'pickup',
    this.address,
    this.timeWindow,
    this.donorPhone,
    this.notes,
    this.itemExpiry,
    this.quantity = 1,
  });

  /// Encode rich donation metadata into a JSON string for recipient_info
  static String encodeRecipientInfo({
    required String charityName,
    String? charityPhone,
    String? charityCategory,
    String logisticsType = 'pickup',
    String? address,
    String? timeWindow,
    String? donorPhone,
    String? notes,
    DateTime? expiry,
    int quantity = 1,
    String status = 'pending',
  }) {
    return jsonEncode({
      'charity_name': charityName,
      'charity_phone': charityPhone,
      'charity_category': charityCategory,
      'logistics_type': logisticsType,
      'address': address,
      'time_window': timeWindow,
      'donor_phone': donorPhone,
      'notes': notes,
      'expiry_date': expiry?.toIso8601String(),
      'quantity': quantity,
      'status': status,
    });
  }

  factory DonationItem.fromMap(Map<String, dynamic> map) {
    String resolvedName = map['item_name']?.toString() ?? '';
    if (resolvedName.isEmpty && map['inventory_items'] is Map) {
      resolvedName = map['inventory_items']['name']?.toString() ?? '';
    }
    if (resolvedName.isEmpty) resolvedName = 'Food Item';

    final offeredAtStr = map['offered_at']?.toString();
    final rawRecipient = map['recipient_info']?.toString() ?? '';
    String resolvedStatus = map['status']?.toString() ?? 'pending';

    String cName = rawRecipient;
    String? cPhone;
    String? cCat;
    String logType = 'pickup';
    String? addr;
    String? tWindow;
    String? dPhone;
    String? note;
    DateTime? exp;
    int qty = (map['quantity'] as int?) ?? 1;

    // Check if recipient_info contains structured JSON
    if (rawRecipient.trim().startsWith('{') && rawRecipient.trim().endsWith('}')) {
      try {
        final decoded = jsonDecode(rawRecipient);
        if (decoded is Map<String, dynamic>) {
          cName = decoded['charity_name']?.toString() ?? rawRecipient;
          cPhone = decoded['charity_phone']?.toString();
          cCat = decoded['charity_category']?.toString();
          logType = decoded['logistics_type']?.toString() ?? 'pickup';
          addr = decoded['address']?.toString();
          tWindow = decoded['time_window']?.toString();
          dPhone = decoded['donor_phone']?.toString();
          note = decoded['notes']?.toString();
          if (decoded['status'] != null) {
            resolvedStatus = decoded['status'].toString();
          }
          if (decoded['expiry_date'] != null) {
            exp = DateTime.tryParse(decoded['expiry_date'].toString());
          }
          if (decoded['quantity'] != null) {
            qty = (decoded['quantity'] as num).toInt();
          }
        }
      } catch (_) {
        // Fallback to raw text
      }
    }

    if (cName.isEmpty) cName = 'Charity Organization';

    return DonationItem(
      id: map['id']?.toString() ?? '',
      itemId: map['item_id']?.toString(),
      itemName: resolvedName,
      recipientInfo: rawRecipient,
      offeredAt: offeredAtStr != null ? DateTime.tryParse(offeredAtStr) ?? DateTime.now() : DateTime.now(),
      status: resolvedStatus,
      charityId: map['charity_id']?.toString(),
      charityName: cName,
      charityPhone: cPhone,
      charityCategory: cCat,
      logisticsType: logType,
      address: addr,
      timeWindow: tWindow,
      donorPhone: dPhone,
      notes: note,
      itemExpiry: exp,
      quantity: qty,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    if (itemId != null) 'item_id': itemId,
    'item_name': itemName,
    'recipient_info': recipientInfo,
    'offered_at': offeredAt.toIso8601String(),
    'status': status,
    'quantity': quantity,
    if (itemExpiry != null) 'expiry_date': itemExpiry!.toIso8601String(),
    if (charityId != null) 'charity_id': charityId,
  };

  DonationItem copyWith({
    String? status,
    String? charityName,
    String? charityPhone,
    String? logisticsType,
    String? address,
    String? timeWindow,
    String? donorPhone,
    String? notes,
    DateTime? itemExpiry,
    int? quantity,
  }) {
    final updatedRecipient = encodeRecipientInfo(
      charityName: charityName ?? this.charityName,
      charityPhone: charityPhone ?? this.charityPhone,
      charityCategory: charityCategory,
      logisticsType: logisticsType ?? this.logisticsType,
      address: address ?? this.address,
      timeWindow: timeWindow ?? this.timeWindow,
      donorPhone: donorPhone ?? this.donorPhone,
      notes: notes ?? this.notes,
      expiry: itemExpiry ?? this.itemExpiry,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
    );

    return DonationItem(
      id: id,
      itemId: itemId,
      itemName: itemName,
      recipientInfo: updatedRecipient,
      offeredAt: offeredAt,
      status: status ?? this.status,
      charityId: charityId,
      charityName: charityName ?? this.charityName,
      charityPhone: charityPhone ?? this.charityPhone,
      charityCategory: charityCategory,
      logisticsType: logisticsType ?? this.logisticsType,
      address: address ?? this.address,
      timeWindow: timeWindow ?? this.timeWindow,
      donorPhone: donorPhone ?? this.donorPhone,
      notes: notes ?? this.notes,
      itemExpiry: itemExpiry ?? this.itemExpiry,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  String toString() => 'DonationItem(id: $id, item: $itemName, charity: $charityName, status: $status)';
}
