// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SupabaseService {
  final FlutterLocalNotificationsPlugin _local;

  SupabaseService(this._local);

  final SupabaseClient client = Supabase.instance.client;

  /// Fetch only this user’s inventory
  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('inventory_items')
        .select('''
         id,
         name,
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

  /// Fetch the full list of (pre‐seeded) categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await client.from('categories').select('id, name, icon_url').order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch only this user’s waste logs (prefer denormalized item_name, fallback to join)
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('waste_logs')
        .select('id, item_id, quantity, reason, item_name, logged_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('logged_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addItem({
    required String name,
    required DateTime expiry,
    required int quantity,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
    required List<String> categoryIds,
  }) async {
    final uid = client.auth.currentUser!.id;

    // 1) insert the item
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

    // 2) link to categories
    if (categoryIds.isNotEmpty) {
      await client.from('inventory_item_categories').insert(
            categoryIds
                .map((catId) => {'inventory_item_id': itemId, 'category_id': catId})
                .toList(),
          );
    }

    // 3) schedule notification (best-effort)
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
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    } catch (_) {}
  }

  /// Log waste FOR THIS USER (store item_name before deleting)
  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final uid = client.auth.currentUser!.id;

    // get name BEFORE deletion
    String itemName = '';
    try {
      final inv = await client
          .from('inventory_items')
          .select('name')
          .eq('id', itemId)
          .single();
      itemName = (inv['name'] as String?) ?? '';
    } catch (_) {}

    final entry = {
      'item_id': itemId,
      'quantity': qty,
      'logged_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      if (reason?.isNotEmpty ?? false) 'reason': reason,
      if (itemName.isNotEmpty) 'item_name': itemName, // denormalized
    };
    await client.from('waste_logs').insert(entry);

    // remove from inventory
    await deleteInventoryItem(itemId);
  }

  /// Delete a waste log by its id
  Future<void> deleteWasteLog(String id) async {
    await client.from('waste_logs').delete().eq('id', id);
  }

  /// Offer a donation FOR THIS USER (store item_name before deleting)
  Future<void> offerDonation(String itemId, String recipientInfo) async {
    final uid = client.auth.currentUser!.id;

    // get name BEFORE deletion
    String itemName = '';
    try {
      final inv = await client
          .from('inventory_items')
          .select('name')
          .eq('id', itemId)
          .single();
      itemName = (inv['name'] as String?) ?? '';
    } catch (_) {}

    await client.from('donations').insert({
      'item_id': itemId,
      'recipient_info': recipientInfo,
      'offered_at': DateTime.now().toIso8601String(),
      'user_id': uid,
      if (itemName.isNotEmpty) 'item_name': itemName, // denormalized
    });

    // remove from inventory
    await deleteInventoryItem(itemId);
  }

  /// Fetch only this user’s donations (prefer denormalized item_name)
  Future<List<Map<String, dynamic>>> fetchDonations() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('donations')
        .select('id, item_id, item_name, recipient_info, offered_at, inventory_items(name)')
        .eq('user_id', uid)
        .order('offered_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // Delete an inventory item by its id
  Future<void> deleteInventoryItem(String id) async {
    await client.from('inventory_items').delete().eq('id', id);
  }

  /// Delete a donation by its id
  Future<void> deleteDonation(String id) async {
    await client.from('donations').delete().eq('id', id);
  }
}
