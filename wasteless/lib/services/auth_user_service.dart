import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/local_user.dart';

/// Service managing local users, PIN/password hashing, local session persistence,
/// and auth password reset.
class AuthUserService {
  final SupabaseClient client;

  String? activeLocalUserId;
  String? activeLocalUserName;
  bool _isAdminMode = false;

  bool get isAdminMode => _isAdminMode;

  AuthUserService({required this.client});

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  /// Ensure the current user has an account row; create if missing
  Future<String> getOrCreateAccountId() async {
    try {
      final uid = client.auth.currentUser!.id;
      final existing = await client
          .from('accounts')
          .select('id')
          .eq('owner_id', uid)
          .maybeSingle();
      if (existing != null && existing['id'] != null) {
        return existing['id'] as String;
      }
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

  /// Fetch local users for the current user's account as raw Maps
  Future<List<Map<String, dynamic>>> fetchLocalUsers() async {
    try {
      final accountId = await getOrCreateAccountId();
      final data = await client
          .from('local_users')
          .select('id, name, created_at')
          .eq('account_id', accountId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching local users: $e');
      return [];
    }
  }

  /// Fetch local users as typed LocalUser models
  Future<List<LocalUser>> fetchLocalUserModels() async {
    final raw = await fetchLocalUsers();
    return raw.map((m) => LocalUser.fromMap(m)).toList();
  }

  /// Create a local user for current user's account
  Future<void> createLocalUser(String name) async {
    try {
      final accountId = await getOrCreateAccountId();
      await client.from('local_users').insert({
        'name': name,
        'account_id': accountId,
      });
    } catch (e) {
      debugPrint('Error creating local user: $e');
      rethrow;
    }
  }

  /// Create a local user with password (hashed on client)
  Future<void> createLocalUserWithPassword(String name, String password) async {
    try {
      final accountId = await getOrCreateAccountId();
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

  /// Update a local user's password
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
      final accountId = await getOrCreateAccountId();
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

  /// Load saved user context from SharedPreferences
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

  /// Save user context to SharedPreferences
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

  /// Send password reset email via Supabase
  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'wasteless://reset',
    );
  }
}
