// lib/services/supabase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch the full list of (pre‐seeded) categories
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await client.from('categories').select('id, name, icon_url, default_expiry_days').order('name');
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch only this user’s waste logs (prefer denormalized item_name, fallback to join)
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final uid = client.auth.currentUser!.id;
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
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
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
    try {
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
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
      if (fridge == null) return null; // Skip if fridge was deleted
      return {
        'id': fridge['id'],
        'name': fridge['name'],
        'location': fridge['location'],
        'created_at': fridge['created_at'],
        'role': item['role'],
        'joined_at': item['joined_at'],
      };
    }).where((item) => item != null).cast<Map<String, dynamic>>().toList();
  } catch (e) {
    debugPrint('Error fetching my fridges: $e');
    return [];
  }
}

  /// Fetch fridges connected to the current user (via membership or items)
  /// Fetch fridges connected to the current user (via membership or items)
Future<List<Map<String, dynamic>>> fetchConnectedFridges() async {
  try {
    final uid = client.auth.currentUser!.id;
    
    // Get fridges where user is a member
    final memberFridges = await client
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
    
    // Transform the data
    final result = <Map<String, dynamic>>[];
    for (final item in memberFridges) {
      final fridge = item['fridges'];
      if (fridge != null) {
        result.add({
          'id': fridge['id'],
          'name': fridge['name'],
          'location': fridge['location'],
          'created_at': fridge['created_at'],
          'role': item['role'],
          'joined_at': item['joined_at'],
        });
      }
    }
    
    // Also get fridges owned by the user (in case they're not in fridge_users yet)
    final ownedFridges = await client
        .from('fridges')
        .select('id, name, location, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    
    // Add owned fridges that aren't already in the list
    for (final fridge in ownedFridges) {
      final fridgeId = fridge['id'];
      if (!result.any((f) => f['id'] == fridgeId)) {
        result.add({
          'id': fridge['id'],
          'name': fridge['name'],
          'location': fridge['location'],
          'created_at': fridge['created_at'],
          'role': 'admin', // Owner is always admin
          'joined_at': fridge['created_at'],
        });
      }
    }
    
    return result;
  } catch (e) {
    debugPrint('Error fetching connected fridges: $e');
    return [];
  }
}

  /// Fetch items in a given fridge
  Future<List<Map<String, dynamic>>> fetchFridgeItems(String fridgeId) async {
    try {
      final data = await client
          .from('inventory_items')
          .select('id, name, expiry_date, quantity, user_id, created_at')
          .eq('fridge_id', fridgeId)
          .order('expiry_date', ascending: true);
      try {
        return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching fridge items: $e');
      return [];
    }
  }

  /// Fetch members for a specific fridge
  Future<List<Map<String, dynamic>>> fetchFridgeMembersForFridge(String fridgeId) async {
    try {
      final data = await client
          .from('fridge_users')
          .select('id, user_id, role, joined_at, profiles!fridge_users_user_id_fkey(full_name)')
          .eq('fridge_id', fridgeId)
          .order('joined_at', ascending: true);
      try {
        final list = (data as List).map((entry) {
          final m = Map<String, dynamic>.from(entry as Map);
        return {
          'id': m['id'],
          'user_id': m['user_id'],
          'role': m['role'],
          'joined_at': m['joined_at'],
          'user_name': m['profiles']?['full_name'] ?? 'Unknown',
        };
        }).toList();
        return list;
      } catch (_) {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching fridge members: $e');
      return [];
    }
  }

  /// Fetch pending requests for a specific fridge (admin view)
  Future<List<Map<String, dynamic>>> fetchPendingRequestsForFridge(String fridgeId) async {
    try {
      final data = await client
          .from('fridge_requests')
          .select('id, requester_id, fridge_id, status, message, created_at, profiles!fridge_requests_requester_id_fkey(full_name)')
          .eq('fridge_id', fridgeId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      try {
        final list = (data as List).map((entry) {
          final r = Map<String, dynamic>.from(entry as Map);
          return {
            'id': r['id'],
            'requester_id': r['requester_id'],
            'status': r['status'],
            'message': r['message'],
            'created_at': r['created_at'],
            'requester_name': r['profiles']?['full_name'] ?? 'Unknown',
          };
        }).toList();
        return list;
      } catch (_) {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching fridge requests: $e');
      return [];
    }
  }

/// Regenerate fridge code via RPC or direct update
Future<String?> regenerateFridgeCode(String fridgeId) async {
  try {
    // Try RPC first if it exists
    try {
      final res = await client.rpc('regenerate_fridge_code', params: {'p_fridge': fridgeId});
      if (res != null) {
        if (res is String) return res;
        if (res is Map && res.containsKey('code')) return res['code']?.toString();
        return res.toString();
      }
    } catch (rpcError) {
      debugPrint('RPC not available, generating code locally: $rpcError');
    }
    
    // Fallback: generate a unique code locally
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = '${fridgeId.substring(0, 3).toUpperCase()}${timestamp.toString().substring(7, 13)}';
    
    // Update the fridge with the new code
    await client
        .from('fridges')
        .update({'code': code})
        .eq('id', fridgeId);
    
    debugPrint('Generated fridge code: $code for fridge: $fridgeId');
    return code;
  } catch (e) {
    debugPrint('Error regenerating fridge code: $e');
    return null;
  }
}

  /// Helper to return current authenticated user's id
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  /// Create a new fridge (owner becomes admin)
  Future<String?> createFridge({String? name, String? location}) async {
    try {
      final uid = client.auth.currentUser!.id;
      final res = await client.from('fridges').insert({
        'user_id': uid,
        if (name != null) 'name': name,
        if (location != null) 'location': location,
      }).select('id').single();
      // id may be returned as int or string depending on DB setup; normalize to String
      String? id;
      try {
        id = (res['id']).toString();
      } catch (_) {
        id = null;
      }
      // add owner as fridge_user
      if (id != null) {
        try {
          await client.from('fridge_users').insert({'user_id': uid, 'fridge_id': id, 'role': 'admin'});
        } catch (_) {
          // ignore duplicate membership
        }
        debugPrint('Created fridge id=$id for user=$uid');
      }
      return id;
    } catch (e) {
      debugPrint('Error creating fridge: $e');
      return null;
    }
  }

  /// Delete a fridge (admin only)
/// Delete a fridge (admin/owner only). Removes dependent rows first to avoid FK constraint errors.
Future<bool> deleteFridge(String fridgeId) async {
  try {
    final uid = client.auth.currentUser!.id;

    // Find fridge row to verify ownership/admin
    final fridgeRow = await client.from('fridges').select('user_id').eq('id', fridgeId).maybeSingle();
    if (fridgeRow == null) {
      debugPrint('deleteFridge: fridge not found $fridgeId');
      return false;
    }

    final ownerId = fridgeRow['user_id']?.toString();

    // Check membership role (admin) OR owner of fridge
    final membership = await client
        .from('fridge_users')
        .select('role')
        .eq('user_id', uid)
        .eq('fridge_id', fridgeId)
        .maybeSingle();

    final bool isAdmin = (membership != null && membership['role'] == 'admin') || (ownerId != null && ownerId == uid);

    if (!isAdmin) {
      debugPrint('deleteFridge: user is not admin/owner of fridge $fridgeId');
      return false;
    }

    // Delete dependent rows first to avoid FK constraints
    // Adjust these as per your schema (remove/keep any related tables you need)
    await client.from('fridge_requests').delete().eq('fridge_id', fridgeId);
    await client.from('fridge_users').delete().eq('fridge_id', fridgeId);
    await client.from('inventory_items').delete().eq('fridge_id', fridgeId);
    // Optionally remove donations or other linked data:
    // await client.from('donations').delete().eq('fridge_id', fridgeId);

    // Now delete the fridge row
    await client.from('fridges').delete().eq('id', fridgeId);

    debugPrint('deleteFridge: deleted fridge $fridgeId');

    return true;
  } catch (e) {
    debugPrint('Error deleting fridge: $e');
    return false;
  }
}

/// Join a fridge immediately using code
/// Join a fridge immediately using code (instrumented + tolerant)
Future<Map<String, dynamic>> joinFridgeWithCode(String code) async {
  try {
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('joinFridgeWithCode: no authenticated user');
      return {'success': false, 'message': 'Not authenticated'};
    }

    debugPrint('Attempting to join fridge with code: $code (uid=$uid)');

    // Try RPC path first
    try {
      final res = await client.rpc('join_fridge_with_code', params: {'p_code': code});
      debugPrint('RPC result: $res');
      if (res != null && res is Map && res['status'] == 'ok') {
        final fridgeId = res['fridge_id']?.toString();
        String fridgeName = 'Unknown Fridge';
        if (fridgeId != null) {
          try {
            final fridgeData = await client.from('fridges').select('name').eq('id', fridgeId).maybeSingle();
            fridgeName = fridgeData?['name'] ?? fridgeName;
          } catch (e) {
            debugPrint('Error reading fridge name after RPC: $e');
          }
        }
        return {'success': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
      }
    } catch (rpcError) {
      debugPrint('RPC unavailable or failed (ok to ignore if you don\'t use RPC): $rpcError');
    }

    // Fallback: find fridge by code (case-insensitive trim)
    final trimmed = code.trim();
    final fridgeResult = await client
        .from('fridges')
        .select('id, name')
        .ilike('code', trimmed) // case-insensitive match
        .maybeSingle();

    debugPrint('fridgeResult (by code): $fridgeResult');

    if (fridgeResult == null) {
      return {'success': false, 'message': 'Invalid fridge code'};
    }

    final fridgeId = fridgeResult['id']?.toString();
    final fridgeName = (fridgeResult['name'] as String?) ?? 'Unknown Fridge';

    if (fridgeId == null) {
      return {'success': false, 'message': 'Invalid fridge data'};
    }

    // Check if membership already exists
    final existingMembership = await client
        .from('fridge_users')
        .select('id, role')
        .eq('user_id', uid)
        .eq('fridge_id', fridgeId)
        .maybeSingle();

    debugPrint('existingMembership: $existingMembership');

    if (existingMembership != null) {
      return {'success': true, 'alreadyMember': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
    }

    // Insert membership
    dynamic insertRes;
    try {
      insertRes = await client.from('fridge_users').insert({
        'user_id': uid,
        'fridge_id': fridgeId,
        'role': 'user',
        'joined_at': DateTime.now().toIso8601String(),
      }).select('id'); // don't use .single() in case some clients return list
      debugPrint('raw insertRes: $insertRes');
    } catch (e) {
      debugPrint('Insert into fridge_users failed with exception: $e');
      return {'success': false, 'message': 'Failed to join (insert failed): $e'};
    }

    // Accept lists or single maps returned by different client versions
    Map<String, dynamic>? insertedRow;
    try {
      if (insertRes == null) {
        insertedRow = null;
      } else if (insertRes is List && insertRes.isNotEmpty) {
        insertedRow = Map<String, dynamic>.from(insertRes.first as Map);
      } else if (insertRes is Map) {
        // insertedRow = Map<String, dynamic>.from(insertRes as Map);
      } else {
        debugPrint('Unexpected insertRes shape: ${insertRes.runtimeType} -> $insertRes');
        insertedRow = null;
      }
    } catch (e) {
      debugPrint('Error parsing insertRes: $e (raw: $insertRes)');
      insertedRow = null;
    }

    debugPrint('parsed insertedRow: $insertedRow');

    if (insertedRow == null || insertedRow['id'] == null) {
      // There are cases where insert returns [] or {} when RLS forbids action.
      // Query DB to check whether a membership now exists (best-effort)
      final check = await client
          .from('fridge_users')
          .select('id')
          .eq('user_id', uid)
          .eq('fridge_id', fridgeId)
          .maybeSingle();
      debugPrint('post-insert check: $check');
      if (check == null) {
        return {'success': false, 'message': 'Failed to join fridge (no membership created). Check RLS / permissions.'};
      }
    }

    // Success — return fridge id & name
    return {'success': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
  } catch (e) {
    debugPrint('Unexpected error in joinFridgeWithCode: $e');
    return {'success': false, 'message': 'Error: ${e.toString()}'};
  }
}



  /// Request to join a fridge (creates fridge_requests row)
  Future<bool> requestToJoinFridge(String fridgeId, String message) async {
    try {
      final uid = client.auth.currentUser!.id;
      await client.from('fridge_requests').insert({
        'requester_id': uid,
        'fridge_id': fridgeId,
        'message': message,
      });
      return true;
    } catch (e) {
      debugPrint('Error requesting to join fridge: $e');
      return false;
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

  /// Load saved user context from local storage
  Future<void> loadSavedUserContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString('active_local_user_id');
      final savedUserName = prefs.getString('active_local_user_name');
      final savedIsAdmin = prefs.getBool('is_admin_mode') ?? false;
      
      if (savedUserId != null && savedUserName != null) {
        activeLocalUserId = savedUserId;
        activeLocalUserName = savedUserName;
        _isAdminMode = false;
      } else if (savedIsAdmin) {
        _isAdminMode = true;
        activeLocalUserId = null;
        activeLocalUserName = null;
      }
    } catch (e) {
      debugPrint('Error loading saved user context: $e');
    }
  }

  /// Save user context to local storage
  Future<void> saveUserContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (activeLocalUserId != null && activeLocalUserName != null) {
        await prefs.setString('active_local_user_id', activeLocalUserId!);
        await prefs.setString('active_local_user_name', activeLocalUserName!);
        await prefs.setBool('is_admin_mode', false);
      } else if (_isAdminMode) {
        await prefs.setBool('is_admin_mode', true);
        await prefs.remove('active_local_user_id');
        await prefs.remove('active_local_user_name');
      }
    } catch (e) {
      debugPrint('Error saving user context: $e');
    }
  }

  /// Clear saved user context
  Future<void> clearUserContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_local_user_id');
      await prefs.remove('active_local_user_name');
      await prefs.remove('is_admin_mode');
    } catch (e) {
      debugPrint('Error clearing user context: $e');
    }
  }

  // Active local user context
  String? activeLocalUserId;
  String? activeLocalUserName;
  bool _isAdminMode = false;

  bool get isAdminMode => _isAdminMode;

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
        _isAdminMode = false;
        await saveUserContext();
      }
      return ok;
    } catch (e) {
      debugPrint('Error verifying local user: $e');
      return false;
    }
  }

  /// Set admin mode and clear local user context
  Future<void> setAdminMode() async {
    _isAdminMode = true;
    activeLocalUserId = null;
    activeLocalUserName = null;
    await saveUserContext();
  }

  /// Check if account has any local users
  Future<bool> hasLocalUsers() async {
    try {
      final accountId = await _getOrCreateAccountId();
      final result = await client
          .from('local_users')
          .select('id')
          .eq('account_id', accountId)
          .limit(1);
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking for local users: $e');
      return false;
    }
  }
 
 Future<Map<String, dynamic>?> fetchFridgeById(String fridgeId) async {
  try {
    final f = await client.from('fridges').select('id, name, location, created_at, user_id').eq('id', fridgeId).maybeSingle();
    if (f == null) return null;
    return Map<String, dynamic>.from(f as Map);
  } catch (e) {
    debugPrint('Error fetching fridge by id: $e');
    return null;
  }
 }

 Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'wasteless://reset',
      // redirectTo: 'http://localhost:64055'
      // or a deep link if mobile
    );
  }

}

