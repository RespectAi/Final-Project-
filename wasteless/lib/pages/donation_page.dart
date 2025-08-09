// lib/pages/donation_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class DonationPage extends StatefulWidget {
  static const route = '/donate';
  final SupabaseService supa;
  const DonationPage({required this.supa, Key? key}) : super(key: key);

  @override
  DonationPageState createState() => DonationPageState();
}

class DonationPageState extends State<DonationPage> {
  final _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _donations;

  String? _itemId;
  String _itemName = '';

  @override
  void initState() {
    super.initState();
    _refreshDonations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _itemId = args['id']?.toString();
      _itemName = (args['name'] as String?) ?? '';
    }
  }

  Future<void> _refreshDonations() async {
    setState(() {
      _donations = widget.supa.fetchDonations();
    });
  }

  // Allow parent to trigger refresh when tab becomes active
  void refresh() => _refreshDonations();

  Future<void> _submit(String itemId) async {
    final info = _controller.text.trim();
    if (info.isEmpty) return;
    await widget.supa.offerDonation(itemId, info);
    await _refreshDonations();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_itemId != null) {
      return Scaffold(
        appBar: buildGradientAppBar(context, 'Offer Donation: ${_itemName.isEmpty ? "Item" : _itemName}'),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item: ${_itemName.isEmpty ? _itemId : _itemName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Recipient Info'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => _submit(_itemId!), child: const Text('Donate')),
              ),
            ],
          ),
        ),
      );
    } else {
      final showOwnAppBar = Navigator.of(context).canPop();
      return Scaffold(
        appBar: showOwnAppBar ? buildGradientAppBar(context, 'All Donations', showBackIfCanPop: true) : null,
        body: RefreshIndicator(
          onRefresh: _refreshDonations,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _donations,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('No donations yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final d = list[i];
                  final when = DateTime.parse(d['offered_at']);
                  final formatted = DateFormat.yMMMd().add_jm().format(when);
                  final inv = d['inventory_items'] as Map<String, dynamic>?;
                  final itemName = (d['item_name'] as String?) ?? (inv?['name'] as String?) ?? 'Unknown Item';
                  return Card(
                    child: ListTile(
                      title: Text('$itemName → ${d['recipient_info']}'),
                      subtitle: Text(formatted),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete donation?'),
                              content: const Text('Remove this donation permanently?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await widget.supa.deleteDonation(d['id'].toString());
                            await _refreshDonations();
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }
  }
}
