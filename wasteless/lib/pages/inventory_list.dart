// lib/pages/inventory_list.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'waste_log_page.dart';
import 'donation_page.dart';

class InventoryList extends StatefulWidget {
  final SupabaseService supa;
  const InventoryList({required this.supa, super.key});

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
              final name = (item['name'] as String?)?.trim().isNotEmpty == true
                  ? (item['name'] as String)
                  : 'Unnamed';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEADING
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.green[50],
                            child: (catIcon != null && catIcon.isNotEmpty)
                                ? ClipOval(
                                    child: Image.network(
                                      catIcon,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
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
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // TITLE + SUBTITLE
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              daysLeft >= 0
                                  ? 'Expires in $daysLeft day(s) ${hoursLeft}h'
                                  : 'Expired ${-daysLeft} day(s) ago',
                            ),
                            if (cats.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                clipBehavior: Clip.hardEdge,
                                children: cats.map((c) {
                                  final iconUrl = (c['icon_url'] as String?) ?? '';
                                  final label = (c['name'] as String?) ?? '';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (iconUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Image.network(iconUrl, width: 16, height: 16),
                                          ),
                                        Text(label, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                       // TRAILING: [status badge] to the LEFT of dropdown menu
                       Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: daysLeft <= 1 ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Text(
                              daysLeft >= 0 ? '$daysLeft d' : 'Exp',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                           PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'waste') {
                                // Navigate to waste page with id + name
                                Navigator.of(context)
                                    .pushNamed(
                                      WasteLogPage.route,
                                      arguments: {'id': item['id'].toString(), 'name': name},
                                    )
                                     .then((_) {
                                       refresh();
                                       // also ask waste tab to refresh if mounted
                                       // Parent HomePage will refresh tab on selection
                                     });
                              } else if (val == 'donate') {
                                // Navigate to donate page with id + name
                                Navigator.of(context)
                                    .pushNamed(
                                      DonationPage.route,
                                      arguments: {'id': item['id'].toString(), 'name': name},
                                    )
                                     .then((_) {
                                       refresh();
                                     });
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
                             itemBuilder: (_) => const [
                              PopupMenuItem(value: 'waste', child: Text('Log Waste')),
                              PopupMenuItem(value: 'donate', child: Text('Donate')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
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
