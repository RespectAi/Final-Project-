import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/charity_organization.dart';
import '../models/donation_item.dart';
import '../models/waste_log.dart';

/// Service managing food waste logs, donations, and charity directory.
class WasteDonationService {
  final SupabaseClient client;
  final Future<void> Function(String itemId, int newQty)? onUpdateItemQuantity;
  final Future<void> Function(String itemId)? onDeleteInventoryItem;
  final Future<void> Function(Map<String, dynamic> item)? onReinsertInventoryItem;
  final VoidCallback? onNotifyInventoryChanged;

  static const String _cachedCharitiesKey = 'cached_charities_list_v1';
  static const String _customCharitiesKey = 'custom_charities_list_v1';

  WasteDonationService({
    required this.client,
    this.onUpdateItemQuantity,
    this.onDeleteInventoryItem,
    this.onReinsertInventoryItem,
    this.onNotifyInventoryChanged,
  });

  // ---------------------------------------------------------------------------
  // Waste Logs
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Donations
  // ---------------------------------------------------------------------------

  /// Fetch this user's donations as raw maps
  Future<List<Map<String, dynamic>>> fetchDonations() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      // 1. Try selecting with status and charity_id columns
      final data = await client
          .from('donations')
          .select('id, item_id, item_name, recipient_info, offered_at, status, charity_id, inventory_items(name)')
          .eq('user_id', uid)
          .order('offered_at', ascending: false);
      return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      try {
        // Fallback for older database schemas
        final fallbackData = await client
            .from('donations')
            .select('id, item_id, item_name, recipient_info, offered_at, inventory_items(name)')
            .eq('user_id', uid)
            .order('offered_at', ascending: false);
        return (fallbackData as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (err) {
        debugPrint('Error fetching donations: $err');
        return [];
      }
    }
  }

  /// Fetch typed DonationItem models
  Future<List<DonationItem>> fetchDonationModels() async {
    final raw = await fetchDonations();
    return raw.map((m) => DonationItem.fromMap(m)).toList();
  }

  /// Offer a donation.
  /// Attempts the atomic server RPC `process_donation` first for speed and data consistency.
  /// If offline or on RPC failure, falls back seamlessly to client-side database execution.
  Future<void> offerDonation(String itemId, String recipientInfo, [int qty = 1, String? charityId]) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    // 1. Attempt Server-side RPC (1 roundtrip)
    try {
      final res = await client.rpc('process_donation', params: {
        'p_item_id': itemId,
        'p_recipient_info': recipientInfo,
        'p_qty': qty,
      });
      if (res != null && (res is Map && res['success'] == true)) {
        onNotifyInventoryChanged?.call();
        return;
      }
    } catch (e) {
      debugPrint('process_donation RPC failed or offline, falling back to client execution: $e');
    }

