// lib/pages/donation_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class DonationPage extends StatefulWidget {
  static const route = '/donate';
  final SupabaseService supa;
  const DonationPage({required this.supa, Key? key}) : super(key: key);

  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  // form mode
  final _controller = TextEditingController();

  // list mode
  late Future<List<Map<String, dynamic>>> _donations;

  @override
  void initState() {
    super.initState();
    _refreshDonations();
  }

  Future<void> _refreshDonations() async {
    setState(() {
      _donations = widget.supa.fetchDonations();
    });
  }

  Future<void> _submit(String itemId) async {
    final info = _controller.text.trim();
    if (info.isEmpty) return;
    await widget.supa.offerDonation(itemId, info);
    // ensure list is updated when we pop back
    await _refreshDonations();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final itemId = args is String ? args : null;

    if (itemId != null) {
      // FORM MODE: show donation input
      return Scaffold(
        appBar: AppBar(title: Text('Offer Donation')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: InputDecoration(labelText: 'Recipient Info'),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () => _submit(itemId),
                child: Text('Donate'),
              ),
            ],
          ),
        ),
      );
    } else {
      // LIST MODE: show all donations
      return Scaffold(
        appBar: AppBar(title: Text('All Donations')),
        body: RefreshIndicator(
          onRefresh: _refreshDonations,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _donations,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final list = snap.data ?? [];
              if (list.isEmpty) {
                return Center(child: Text('No donations yet.'));
              }
              return ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final d = list[i];
                  final when = DateTime.parse(d['offered_at']);
                  final formatted = DateFormat.yMMMd().add_jm().format(when);
                  final itemName = (d['inventory_items'] as Map)['name'];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('$itemName → ${d['recipient_info']}'),
                      subtitle: Text(formatted),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Delete donation?'),
                              content: Text('Remove this donation permanently?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete'),
                                ),
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
