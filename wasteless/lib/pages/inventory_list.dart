// lib/pages/inventory_list.dart
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
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No items yet. Tap + to add.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];

              final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
              final cats = links
                  .map((link) => (link['categories'] as Map<String, dynamic>? ?? {}))
                  .toList();

              final expiry = DateTime.parse(item['expiry_date']);
              final now = DateTime.now();
              final diff = expiry.difference(now);
              final daysLeft = diff.inDays;
              final hoursLeft = diff.inHours % 24;

              final quantity = item['quantity'] ?? 1;
              final firstCat = cats.isNotEmpty ? cats.first : null;
              final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
              final name = item['name'] as String? ?? 'Unnamed';

              return Card(
                child: ListTile(
                  isThreeLine: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  leading: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.green[50],
                        child: catIcon != null && catIcon.isNotEmpty
                            ? ClipOval(
                                child: Image.network(catIcon, width: 44, height: 44, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.eco, size: 30),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.blueAccent,
                          child: Text(
                            '$quantity',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        daysLeft >= 0
                            ? 'Expires in $daysLeft day(s) ${hoursLeft}h'
                            : 'Expired ${-daysLeft} day(s) ago',
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: cats.map((c) {
                          return Chip(
                            label: Text(c['name'] ?? ''),
                            avatar: c['icon_url'] != null
                                ? Image.network(c['icon_url'], width: 20, height: 20)
                                : null,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        label: Text(daysLeft >= 0 ? '$daysLeft d' : 'Exp'),
                        backgroundColor: daysLeft <= 1 ? Colors.red[50] : Colors.green[50],
                      ),
                      const SizedBox(height: 8),
                      PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'waste') {
                            await widget.supa.logWaste(item['id'].toString(), 1);
                            await refresh();
                          } else if (val == 'donate') {
                            // open donation flow — pass item id
                            Navigator.of(context).pushNamed('/donate', arguments: item['id'].toString()).then((_) => refresh());
                          } else if (val == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete item?'),
                                content: const Text('Remove this product permanently?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.supa.deleteInventoryItem(item['id'].toString());
                              await refresh();
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'waste', child: Text('Log Waste')),
                          const PopupMenuItem(value: 'donate', child: Text('Donate')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
