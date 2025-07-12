import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class InventoryList extends StatefulWidget {
  final SupabaseService supa;
  const InventoryList({required this.supa, Key? key}) : super(key: key);

  @override
  _InventoryListState createState() => _InventoryListState();
}

class _InventoryListState extends State<InventoryList> {
  late Future<List<Map<String, dynamic>>> _items;

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
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(child: Text('No items yet. Tap + to add.'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final expiry = DateTime.parse(item['expiry_date']);
              final daysLeft = expiry.difference(DateTime.now()).inDays;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  title: Text(item['name']),
                  subtitle: Text(
                    daysLeft >= 0
                        ? 'Expires in $daysLeft day(s)'
                        : 'Expired ${-daysLeft} day(s) ago',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'waste') {
                        Navigator.pushNamed(context, '/waste', arguments: item['id'])
                            .then((_) => _refresh());
                      }
                      if (val == 'donate') {
                        Navigator.pushNamed(context, '/donate', arguments: item['id'])
                            .then((_) => _refresh());
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'waste', child: Text('Log Waste')),
                      PopupMenuItem(value: 'donate', child: Text('Donate')),
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
