// lib/services/supabase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/donation_item.dart';
import '../models/fridge.dart';
import '../models/fridge_member.dart';
import '../models/inventory_item.dart';
import '../models/join_request.dart';
import '../models/local_user.dart';
import '../models/waste_log.dart';
import 'auth_user_service.dart';
import 'fridge_service.dart';
import 'inventory_service.dart';
import 'notification_service.dart';
import 'waste_donation_service.dart';

/// Unifying Facade for all WasteLess backend & local services.
///
/// Delegates focused domain operations to:
/// - [NotificationService]
/// - [InventoryService]
/// - [FridgeService]
/// - [WasteDonationService]
/// - [AuthUserService]
///
/// Preserves 100% backward compatibility for all existing callers across the app.
class SupabaseService {
  final FlutterLocalNotificationsPlugin _local;
  final SupabaseClient client = Supabase.instance.client;

  late final NotificationService notificationService;
  late final FridgeService fridgeService;
  late final InventoryService inventoryService;
  late final WasteDonationService wasteDonationService;
  late final AuthUserService authUserService;

  SupabaseService(this._local) {
    notificationService = NotificationService(_local);
    fridgeService = FridgeService(client: client);
    authUserService = AuthUserService(client: client);

    inventoryService = InventoryService(
      client: client,
      notificationService: notificationService,
      getDefaultFridgeId: () => fridgeService.getDefaultFridgeId(),
      ensureItemFridgeAssigned: () => fridgeService.ensureItemFridgeAssigned(),
      getActiveLocalUserName: () => authUserService.activeLocalUserName,
    );

    wasteDonationService = WasteDonationService(
      client: client,
      onUpdateItemQuantity: (id, qty) => inventoryService.updateItemQuantity(id, qty),
      onDeleteInventoryItem: (id) => inventoryService.deleteInventoryItem(id),
    );
  }

  // ---------------------------------------------------------------------------
  // Broadcast Streams & Properties
  // ---------------------------------------------------------------------------

  Stream<void> get onInventoryChanged => inventoryService.onInventoryChanged;

  bool get isAdminMode => authUserService.isAdminMode;

  String? get activeLocalUserId => authUserService.activeLocalUserId;
  set activeLocalUserId(String? val) => authUserService.activeLocalUserId = val;

  String? get activeLocalUserName => authUserService.activeLocalUserName;
  set activeLocalUserName(String? val) => authUserService.activeLocalUserName = val;

  String? getCurrentUserId() => client.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Inventory Operations (Delegated to InventoryService)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchInventory() =>
      inventoryService.fetchInventory();

  Future<List<InventoryItem>> fetchInventoryItems() =>
      inventoryService.fetchInventoryItems();

  Future<List<Map<String, dynamic>>> fetchCategories() =>
      inventoryService.fetchCategories();

  Future<List<Category>> fetchCategoryModels() =>
      inventoryService.fetchCategoryModels();

  Future<List<Map<String, dynamic>>> fetchInventoryByCategory(String categoryId) =>
      inventoryService.fetchInventoryByCategory(categoryId);

  Future<void> addItem({
    required String name,
    required DateTime expiry,
    required int quantity,
    required int reminderDaysBefore,
    required int reminderHoursBefore,
    required List<String> categoryIds,
    String? fridgeId,
  }) =>
      inventoryService.addItem(
        name: name,
        expiry: expiry,
        quantity: quantity,
        reminderDaysBefore: reminderDaysBefore,
        reminderHoursBefore: reminderHoursBefore,
        categoryIds: categoryIds,
        fridgeId: fridgeId,
      );

  Future<void> addMultipleItems(List<Map<String, dynamic>> items, [String? defaultFridgeId]) =>
      inventoryService.addMultipleItems(items, defaultFridgeId);

  Future<void> updateItemQuantity(String itemId, int newQty) =>
      inventoryService.updateItemQuantity(itemId, newQty);

  Future<void> consumeItem(String itemId, [int qty = 1]) =>
      inventoryService.consumeItem(itemId, qty);

  Future<void> deleteInventoryItem(String id) =>
      inventoryService.deleteInventoryItem(id);

  Future<void> rescheduleExpiryReminders() =>
      inventoryService.rescheduleExpiryReminders();

  Future<List<Map<String, dynamic>>> fetchFridgeItems(String fridgeId) =>
      inventoryService.fetchFridgeItems(fridgeId);

  // ---------------------------------------------------------------------------
  // Waste & Donation Operations (Delegated to WasteDonationService)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchWasteLogs() =>
      wasteDonationService.fetchWasteLogs();

  Future<List<WasteLog>> fetchWasteLogModels() =>
      wasteDonationService.fetchWasteLogModels();

  Future<void> logWaste(String itemId, int qty, [String? reason]) =>
      wasteDonationService.logWaste(itemId, qty, reason);

  Future<void> deleteWasteLog(String id) =>
      wasteDonationService.deleteWasteLog(id);

  Future<List<Map<String, dynamic>>> fetchDonations() =>
      wasteDonationService.fetchDonations();

  Future<List<DonationItem>> fetchDonationModels() =>
      wasteDonationService.fetchDonationModels();

  Future<void> offerDonation(String itemId, String recipientInfo, [int qty = 1]) =>
      wasteDonationService.offerDonation(itemId, recipientInfo, qty);

  Future<void> deleteDonation(String id) =>
      wasteDonationService.deleteDonation(id);

