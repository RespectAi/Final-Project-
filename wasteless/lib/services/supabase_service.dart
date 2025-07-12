import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Future<SupabaseService> init() async {
    await Supabase.initialize(
      url: 'https://doxhjonwexqsrksakpqo.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
    );
    return SupabaseService();
  }

  final client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchInventory() async {
    final List<dynamic> data = await client
        .from('inventory')
        .select()
        .limit(100)
        .order('id')
        .then((value) => value as List<dynamic>);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addItem({required String name, required DateTime expiry}) async {
    await client.from('inventory').insert({
      'name': name,
      'expiry_date': expiry.toIso8601String(),
    });
  }

  Future<void> logWaste(String itemId, int qty, [String? reason]) async {
    final Map<String, dynamic> data = {
      'item_id': itemId,
      'quantity': qty,
      'date': DateTime.now().toIso8601String(),
    };

    // Add reason to the data only if it's provided and not empty
    if (reason != null && reason.isNotEmpty) {
      data['reason'] = reason;
    }

    await client.from('waste_log').insert(data);
  }

  Future<void> offerDonation(String itemId, String recipient) async {
    await client.from('donations').insert({
      'item_id': itemId,
      'recipient': recipient,
      'date': DateTime.now().toIso8601String(),
    });
  }
}
