import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fridge.dart';
import '../models/fridge_member.dart';
import '../models/join_request.dart';

/// Service managing fridges, fridge membership, roles, and join requests.
class FridgeService {
  final SupabaseClient client;

  FridgeService({required this.client});

  String? get currentUserId => client.auth.currentUser?.id;

  /// Fetch fridges the current user has access to
  Future<List<Map<String, dynamic>>> fetchMyFridges() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];

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

      return List<Map<String, dynamic>>.from(data).map((item) {
        final fridge = item['fridges'];
        if (fridge == null) return null;
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

  /// Fetch fridges the current user has access to as typed Fridge models
  Future<List<Fridge>> fetchMyFridgeModels() async {
    final raw = await fetchMyFridges();
    return raw.map((m) => Fridge.fromMap(m)).toList();
  }

  /// Fetch fridges connected to the current user (via membership or ownership)
  Future<List<Map<String, dynamic>>> fetchConnectedFridges() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];

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
              created_at,
              code
            )
          ''')
          .eq('user_id', uid)
          .order('joined_at', ascending: false);

      final result = <Map<String, dynamic>>[];
      for (final item in memberFridges) {
        final fridge = item['fridges'];
        if (fridge != null) {
          result.add({
            'id': fridge['id'],
            'name': fridge['name'],
            'location': fridge['location'],
            'created_at': fridge['created_at'],
            'code': fridge['code'],
            'role': item['role'],
            'joined_at': item['joined_at'],
          });
        }
      }

      final ownedFridges = await client
          .from('fridges')
          .select('id, name, location, created_at, code')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      for (final fridge in ownedFridges) {
        final fridgeId = fridge['id'];
        if (!result.any((f) => f['id'] == fridgeId)) {
          result.add({
            'id': fridge['id'],
            'name': fridge['name'],
            'location': fridge['location'],
            'created_at': fridge['created_at'],
            'code': fridge['code'],
            'role': 'admin',
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

  /// Get default/primary fridge ID for current user
  Future<String?> getDefaultFridgeId() async {
    try {
      final fridges = await fetchConnectedFridges();
      if (fridges.isNotEmpty) {
        return fridges.first['id']?.toString();
      }
    } catch (e) {
      debugPrint('Error getting default fridge: $e');
    }
    return null;
  }

  /// Backfill items with null fridge_id to user's primary fridge
  Future<void> ensureItemFridgeAssigned() async {
    try {
      final defaultFridgeId = await getDefaultFridgeId();
      if (defaultFridgeId == null) return;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      await client
          .from('inventory_items')
          .update({'fridge_id': defaultFridgeId})
          .eq('user_id', uid)
          .isFilter('fridge_id', null);
    } catch (e) {
      debugPrint('Error backfilling fridge items: $e');
    }
  }

  /// Fetch all members across user's fridges
  Future<List<Map<String, dynamic>>> fetchFridgeMembers() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];

      final userFridges = await client
          .from('fridge_users')
          .select('fridge_id')
          .eq('user_id', uid);

      if (userFridges.isEmpty) return [];

      final fridgeIds = (userFridges as List)
          .map((item) => item['fridge_id'] as String)
          .toList();

      final data = await client
          .from('fridge_users')
          .select('''
            id,
            user_id,
            fridge_id,
            role,
            joined_at,
            fridges(name)
          ''')
          .inFilter('fridge_id', fridgeIds)
          .order('joined_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(data);
      final userIds = items.map((m) => m['user_id'] as String?).whereType<String>().toSet().toList();

      final userNames = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final profilesData = await client
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', userIds);
          for (final p in profilesData) {
            final pid = p['id']?.toString();
            final name = p['full_name']?.toString();
            if (pid != null && name != null && name.isNotEmpty) {
              userNames[pid] = name;
            }
          }
        } catch (_) {}

        try {
          final localData = await client
              .from('local_users')
              .select('id, name')
              .inFilter('id', userIds);
          for (final l in localData) {
            final lid = l['id']?.toString();
            final name = l['name']?.toString();
            if (lid != null && name != null && name.isNotEmpty) {
              userNames.putIfAbsent(lid, () => name);
            }
          }
        } catch (_) {}
      }

      return items.map((item) {
        final userId = item['user_id'] as String?;
        return {
          'id': item['id'],
          'user_id': userId,
          'fridge_id': item['fridge_id'],
          'role': item['role'],
          'joined_at': item['joined_at'],
          'user_name': (userId != null && userNames.containsKey(userId)) ? userNames[userId] : 'Member',
          'fridge_name': item['fridges']?['name'] ?? 'Unknown Fridge',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching fridge members: $e');
      return [];
    }
  }

  /// Fetch all members as typed FridgeMember models
  Future<List<FridgeMember>> fetchFridgeMemberModels() async {
    final raw = await fetchFridgeMembers();
    return raw.map((m) => FridgeMember.fromMap(m)).toList();
  }

  /// Fetch members for a specific fridge
  Future<List<Map<String, dynamic>>> fetchFridgeMembersForFridge(String fridgeId) async {
    try {
      final data = await client
          .from('fridge_users')
          .select('id, user_id, role, joined_at')
          .eq('fridge_id', fridgeId)
          .order('joined_at', ascending: true);

      final items = List<Map<String, dynamic>>.from(data);
      final userIds = items.map((m) => m['user_id'] as String?).whereType<String>().toSet().toList();

      final userNames = <String, String>{};
      if (userIds.isNotEmpty) {
        try {
          final profiles = await client.from('profiles').select('id, full_name').inFilter('id', userIds);
          for (final p in profiles) {
            final id = p['id']?.toString();
            final name = p['full_name']?.toString();
            if (id != null && name != null && name.isNotEmpty) userNames[id] = name;
          }
        } catch (_) {}
        try {
          final locals = await client.from('local_users').select('id, name').inFilter('id', userIds);
          for (final l in locals) {
            final id = l['id']?.toString();
            final name = l['name']?.toString();
            if (id != null && name != null && name.isNotEmpty) userNames.putIfAbsent(id, () => name);
          }
        } catch (_) {}
      }

      return items.map((m) {
        final uid = m['user_id'] as String?;
        return {
          'id': m['id'],
          'user_id': uid,
          'role': m['role'],
          'joined_at': m['joined_at'],
          'user_name': (uid != null && userNames.containsKey(uid)) ? userNames[uid] : 'Member',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching members for fridge: $e');
      return [];
    }
  }

  /// Fetch pending join requests for fridges where user is admin
  Future<List<Map<String, dynamic>>> fetchPendingRequests() async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];

      final adminFridges = await client
          .from('fridge_users')
          .select('fridge_id')
          .eq('user_id', uid)
          .eq('role', 'admin');

      if (adminFridges.isEmpty) return [];

      final fridgeIds = (adminFridges as List)
          .map((item) => item['fridge_id'] as String)
          .toList();

      final data = await client
          .from('fridge_requests')
          .select('''
            id,
            requester_id,
            fridge_id,
            status,
            message,
            created_at,
            fridges(name)
          ''')
          .inFilter('fridge_id', fridgeIds)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(data);
      final reqIds = items.map((m) => m['requester_id'] as String?).whereType<String>().toSet().toList();

      final userNames = <String, String>{};
      if (reqIds.isNotEmpty) {
        try {
          final profilesData = await client.from('profiles').select('id, full_name').inFilter('id', reqIds);
          for (final p in profilesData) {
            final pid = p['id']?.toString();
            final name = p['full_name']?.toString();
            if (pid != null && name != null && name.isNotEmpty) userNames[pid] = name;
          }
        } catch (_) {}
        try {
          final localData = await client.from('local_users').select('id, name').inFilter('id', reqIds);
          for (final l in localData) {
            final lid = l['id']?.toString();
            final name = l['name']?.toString();
            if (lid != null && name != null && name.isNotEmpty) userNames.putIfAbsent(lid, () => name);
          }
        } catch (_) {}
      }

      return items.map((item) {
        final reqId = item['requester_id'] as String?;
        return {
          'id': item['id'],
          'requester_id': reqId,
          'fridge_id': item['fridge_id'],
          'status': item['status'],
          'message': item['message'],
          'created_at': item['created_at'],
          'requester_name': (reqId != null && userNames.containsKey(reqId)) ? userNames[reqId] : 'Unknown User',
          'fridge_name': item['fridges']?['name'] ?? 'Unknown Fridge',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
      return [];
    }
  }

  /// Fetch all pending requests as typed JoinRequest models
  Future<List<JoinRequest>> fetchPendingRequestModels() async {
    final raw = await fetchPendingRequests();
    return raw.map((m) => JoinRequest.fromMap(m)).toList();
  }

  /// Fetch pending requests for a specific fridge
  Future<List<Map<String, dynamic>>> fetchPendingRequestsForFridge(String fridgeId) async {
    try {
      final data = await client
          .from('fridge_requests')
          .select('id, requester_id, fridge_id, status, message, created_at')
          .eq('fridge_id', fridgeId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final items = List<Map<String, dynamic>>.from(data);
      final reqIds = items.map((m) => m['requester_id'] as String?).whereType<String>().toSet().toList();

      final userNames = <String, String>{};
      if (reqIds.isNotEmpty) {
        try {
          final profiles = await client.from('profiles').select('id, full_name').inFilter('id', reqIds);
          for (final p in profiles) {
            final id = p['id']?.toString();
            final name = p['full_name']?.toString();
            if (id != null && name != null && name.isNotEmpty) userNames[id] = name;
          }
        } catch (_) {}
        try {
          final locals = await client.from('local_users').select('id, name').inFilter('id', reqIds);
          for (final l in locals) {
            final id = l['id']?.toString();
            final name = l['name']?.toString();
            if (id != null && name != null && name.isNotEmpty) userNames.putIfAbsent(id, () => name);
          }
        } catch (_) {}
      }

      return items.map((m) {
        final reqId = m['requester_id'] as String?;
        return {
          'id': m['id'],
          'requester_id': reqId,
          'fridge_id': m['fridge_id'],
          'status': m['status'],
          'message': m['message'],
          'created_at': m['created_at'],
          'requester_name': (reqId != null && userNames.containsKey(reqId)) ? userNames[reqId] : 'Unknown User',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching pending requests for fridge: $e');
      return [];
    }
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

      final String id = res['id'].toString();
      try {
        await client.from('fridge_users').insert({'user_id': uid, 'fridge_id': id, 'role': 'admin'});
      } catch (_) {}
      return id;
    } catch (e) {
      debugPrint('Error creating fridge: $e');
      return null;
    }
  }

  /// Delete a fridge (admin/owner only)
  Future<bool> deleteFridge(String fridgeId) async {
    try {
      final uid = client.auth.currentUser!.id;
      final fridgeRow = await client.from('fridges').select('user_id').eq('id', fridgeId).maybeSingle();
      if (fridgeRow == null) return false;

      final ownerId = fridgeRow['user_id']?.toString();
      final membership = await client
          .from('fridge_users')
          .select('role')
          .eq('user_id', uid)
          .eq('fridge_id', fridgeId)
          .maybeSingle();

      final bool isAdmin = (membership != null && membership['role'] == 'admin') || (ownerId != null && ownerId == uid);
      if (!isAdmin) return false;

      await client.from('fridge_requests').delete().eq('fridge_id', fridgeId);
      await client.from('fridge_users').delete().eq('fridge_id', fridgeId);
      await client.from('inventory_items').delete().eq('fridge_id', fridgeId);
      await client.from('fridges').delete().eq('id', fridgeId);
      return true;
    } catch (e) {
      debugPrint('Error deleting fridge: $e');
      return false;
    }
  }

  /// Regenerate invite code for a fridge
  Future<String?> regenerateFridgeCode(String fridgeId) async {
    try {
      final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rnd = Random.secure();
      final code = List.generate(6, (index) => chars[rnd.nextInt(chars.length)]).join();

      await client.from('fridges').update({'code': code}).eq('id', fridgeId);
      return code;
    } catch (e) {
      debugPrint('Error regenerating fridge code: $e');
      return null;
    }
  }

  /// Join a fridge using code
  Future<Map<String, dynamic>> joinFridgeWithCode(String code) async {
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return {'success': false, 'message': 'Not authenticated'};

      try {
        final res = await client.rpc('join_fridge_with_code', params: {'p_code': code});
        if (res != null && res is Map && res['status'] == 'ok') {
          final fridgeId = res['fridge_id']?.toString();
          String fridgeName = 'Unknown Fridge';
          if (fridgeId != null) {
            try {
              final fridgeData = await client.from('fridges').select('name').eq('id', fridgeId).maybeSingle();
              fridgeName = fridgeData?['name'] ?? fridgeName;
            } catch (_) {}
          }
          return {'success': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
        }
      } catch (_) {}

      final trimmed = code.trim();
      final fridgeResult = await client
          .from('fridges')
          .select('id, name')
          .ilike('code', trimmed)
          .maybeSingle();

      if (fridgeResult == null) {
        return {'success': false, 'message': 'Invalid fridge code'};
      }

      final fridgeId = fridgeResult['id']?.toString();
      final fridgeName = (fridgeResult['name'] as String?) ?? 'Unknown Fridge';
      if (fridgeId == null) return {'success': false, 'message': 'Invalid fridge data'};

      final existingMembership = await client
          .from('fridge_users')
          .select('id, role')
          .eq('user_id', uid)
          .eq('fridge_id', fridgeId)
          .maybeSingle();

      if (existingMembership != null) {
        return {'success': true, 'alreadyMember': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
      }

      await client.from('fridge_users').insert({
        'user_id': uid,
        'fridge_id': fridgeId,
        'role': 'user',
        'joined_at': DateTime.now().toIso8601String(),
      });

      return {'success': true, 'fridgeId': fridgeId, 'fridgeName': fridgeName};
    } catch (e) {
      debugPrint('Unexpected error in joinFridgeWithCode: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Request to join a fridge
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

  /// Promote a user to admin in a specific fridge
  Future<void> promoteUser(String userId, String fridgeId) async {
    await client
        .from('fridge_users')
        .update({'role': 'admin'})
        .eq('user_id', userId)
        .eq('fridge_id', fridgeId);
  }

  /// Demote a user from admin to regular user in a specific fridge
  Future<void> demoteUser(String userId, String fridgeId) async {
    await client
        .from('fridge_users')
        .update({'role': 'user'})
        .eq('user_id', userId)
        .eq('fridge_id', fridgeId);
  }

  /// Remove a user from a fridge
  Future<void> removeUserFromFridge(String userId, String fridgeId) async {
    await client
        .from('fridge_users')
        .delete()
        .eq('user_id', userId)
        .eq('fridge_id', fridgeId);
  }

  /// Approve a join request
  Future<void> approveJoinRequest(String requestId) async {
    final request = await client
        .from('fridge_requests')
        .select('requester_id, fridge_id')
        .eq('id', requestId)
        .single();

    await client.from('fridge_users').insert({
      'user_id': request['requester_id'],
      'fridge_id': request['fridge_id'],
      'role': 'user',
    });

    await client
        .from('fridge_requests')
        .update({'status': 'approved'})
        .eq('id', requestId);
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId) async {
    await client
        .from('fridge_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }
}