  // ---------------------------------------------------------------------------
  // Fridge Operations (Delegated to FridgeService)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchMyFridges() =>
      fridgeService.fetchMyFridges();

  Future<List<Fridge>> fetchMyFridgeModels() =>
      fridgeService.fetchMyFridgeModels();

  Future<List<Map<String, dynamic>>> fetchConnectedFridges() =>
      fridgeService.fetchConnectedFridges();

  Future<String?> getDefaultFridgeId() =>
      fridgeService.getDefaultFridgeId();

  Future<void> ensureItemFridgeAssigned() =>
      fridgeService.ensureItemFridgeAssigned();

  Future<List<Map<String, dynamic>>> fetchFridgeMembers() =>
      fridgeService.fetchFridgeMembers();

  Future<List<FridgeMember>> fetchFridgeMemberModels() =>
      fridgeService.fetchFridgeMemberModels();

  Future<List<Map<String, dynamic>>> fetchFridgeMembersForFridge(String fridgeId) =>
      fridgeService.fetchFridgeMembersForFridge(fridgeId);

  Future<List<Map<String, dynamic>>> fetchPendingRequests() =>
      fridgeService.fetchPendingRequests();

  Future<List<JoinRequest>> fetchPendingRequestModels() =>
      fridgeService.fetchPendingRequestModels();

  Future<List<Map<String, dynamic>>> fetchPendingRequestsForFridge(String fridgeId) =>
      fridgeService.fetchPendingRequestsForFridge(fridgeId);

  Future<String?> createFridge({String? name, String? location}) =>
      fridgeService.createFridge(name: name, location: location);

  Future<bool> deleteFridge(String fridgeId) =>
      fridgeService.deleteFridge(fridgeId);

  Future<String?> regenerateFridgeCode(String fridgeId) =>
      fridgeService.regenerateFridgeCode(fridgeId);

  Future<Map<String, dynamic>> joinFridgeWithCode(String code) =>
      fridgeService.joinFridgeWithCode(code);

  Future<bool> requestToJoinFridge(String fridgeId, String message) =>
      fridgeService.requestToJoinFridge(fridgeId, message);

  Future<void> promoteUser(String userId, String fridgeId) =>
      fridgeService.promoteUser(userId, fridgeId);

  Future<void> demoteUser(String userId, String fridgeId) =>
      fridgeService.demoteUser(userId, fridgeId);

  Future<void> removeUserFromFridge(String userId, String fridgeId) =>
      fridgeService.removeUserFromFridge(userId, fridgeId);

  Future<void> approveJoinRequest(String requestId) =>
      fridgeService.approveJoinRequest(requestId);

  Future<void> rejectJoinRequest(String requestId) =>
      fridgeService.rejectJoinRequest(requestId);

  Future<Map<String, dynamic>?> fetchFridgeById(String fridgeId) async {
    try {
      final f = await client
          .from('fridges')
          .select('id, name, location, created_at, user_id, code')
          .eq('id', fridgeId)
          .maybeSingle();
      if (f == null) return null;
      return Map<String, dynamic>.from(f as Map);
    } catch (e) {
      debugPrint('Error fetching fridge by id: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Auth & Local User Operations (Delegated to AuthUserService)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchLocalUsers() =>
      authUserService.fetchLocalUsers();

  Future<List<LocalUser>> fetchLocalUserModels() =>
      authUserService.fetchLocalUserModels();

  Future<void> createLocalUser(String name) =>
      authUserService.createLocalUser(name);

  Future<void> createLocalUserWithPassword(String name, String password) =>
      authUserService.createLocalUserWithPassword(name, password);

  Future<void> updateLocalUser(String userId, String newName) =>
      authUserService.updateLocalUser(userId, newName);

  Future<void> updateLocalUserPassword(String userId, String newPassword) =>
      authUserService.updateLocalUserPassword(userId, newPassword);

  Future<void> deleteLocalUser(String userId) =>
      authUserService.deleteLocalUser(userId);

  Future<bool> verifyAndSelectLocalUser(String localUserId, String password) =>
      authUserService.verifyAndSelectLocalUser(localUserId, password);

  Future<void> setAdminMode() =>
      authUserService.setAdminMode();

  Future<bool> hasLocalUsers() =>
      authUserService.hasLocalUsers();

  Future<void> loadSavedUserContext() =>
      authUserService.loadSavedUserContext();

  Future<void> saveUserContext() =>
      authUserService.saveUserContext();

  Future<void> clearUserContext() =>
      authUserService.clearUserContext();

  Future<void> sendPasswordReset(String email) =>
      authUserService.sendPasswordReset(email);

  // ---------------------------------------------------------------------------
  // Aggregated Dashboard Stats
  // ---------------------------------------------------------------------------

  /// Fetch dashboard summary metrics (Active Items, Expiring in <= 48h, Meals Shared)
  Future<Map<String, int>> fetchDashboardStats() async {
    try {
      final items = await fetchInventory();
      final now = DateTime.now();
      int expiringSoon = 0;
      for (final item in items) {
        final exp = DateTime.tryParse(item['expiry_date'] as String? ?? '');
        if (exp != null) {
          final diff = exp.difference(now);
          if (diff.inDays <= 2 && !diff.isNegative) {
            expiringSoon++;
          }
        }
      }
      final donations = await fetchDonations();
      return {
        'activeItems': items.length,
        'expiringSoon': expiringSoon,
        'mealsShared': donations.length,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      return {'activeItems': 0, 'expiringSoon': 0, 'mealsShared': 0};
    }
  }
}
