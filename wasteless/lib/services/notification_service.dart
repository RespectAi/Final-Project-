import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/utils/notification_id_helper.dart';
import '../models/inventory_item.dart';

/// Service responsible for managing scheduled local notifications and expiry alerts.
class NotificationService {
  final FlutterLocalNotificationsPlugin _local;

  NotificationService(this._local);

  /// Rebuilds all scheduled expiry reminders from the provided inventory list.
  Future<void> rescheduleExpiryReminders(List<InventoryItem> items) async {
    if (kIsWeb) return;
    try {
      await _local.cancelAll();
    } catch (error) {
      debugPrint('Could not clear notifications before reschedule: $error');
    }

    for (final item in items) {
      try {
        await scheduleExpiryReminder(
          itemId: item.id,
          name: item.name,
          expiry: item.expiryDate,
          reminderDaysBefore: item.reminderDaysBefore,
          reminderHoursBefore: item.reminderHoursBefore,
        );
      } catch (error) {
        debugPrint('Could not restore reminder for ${item.id}: $error');
      }
    }
  }

  /// Schedules a one-time expiry reminder for an item.
  Future<void> scheduleExpiryReminder({
    required String itemId,
    required String name,
    required DateTime expiry,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
  }) async {
    if (kIsWeb) return;
    final notifyTime = expiry.subtract(
      Duration(days: reminderDaysBefore, hours: reminderHoursBefore),
    );
    if (!notifyTime.isAfter(DateTime.now())) return;

    try {
      await _local.zonedSchedule(
        notificationIdForItem(itemId),
        'Expiry Reminder',
        '$name expires on ${expiry.toLocal()}',
        tz.TZDateTime.from(notifyTime, tz.local),
        const NotificationDetails(
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
      );
    } catch (error) {
      debugPrint('Could not schedule expiry reminder for $itemId: $error');
    }
  }

  /// Cancels an existing notification for a given item id.
  Future<void> cancelReminder(String itemId) async {
    if (kIsWeb) return;
    try {
      await _local.cancel(notificationIdForItem(itemId));
    } catch (error) {
      debugPrint('Could not cancel notification for $itemId: $error');
    }
  }

  /// Cancels all scheduled local notifications.
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _local.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel all notifications: $error');
    }
  }
}
