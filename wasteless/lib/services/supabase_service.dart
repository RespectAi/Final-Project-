import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SupabaseService {
  
  // ← add this field
  final FlutterLocalNotificationsPlugin _local;

  // ← modify the constructor to accept it
  SupabaseService(this._local);

  /// Initialize Supabase – replace with your own URL & anon key.
  static Future<SupabaseService> init(
    FlutterLocalNotificationsPlugin local,
  ) async {
    await Supabase.initialize(
      url: 'https://doxhjonwexqsrksakpqo.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
    );
    return SupabaseService(local);
  }

  final SupabaseClient client = Supabase.instance.client;

  /// Fetch only this user’s inventory
  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('inventory_items')
        .select()
        .eq('user_id', uid) // ← filter by user
        .order('expiry_date', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch only this user’s waste logs
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('waste_logs')
        .select(
          'id, item_id, quantity, reason, logged_at, inventory_items(name)',
        )
        .eq('user_id', uid) // ← filter
        .order('logged_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Insert a new inventory item FOR THIS USER
  Future<void> addItem(
    {required String name, required DateTime expiry, required int quantity,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
  }) 
  async {
    final uid = client.auth.currentUser!.id;
    await client.from('inventory_items').insert({
      'name': name,
      'expiry_date': expiry.toIso8601String(),
      'quantity': quantity,
      'reminder_days_before': reminderDaysBefore,
      'reminder_hours_before': reminderHoursBefore,
      'user_id': uid, // ← stamp with user
    });

    // 2) schedule notification
    final notifyTime = expiry.subtract(
      Duration(days: reminderDaysBefore, hours: reminderHoursBefore),
    );
    await _local.zonedSchedule(
      name.hashCode, // unique ID per item
      'Expiry Reminder',
      '$name expires on ${expiry.toLocal()}',
      tz.TZDateTime.from(notifyTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'Expiry Alerts',
          channelDescription: 'Reminders for inventory expiry',
        ),
        iOS:DarwinNotificationDetails(),
      ),
       // **These two are now required**:
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime
,
    );
  }

  /// Log waste FOR THIS USER
  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final uid = client.auth.currentUser!.id;
    final entry = {
      'item_id': itemId,
      'quantity': qty,
      'logged_at': DateTime.now().toIso8601String(),
      'user_id': uid, // ← stamp
      if (reason?.isNotEmpty ?? false) 'reason': reason,
    };
    await client.from('waste_logs').insert(entry);
    // remove from inventory
    await deleteInventoryItem(itemId);
  }

  /// Delete a waste log by its id
  Future<void> deleteWasteLog(String id) async {
  await client
    .from('waste_logs')
    .delete()
    .eq('id', id);
  }

  /// Offer a donation FOR THIS USER
  Future<void> offerDonation(String itemId, String recipientInfo) async {
    final uid = client.auth.currentUser!.id;
    await client.from('donations').insert({
      'item_id': itemId,
      'recipient_info': recipientInfo,
      'offered_at': DateTime.now().toIso8601String(),
      'user_id': uid, // ← stamp
    });
    // remove from inventory
    await deleteInventoryItem(itemId);
  }

  /// Fetch only this user’s donations
  Future<List<Map<String, dynamic>>> fetchDonations() async {
    final uid = client.auth.currentUser!.id;
    final data = await client
        .from('donations')
        .select(
          'id, item_id, recipient_info, offered_at, inventory_items(name)',
        )
        .eq('user_id', uid) // ← filter
        .order('offered_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  // Delete an inventory item by its id
  Future deleteInventoryItem(String id) async {
    await client.from('inventory_items').delete().eq('id', id);
  }
  
  /// Delete a donation by its id
  Future<void> deleteDonation(String id) async {
    await client.from('donations').delete().eq('id', id);
  }

}
