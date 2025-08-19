// lib/services/supabase_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SupabaseService {
  final FlutterLocalNotificationsPlugin _local;
  SupabaseService(this._local);

  final SupabaseClient client = Supabase.instance.client;

  // NEW: simple broadcast stream to notify other widgets/pages of inventory changes
  final StreamController<void> _inventoryChanged = StreamController<void>.broadcast();
  Stream<void> get onInventoryChanged => _inventoryChanged.stream;

  void _notifyInventoryChanged() {
    try {
      _inventoryChanged.add(null);
    } catch (_) {}
  }

  /// Fetch only this user’s inventory
  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('inventory_items')
        .select('''
         id,
         name,
         created_at,
         expiry_date,
         quantity,
         reminder_days_before,
         reminder_hours_before,
         inventory_item_categories (
          category_id,
          categories ( id, name, icon_url )
      )
    ''')
        .eq('user_id', uid)
        .order('expiry_date', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await client.from('categories').select('id, name, icon_url, default_expiry_days').order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch this user's inventory filtered by category
  Future<List<Map<String, dynamic>>> fetchInventoryByCategory(String categoryId) async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('inventory_items')
        .select('''
         id,
         name,
         created_at,
         expiry_date,
         quantity,
         reminder_days_before,
         reminder_hours_before,
         inventory_item_categories!inner(
            category_id,
            categories ( id, name, icon_url )
         )
        ''')
        .eq('user_id', uid)
        .eq('inventory_item_categories.category_id', categoryId)
        .order('expiry_date', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Add item (simplified snippet) — notify after successful insert
  Future<void> addItem({
    required String name,
    required DateTime expiry,
    required int quantity,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
    required List<String> categoryIds,
  }) async {
    final uid = client.auth.currentUser!.id;
    final res = await client
        .from('inventory_items')
        .insert({
          'name': name,
          'expiry_date': expiry.toIso8601String(),
          'quantity': quantity,
          'reminder_days_before': reminderDaysBefore,
          'reminder_hours_before': reminderHoursBefore,
          'user_id': uid,
        })
        .select('id')
        .single();
    final itemId = res['id'] as String;

    if (categoryIds.isNotEmpty) {
      await client.from('inventory_item_categories').insert(
            categoryIds
                .map((catId) => {'inventory_item_id': itemId, 'category_id': catId})
                .toList(),
          );
    }

    // schedule notification (best-effort)
    try {
      final notifyTime = expiry.subtract(Duration(days: reminderDaysBefore, hours: reminderHoursBefore));
      if (notifyTime.isAfter(DateTime.now())) {
        await _local.zonedSchedule(
          itemId.hashCode,
          'Expiry Reminder',
          '$name expires on ${expiry.toLocal()}',
          tz.TZDateTime.from(notifyTime, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'expiry_channel',
              'Expiry Alerts',
              channelDescription: 'Reminders for inventory expiry',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    } catch (_) {}

    // Notify subscribers that inventory changed
    _notifyInventoryChanged();
  }

  /// Delete an inventory item by its id
  Future<void> deleteInventoryItem(String id) async {
    await client.from('inventory_items').delete().eq('id', id);
    _notifyInventoryChanged();
  }

  /// Log waste (denormalize item_name), then remove the inventory item
  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final uid = client.auth.currentUser!.id;
    // fetch name
    String itemName = '';
    try {
      final inv = await client.from('inventory_items').select('name').eq('id', itemId).single();
      itemName = (inv['name'] as String?) ?? '';
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

    // delete inventory item
    await deleteInventoryItem(itemId);
    // deleteInventoryItem already calls _notifyInventoryChanged
  }

  /// Offer donation then delete inventory item
  Future<void> offerDonation(String itemId, String recipientInfo) async {
    final uid = client.auth.currentUser!.id;
    String itemName = '';
    try {
      final inv = await client.from('inventory_items').select('name').eq('id', itemId).single();
      itemName = (inv['name'] as String?) ?? '';
    } catch (_) {}
    await client.from('donations').insert({
      'item_id': itemId,
      'recipient_info': recipientInfo,
      'offered_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      if (itemName.isNotEmpty) 'item_name': itemName,
    });
    await deleteInventoryItem(itemId);
  }

  /// Fetch waste logs/donations etc. (unchanged)
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('waste_logs')
        .select('id, item_id, quantity, reason, item_name, logged_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('logged_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> fetchDonations() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('donations')
        .select('id, item_id, item_name, recipient_info, offered_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('offered_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Delete donation/waste helpers
  Future<void> deleteWasteLog(String id) async {
    await client.from('waste_logs').delete().eq('id', id);
  }

  Future<void> deleteDonation(String id) async {
    await client.from('donations').delete().eq('id', id);
  }

  // Dispose stream controller if app teardown ever required
  void dispose() {
    try {
      _inventoryChanged.close();
    } catch (_) {}
  }
}
