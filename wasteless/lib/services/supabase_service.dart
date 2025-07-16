import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  /// Initialize Supabase – replace with your own URL & anon key.
  static Future<SupabaseService> init() async {
    await Supabase.initialize(
      url: 'https://doxhjonwexqsrksakpqo.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
    );
    return SupabaseService();
  }

  final SupabaseClient client = Supabase.instance.client;

  /// Fetch all inventory items
  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final data = await client
        .from('inventory_items')
        .select()
        .order('expiry_date', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetch all waste log entries, joining in item name
  Future<List<Map<String, dynamic>>> fetchWasteLogs() async {
    final data = await client
        .from('waste_logs')
        .select(
          'id, item_id, quantity, reason, logged_at, inventory_items(name)',
        )
        .order('logged_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Insert a new inventory item
  Future<void> addItem({required String name, required DateTime expiry}) async {
    await client.from('inventory_items').insert({
      'name': name,
      'expiry_date': expiry.toIso8601String(),
    });
  }

  /// Log waste
  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final entry = {
      'item_id': itemId,
      'quantity': qty,
      'logged_at': DateTime.now().toIso8601String(),
      // add this:
      'user_id': Supabase.instance.client.auth.currentUser!.id,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    await client.from('waste_logs').insert(entry);
  }


  /// Offer a donation
  Future<void> offerDonation(String itemId, String recipientInfo) async {
    await client.from('donations').insert({
      'item_id': itemId,
      'recipient_info': recipientInfo,
      'offered_at': DateTime.now().toIso8601String(),
    });
  }
}
