import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/donation_item.dart';
import '../models/waste_log.dart';

/// Service managing food waste logs and donations.
class WasteDonationService {
  final SupabaseClient client;
  final Future<void> Function(String itemId, int newQty)? onUpdateItemQuantity;
  final Future<void> Function(String itemId)? onDeleteInventoryItem;

  WasteDonationService({
    required this.client,
    this.onUpdateItemQuantity,
    this.onDeleteInventoryItem,
  });

  /// Fetch this user's waste logs as raw maps
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

    final data = await client
        .from('waste_logs')
        .select('id, item_id, quantity, reason, item_name, logged_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('logged_at', ascending: false);
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch typed WasteLog models
  Future<List<WasteLog>> fetchWasteLogModels() async {
    final raw = await fetchWasteLogs();
    return raw.map((m) => WasteLog.fromMap(m)).toList();
  }

  /// Log waste for an item. Reduces item quantity or deletes item if all units are wasted.
  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    String itemName = '';
    int currentQty = 1;
    try {
      final inv = await client
          .from('inventory_items')
          .select('name, quantity')
          .eq('id', itemId)
          .single();
      itemName = (inv['name'] as String?) ?? '';
      currentQty = (inv['quantity'] as int?) ?? 1;
    } catch (_) {}

    final entry = {
      'item_id': itemId,
      'quantity': qty,
      'logged_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      if (reason?.isNotEmpty ?? false) 'reason': reason,
      if (itemName.isNotEmpty) 'item_name': itemName,
    };
    await client.from('waste_logs').insert(entry);

    if (currentQty > qty) {
      if (onUpdateItemQuantity != null) {
        await onUpdateItemQuantity!(itemId, currentQty - qty);
      }
    } else {
      if (onDeleteInventoryItem != null) {
        await onDeleteInventoryItem!(itemId);
      }
    }
  }

  /// Delete a waste log entry by ID
  Future<void> deleteWasteLog(String id) async {
    await client.from('waste_logs').delete().eq('id', id);
  }

  /// Fetch this user's donations as raw maps
  Future<List<Map<String, dynamic>>> fetchDonations() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

    final data = await client
        .from('donations')
        .select('id, item_id, item_name, recipient_info, offered_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('offered_at', ascending: false);
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch typed DonationItem models
  Future<List<DonationItem>> fetchDonationModels() async {
    final raw = await fetchDonations();
    return raw.map((m) => DonationItem.fromMap(m)).toList();
  }

  /// Offer a donation (reduces quantity; deletes only if all units offered)
  Future<void> offerDonation(String itemId, String recipientInfo, [int qty = 1]) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    String itemName = '';
    int currentQty = 1;
    try {
      final inv = await client
          .from('inventory_items')
          .select('name, quantity')
          .eq('id', itemId)
          .single();
      itemName = (inv['name'] as String?) ?? '';
      currentQty = (inv['quantity'] as int?) ?? 1;
    } catch (_) {}

    await client.from('donations').insert({
      'item_id': itemId,
      'recipient_info': recipientInfo,
      'offered_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      if (itemName.isNotEmpty) 'item_name': itemName,
    });

    if (currentQty > qty) {
      if (onUpdateItemQuantity != null) {
        await onUpdateItemQuantity!(itemId, currentQty - qty);
      }
    } else {
      if (onDeleteInventoryItem != null) {
        await onDeleteInventoryItem!(itemId);
      }
    }
  }

  /// Delete a donation record by ID
  Future<void> deleteDonation(String id) async {
    await client.from('donations').delete().eq('id', id);
  }
}