    // 2. Client-side Fallback (Resilient offline / network recovery)
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
      'status': 'pending',
      if (charityId != null) 'charity_id': charityId,
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
    onNotifyInventoryChanged?.call();
  }

  /// Cancel/Delete a donation with optional restoration back to inventory.
  /// Attempts atomic server RPC `cancel_donation` first, with client fallback.
  Future<void> cancelDonation(
    String donationId, {
    bool returnToInventory = true,
    Map<String, dynamic>? donationData,
  }) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    // 1. Attempt Server-side RPC
    try {
      final res = await client.rpc('cancel_donation', params: {
        'p_donation_id': donationId,
        'p_return_to_inventory': returnToInventory,
      });
      if (res != null && (res is Map && res['success'] == true)) {
        onNotifyInventoryChanged?.call();
        return;
      }
    } catch (e) {
      debugPrint('cancel_donation RPC failed or offline, falling back to client execution: $e');
    }

    // 2. Client-side Fallback
    try {
      if (returnToInventory && donationData != null) {
        final itemId = donationData['item_id']?.toString();
        final itemName = donationData['item_name']?.toString() ?? 'Restored Food Item';

        int restoredQty = 1;
        if (donationData['quantity'] != null) {
          restoredQty = (donationData['quantity'] as num).toInt();
        }

        String? originalExpiry = donationData['expiry_date']?.toString();
        final rawRecipient = donationData['recipient_info']?.toString() ?? '';
        if (rawRecipient.trim().startsWith('{')) {
          try {
            final decoded = jsonDecode(rawRecipient);
            if (decoded is Map<String, dynamic>) {
              if (decoded['quantity'] != null) {
                restoredQty = (decoded['quantity'] as num).toInt();
              }
              if (decoded['expiry_date'] != null) {
                originalExpiry = decoded['expiry_date']?.toString();
              }
            }
          } catch (_) {}
        }

        originalExpiry ??= DateTime.now().add(const Duration(days: 7)).toIso8601String();

        if (itemId != null && itemId.isNotEmpty) {
          try {
            final existing = await client
                .from('inventory_items')
                .select('id, quantity')
                .eq('id', itemId)
                .maybeSingle();

            if (existing != null) {
              final q = (existing['quantity'] as int?) ?? 0;
              await client.from('inventory_items').update({'quantity': q + restoredQty}).eq('id', itemId);
            } else {
              await client.from('inventory_items').insert({
                'id': itemId,
                'name': itemName,
                'quantity': restoredQty,
                'expiry_date': originalExpiry,
                'user_id': uid,
              });
            }
          } catch (_) {}
        }
      }

      await client.from('donations').delete().eq('id', donationId);
      onNotifyInventoryChanged?.call();
    } catch (e) {
      debugPrint('Error deleting donation client-side: $e');
      rethrow;
    }
  }

  /// Bulk cancel / restore donations
  Future<void> bulkCancelDonations(
    List<Map<String, dynamic>> items, {
    bool returnToInventory = true,
  }) async {
    for (final item in items) {
      final id = item['id']?.toString();
      if (id != null) {
        await cancelDonation(id, returnToInventory: returnToInventory, donationData: item);
      }
    }
    onNotifyInventoryChanged?.call();
  }

  /// Bulk update donation status
  Future<void> bulkUpdateDonationStatus(
    List<Map<String, dynamic>> items,
    String newStatus,
  ) async {
    for (final item in items) {
      final id = item['id']?.toString();
      if (id != null) {
        await updateDonationStatus(id, newStatus, item);
      }
    }
  }

  /// Update donation status (e.g. 'pending' -> 'scheduled' -> 'completed')
  Future<void> updateDonationStatus(
    String donationId,
    String newStatus,
    Map<String, dynamic> existingData,
  ) async {
    try {
      // Re-encode recipient_info with updated status
      final rawRecipient = existingData['recipient_info']?.toString() ?? '';
      String updatedRecipient = rawRecipient;
      if (rawRecipient.trim().startsWith('{')) {
        try {
          final decoded = jsonDecode(rawRecipient);
          if (decoded is Map<String, dynamic>) {
            decoded['status'] = newStatus;
            updatedRecipient = jsonEncode(decoded);
          }
        } catch (_) {}
      }

      // Update both status column and recipient_info string
      try {
        await client.from('donations').update({
          'status': newStatus,
          'recipient_info': updatedRecipient,
        }).eq('id', donationId);
      } catch (_) {
        // Fallback for older schema without status column
        await client.from('donations').update({
          'recipient_info': updatedRecipient,
        }).eq('id', donationId);
      }
    } catch (e) {
      debugPrint('Error updating donation status: $e');
      rethrow;
    }
  }

  /// Legacy delete donation
  Future<void> deleteDonation(String id) => cancelDonation(id, returnToInventory: false);

  // ---------------------------------------------------------------------------
  // Charity Directory (Supabase + Offline Cache & Fallbacks)
  // ---------------------------------------------------------------------------

  /// Fetch charities from Supabase `charities` table, combined with local custom charities.
  /// Falls back to local SharedPreferences cache or default charities if offline.
  Future<List<CharityOrganization>> fetchCharities() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load user-added custom charities from local storage
    final customList = _loadLocalCustomCharities(prefs);

    // 2. Try fetching from Supabase charities table
    try {
      final res = await client
          .from('charities')
          .select('*')
          .order('name', ascending: true);

      final remoteCharities = (res as List).map((m) => CharityOrganization.fromMap(m)).toList();

      if (remoteCharities.isNotEmpty) {
        // Cache for offline resilience
        final encoded = jsonEncode(remoteCharities.map((c) => c.toMap()).toList());
        await prefs.setString(_cachedCharitiesKey, encoded);

        // Combine remote + custom
        return _mergeCharities(remoteCharities, customList);
      }
    } catch (e) {
      debugPrint('Could not fetch charities from server, using local cache: $e');
    }

    // 3. Fallback: Check local cache
    final cached = prefs.getString(_cachedCharitiesKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as List;
        final list = decoded.map((m) => CharityOrganization.fromMap(Map<String, dynamic>.from(m))).toList();
        return _mergeCharities(list, customList);
      } catch (_) {}
    }

    // 4. Ultimate Fallback: Default verified charities
    return _mergeCharities(CharityOrganization.defaultCharities, customList);
  }

  /// Add a custom charity (inserts into Supabase if possible and always saves to local storage)
  Future<void> addCustomCharity(CharityOrganization charity) async {
    final prefs = await SharedPreferences.getInstance();
    final custom = _loadLocalCustomCharities(prefs);

    // Add to local list
    custom.removeWhere((c) => c.id == charity.id || c.name.toLowerCase() == charity.name.toLowerCase());
    custom.insert(0, charity);

    final encoded = jsonEncode(custom.map((c) => c.toMap()).toList());
    await prefs.setString(_customCharitiesKey, encoded);

    // Try inserting into Supabase charities table
    try {
      await client.from('charities').insert({
        'name': charity.name,
        'category': charity.category,
        'phone': charity.phone,
        if (charity.whatsapp != null) 'whatsapp': charity.whatsapp,
        if (charity.email != null) 'email': charity.email,
        'address': charity.address,
        'city': charity.city,
        'accepted_items': charity.acceptedItems,
        'operating_hours': charity.operatingHours,
        'is_verified': false, // User custom charities marked pending verification
      });
    } catch (e) {
      debugPrint('Could not save charity to Supabase table (offline or table missing): $e');
    }
  }

  List<CharityOrganization> _loadLocalCustomCharities(SharedPreferences prefs) {
    final raw = prefs.getString(_customCharitiesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((m) => CharityOrganization.fromMap(Map<String, dynamic>.from(m))).toList();
    } catch (_) {
      return [];
    }
  }

  List<CharityOrganization> _mergeCharities(
    List<CharityOrganization> primary,
    List<CharityOrganization> custom,
  ) {
    final seenIds = <String>{};
    final seenNames = <String>{};
    final result = <CharityOrganization>[];

    for (final c in custom) {
      if (!seenIds.contains(c.id) && !seenNames.contains(c.name.toLowerCase())) {
        seenIds.add(c.id);
        seenNames.add(c.name.toLowerCase());
        result.add(c);
      }
    }

    for (final c in primary) {
      if (!seenIds.contains(c.id) && !seenNames.contains(c.name.toLowerCase())) {
        seenIds.add(c.id);
        seenNames.add(c.name.toLowerCase());
        result.add(c);
      }
    }

    return result;
  }
}
