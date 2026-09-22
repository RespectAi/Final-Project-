import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/inventory_item.dart';
import 'notification_service.dart';

/// Service managing food inventory items, categories, and item mutations.
class InventoryService {
  final SupabaseClient client;
  final NotificationService notificationService;
  final Future<String?> Function()? getDefaultFridgeId;
  final Future<void> Function()? ensureItemFridgeAssigned;
  final String? Function()? getActiveLocalUserName;

  final StreamController<void> _inventoryController = StreamController<void>.broadcast();
  Stream<void> get onInventoryChanged => _inventoryController.stream;

  InventoryService({
    required this.client,
    required this.notificationService,
    this.getDefaultFridgeId,
    this.ensureItemFridgeAssigned,
    this.getActiveLocalUserName,
  });

  void notifyInventoryChanged() {
    _inventoryController.add(null);
  }

  /// Fetch only this user’s inventory as raw Maps
  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

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
         fridge_id,
         inventory_item_categories (
          category_id,
          categories ( id, name, icon_url )
      )
    ''')
        .eq('user_id', uid)
        .order('expiry_date', ascending: true);
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch only this user’s inventory as strongly-typed InventoryItem models
  Future<List<InventoryItem>> fetchInventoryItems() async {
    final raw = await fetchInventory();
    return raw.map((m) => InventoryItem.fromMap(m)).toList();
  }

  /// Fetch the full list of categories as raw Maps
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await client
        .from('categories')
        .select('id, name, icon_url, default_expiry_days')
        .order('name');
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch categories as strongly-typed Category models
  Future<List<Category>> fetchCategoryModels() async {
    final raw = await fetchCategories();
    return raw.map((m) => Category.fromMap(m)).toList();
  }

  /// Fetch inventory filtered by a category ID
  Future<List<Map<String, dynamic>>> fetchInventoryByCategory(String categoryId) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

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
         fridge_id,
         inventory_item_categories!inner(
            category_id,
            categories ( id, name, icon_url )
         )
        ''')
        .eq('user_id', uid)
        .eq('inventory_item_categories.category_id', categoryId)
        .order('expiry_date', ascending: true);
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a single inventory item and schedule reminder
  Future<void> addItem({
    required String name,
    required DateTime expiry,
    required int quantity,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
    required List<String> categoryIds,
    String? fridgeId,
  }) async {
    final uid = client.auth.currentUser!.id;
    final resolvedFridgeId = fridgeId ?? (getDefaultFridgeId != null ? await getDefaultFridgeId!() : null);

    // 1) insert item
    final res = await client
        .from('inventory_items')
        .insert({
          'name': name,
          'expiry_date': expiry.toIso8601String(),
          'quantity': quantity,
          'reminder_days_before': reminderDaysBefore,
          'reminder_hours_before': reminderHoursBefore,
          'user_id': uid,
          if (resolvedFridgeId != null) 'fridge_id': resolvedFridgeId,
        })
        .select('id')
        .single();
    final itemId = res['id'] as String;

    // 2) link to categories
    if (categoryIds.isNotEmpty) {
      final links = categoryIds.map((cid) => {
        'inventory_item_id': itemId,
        'category_id': cid,
      }).toList();
      await client.from('inventory_item_categories').insert(links);
    }

    // 3) schedule notification
    await notificationService.scheduleExpiryReminder(
      itemId: itemId,
      name: name,
      expiry: expiry,
      reminderDaysBefore: reminderDaysBefore,
      reminderHoursBefore: reminderHoursBefore,
    );

    notifyInventoryChanged();
  }

  /// Add multiple items in bulk
  Future<void> addMultipleItems(List<Map<String, dynamic>> items, [String? defaultFridgeId]) async {
    final uid = client.auth.currentUser!.id;
    final resolvedFridgeId = defaultFridgeId ?? (getDefaultFridgeId != null ? await getDefaultFridgeId!() : null);

    for (final itemData in items) {
      final expiry = itemData['expiry'] as DateTime;
      final reminderDaysBefore = itemData['reminderDaysBefore'] as int;
      final reminderHoursBefore = itemData['reminderHoursBefore'] as int;
      final itemFridgeId = itemData['fridgeId'] as String? ?? resolvedFridgeId;

      final res = await client
          .from('inventory_items')
          .insert({
            'name': itemData['name'],
            'expiry_date': expiry.toIso8601String(),
            'quantity': itemData['quantity'],
            'reminder_days_before': reminderDaysBefore,
            'reminder_hours_before': reminderHoursBefore,
            'user_id': uid,
            if (itemFridgeId != null) 'fridge_id': itemFridgeId,
          })
          .select('id')
          .single();
      final itemId = res['id'] as String;

      final categoryIds = itemData['categoryIds'] as List<String>;
      if (categoryIds.isNotEmpty) {
        final links = categoryIds.map((cid) => {
          'inventory_item_id': itemId,
          'category_id': cid,
        }).toList();
        await client.from('inventory_item_categories').insert(links);
      }

      await notificationService.scheduleExpiryReminder(
        itemId: itemId,
        name: itemData['name'] as String,
        expiry: expiry,
        reminderDaysBefore: reminderDaysBefore,
        reminderHoursBefore: reminderHoursBefore,
      );
    }

    notifyInventoryChanged();
  }

  /// Update item quantity directly
  Future<void> updateItemQuantity(String itemId, int newQty) async {
    if (newQty <= 0) {
      await deleteInventoryItem(itemId);
    } else {
      await client
          .from('inventory_items')
          .update({'quantity': newQty})
          .eq('id', itemId);
      notifyInventoryChanged();
    }
  }

  /// Consume a specific quantity of an item
  Future<void> consumeItem(String itemId, [int qty = 1]) async {
    try {
      final inv = await client
          .from('inventory_items')
          .select('quantity')
          .eq('id', itemId)
          .single();
      final currentQty = (inv['quantity'] as int?) ?? 1;
      final remaining = currentQty - qty;
      if (remaining <= 0) {
        await deleteInventoryItem(itemId);
      } else {
        await updateItemQuantity(itemId, remaining);
      }
    } catch (e) {
      debugPrint('Error consuming item: $e');
      rethrow;
    }
  }

  /// Delete an inventory item and cancel its reminder
  Future<void> deleteInventoryItem(String id) async {
    await client.from('inventory_items').delete().eq('id', id);
    await notificationService.cancelReminder(id);
    notifyInventoryChanged();
  }

  /// Re-sync all expiry reminders from existing inventory items
  Future<void> rescheduleExpiryReminders() async {
    final items = await fetchInventoryItems();
    await notificationService.rescheduleExpiryReminders(items);
  }

  /// Fetch items belonging to a fridge
  Future<List<Map<String, dynamic>>> fetchFridgeItems(String fridgeId) async {
    try {
      if (ensureItemFridgeAssigned != null) {
        await ensureItemFridgeAssigned!();
      }

      final currentUid = client.auth.currentUser?.id;
      final data = await client
          .from('inventory_items')
          .select('id, name, expiry_date, quantity, user_id, created_at')
          .eq('fridge_id', fridgeId)
          .order('expiry_date', ascending: true);

      final list = (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final activeUserName = getActiveLocalUserName != null ? getActiveLocalUserName!() : null;

      return list.map((it) {
        final ownerId = it['user_id'] as String?;
        final isOwner = ownerId != null && ownerId == currentUid;
        final ownerName = isOwner ? (activeUserName ?? 'You') : 'Member';
        return {
          ...it,
          'user_name': ownerName,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching fridge items: $e');
      return [];
    }
  }

  void dispose() {
    _inventoryController.close();
  }
}
