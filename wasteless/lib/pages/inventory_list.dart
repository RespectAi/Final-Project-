import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class InventoryList extends StatefulWidget {
  final SupabaseService supa;
  const InventoryList({required this.supa, Key? key}) : super(key: key);

  @override
  InventoryListState createState() => InventoryListState();
}

class InventoryListState extends State<InventoryList> {
  late Future<List<Map<String, dynamic>>> _items;

  Future<void> refresh() async {
    setState(() {
      _items = widget.supa.fetchInventory();
    });
  }

  @override
  void initState() {
    super.initState();
    _items = widget.supa.fetchInventory();
  }

  Future<void> _refresh() async {
    setState(() {
      _items = widget.supa.fetchInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(child: Text('No items yet. Tap + to add.'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (_, i) {
               final item = items[i];
              final expiry = DateTime.parse(item['expiry_date']);
              final now = DateTime.now();
              final diff = expiry.difference(now);
              final daysLeft = diff.inDays;
              final hoursLeft = diff.inHours % 24;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  title: Text(item['name']),
                  subtitle: Text(
                    daysLeft >= 0
                        ? 'Expires in $daysLeft day(s) ${hoursLeft}h'
                        : 'Expired ${-daysLeft} day(s) ago',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      SizedBox(width: 4),
                      Text(
                        daysLeft >= 0 ? '$daysLeft d ${hoursLeft}h' : '–',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 12),
                      PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'waste') {
                            await widget.supa.logWaste(
                              item['id'].toString(),
                              1,
                            );
                            await refresh();
                          } else if (val == 'donate') {
                            // show a dialog to input recipient info, then:
                            await widget.supa.offerDonation(
                              item['id'].toString(),
                              '',
                            );
                            await refresh();
                          } else if (val == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Delete item?'),
                                content: Text(
                                  'Remove this product permanently?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.supa.deleteInventoryItem(
                                item['id'].toString(),
                              );
                              await refresh();
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'waste',
                            child: Text('Log Waste'),
                          ),
                          PopupMenuItem(value: 'donate', child: Text('Donate')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );

            },
          );
        },
      ),
    );
  }
}
