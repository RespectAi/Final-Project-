// lib/services/supabase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class SupabaseService {
  final FlutterLocalNotificationsPlugin _local;
  final StreamController<void> _inventoryController = StreamController<void>.broadcast();
Stream<void> get onInventoryChanged => _inventoryController.stream;
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

  /// Fetch the full list of (pre‐seeded) categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await client.from('categories').select('id, name, icon_url, default_expiry_days').order('name');
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

  // User Management Methods

  /// Returns the current user's account id, creating the account row if missing
  Future<String> _getOrCreateAccountId() async {
    try {
      final uid = client.auth.currentUser!.id;
      // Try to fetch the account for this owner
      final existing = await client
          .from('accounts')
          .select('id')
          .eq('owner_id', uid)
          .maybeSingle();
      if (existing != null && existing['id'] != null) {
        return existing['id'] as String;
      }
      // Create if not found
      final created = await client
          .from('accounts')
          .insert({'owner_id': uid})
          .select('id')
          .single();
      return created['id'] as String;
    } catch (e) {
      debugPrint('Error ensuring account exists: $e');
      rethrow;
    }
  }

  /// Fetch local users for the current user's account
  Future<List<Map<String, dynamic>>> fetchLocalUsers() async {
    try {
      // Ensure the current user has an account row; create if missing
      final accountId = await _getOrCreateAccountId();
      
      // Then fetch local users for this account
      final data = await client
          .from('local_users')
          .select('id, name, created_at')
          .eq('account_id', accountId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Return empty list if tables don't exist yet
      debugPrint('Error fetching local users: $e');
      return [];
    }
  }

  /// Fetch fridge members for fridges the current user has access to
  Future<List<Map<String, dynamic>>> fetchFridgeMembers() async {
    try {
      final uid = client.auth.currentUser!.id;
      
      // First get the fridges the current user has access to
      final userFridges = await client
          .from('fridge_users')
          .select('fridge_id')
          .eq('user_id', uid);
      
      if (userFridges.isEmpty) return [];
      
      final fridgeIds = userFridges.map((f) => f['fridge_id']).toList();
      
      final data = await client
          .from('fridge_users')
          .select('''
            id,
            user_id,
            fridge_id,
            role,
            joined_at,
            profiles!fridge_users_user_id_fkey(full_name),
            fridges!fridge_users_fridge_id_fkey(name)
          ''')
          .inFilter('fridge_id', fridgeIds)
          .order('joined_at', ascending: false);
      
      // Transform the data to flatten the nested objects
      return List<Map<String, dynamic>>.from(data).map((item) {
        return {
          'id': item['id'],
          'user_id': item['user_id'],
          'fridge_id': item['fridge_id'],
          'role': item['role'],
          'joined_at': item['joined_at'],
          'user_name': item['profiles']?['full_name'] ?? 'Unknown User',
          'fridge_name': item['fridges']?['name'] ?? 'Unknown Fridge',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching fridge members: $e');
      return [];
    }
  }

  /// Fetch pending join requests for fridges the current user can manage
  Future<List<Map<String, dynamic>>> fetchPendingRequests() async {
    final uid = client.auth.currentUser!.id;
    
    // First get the fridges where the current user is an admin
    final adminFridges = await client
        .from('fridge_users')
        .select('fridge_id')
        .eq('user_id', uid)
        .eq('role', 'admin');
    
    if (adminFridges.isEmpty) return [];
    
    final fridgeIds = adminFridges.map((f) => f['fridge_id']).toList();
    
    final data = await client
        .from('fridge_requests')
        .select('''
          id,
          requester_id,
          fridge_id,
          status,
          message,
          created_at,
          profiles!fridge_requests_requester_id_fkey(full_name),
          fridges!fridge_requests_fridge_id_fkey(name)
        ''')
        .eq('status', 'pending')
        .inFilter('fridge_id', fridgeIds)
        .order('created_at', ascending: false);
    
    // Transform the data to flatten the nested objects
    return List<Map<String, dynamic>>.from(data).map((item) {
      return {
        'id': item['id'],
        'requester_id': item['requester_id'],
        'fridge_id': item['fridge_id'],
        'status': item['status'],
        'message': item['message'],
        'created_at': item['created_at'],
        'requester_name': item['profiles']?['full_name'] ?? 'Unknown User',
        'fridge_name': item['fridges']?['name'] ?? 'Unknown Fridge',
      };
    }).toList();
  }

  /// Fetch fridges the current user has access to
  Future<List<Map<String, dynamic>>> fetchMyFridges() async {
    try {
      final uid = client.auth.currentUser!.id;
      
      final data = await client
          .from('fridge_users')
          .select('''
            fridge_id,
            role,
            joined_at,
            fridges!fridge_users_fridge_id_fkey(
              id,
              name,
              location,
              created_at
            )
          ''')
          .eq('user_id', uid)
          .order('joined_at', ascending: false);
      
      // Transform the data to flatten the nested objects
      return List<Map<String, dynamic>>.from(data).map((item) {
        final fridge = item['fridges'];
        return {
          'id': fridge['id'],
          'name': fridge['name'],
          'location': fridge['location'],
          'created_at': fridge['created_at'],
          'role': item['role'],
          'joined_at': item['joined_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching my fridges: $e');
      return [];
    }
  }

  /// Create a local user for the current user's account
  Future<void> createLocalUser(String name) async {
    try {
      // Ensure the current user has an account row; create if missing
      final accountId = await _getOrCreateAccountId();
      
      // Create the local user
      await client.from('local_users').insert({
        'name': name,
        'account_id': accountId,
      });
    } catch (e) {
      debugPrint('Error creating local user: $e');
      rethrow;
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a local user with password (hashed on client)
  Future<void> createLocalUserWithPassword(String name, String password) async {
    try {
      final accountId = await _getOrCreateAccountId();
      await client.from('local_users').insert({
        'name': name,
        'account_id': accountId,
        'password_hash': _hashPassword(password),
      });
    } catch (e) {
      debugPrint('Error creating local user with password: $e');
      rethrow;
    }
  }

  /// Update a local user's name
  Future<void> updateLocalUser(String userId, String newName) async {
    try {
      await client
          .from('local_users')
          .update({'name': newName})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error updating local user: $e');
      rethrow;
    }
  }

  /// Optionally update a local user's password
  Future<void> updateLocalUserPassword(String userId, String newPassword) async {
    try {
      await client
          .from('local_users')
          .update({'password_hash': _hashPassword(newPassword)})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error updating local user password: $e');
      rethrow;
    }
  }

  /// Delete a local user
  Future<void> deleteLocalUser(String userId) async {
    try {
      await client.from('local_users').delete().eq('id', userId);
    } catch (e) {
      debugPrint('Error deleting local user: $e');
      rethrow;
    }
  }

  /// Promote a user to admin in a specific fridge
  Future<void> promoteUser(String userId, String fridgeId) async {
    try {
      await client
          .from('fridge_users')
          .update({'role': 'admin'})
          .eq('user_id', userId)
          .eq('fridge_id', fridgeId);
    } catch (e) {
      debugPrint('Error promoting user: $e');
      rethrow;
    }
  }

  /// Demote a user from admin to regular user in a specific fridge
  Future<void> demoteUser(String userId, String fridgeId) async {
    try {
      await client
          .from('fridge_users')
          .update({'role': 'user'})
          .eq('user_id', userId)
          .eq('fridge_id', fridgeId);
    } catch (e) {
      debugPrint('Error demoting user: $e');
      rethrow;
    }
  }

  /// Remove a user from a fridge
  Future<void> removeUserFromFridge(String userId, String fridgeId) async {
    try {
      await client
          .from('fridge_users')
          .delete()
          .eq('user_id', userId)
          .eq('fridge_id', fridgeId);
    } catch (e) {
      debugPrint('Error removing user from fridge: $e');
      rethrow;
    }
  }

  /// Approve a join request
  Future<void> approveJoinRequest(String requestId) async {
    try {
      final request = await client
          .from('fridge_requests')
          .select('requester_id, fridge_id')
          .eq('id', requestId)
          .single();
      
      // Add user to fridge
      await client.from('fridge_users').insert({
        'user_id': request['requester_id'],
        'fridge_id': request['fridge_id'],
        'role': 'user',
      });
      
      // Update request status
      await client
          .from('fridge_requests')
          .update({'status': 'approved'})
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error approving join request: $e');
      rethrow;
    }
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId) async {
    try {
      await client
          .from('fridge_requests')
          .update({'status': 'rejected'})
          .eq('id', requestId);
    } catch (e) {
      debugPrint('Error rejecting join request: $e');
      rethrow;
    }
  }

  // Active local user context
  String? activeLocalUserId;
  String? activeLocalUserName;

  /// Verify local user password and set active local user
  Future<bool> verifyAndSelectLocalUser(String localUserId, String password) async {
    try {
      final row = await client
          .from('local_users')
          .select('id, name, password_hash')
          .eq('id', localUserId)
          .maybeSingle();
      if (row == null) return false;
      final ok = row['password_hash'] == _hashPassword(password);
      if (ok) {
        activeLocalUserId = row['id'] as String;
        activeLocalUserName = row['name'] as String?;
      }
      return ok;
    } catch (e) {
      debugPrint('Error verifying local user: $e');
      return false;
    }
  }

}
