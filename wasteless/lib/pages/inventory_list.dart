// lib/pages/inventory_list.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
// import 'waste_log_page.dart';
// import 'donation_page.dart';
import 'categories_page.dart';

class InventoryList extends StatefulWidget {
  final SupabaseService supa;
  const InventoryList({required this.supa, super.key});

  @override
  InventoryListState createState() => InventoryListState();
}

class InventoryListState extends State<InventoryList> {
  late Future<List<Map<String, dynamic>>> _items;
  StreamSubscription<void>? _inventorySub;

  // Selection mode state
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedItems = {};

  Future<void> refresh() async {
    setState(() {
      _items = widget.supa.fetchInventory();
      _clearSelection();
    });
  }

  @override
  void initState() {
    super.initState();
    _items = widget.supa.fetchInventory();

    // Subscribe to changes so the list refreshes when another page mutates inventory
    _inventorySub = widget.supa.onInventoryChanged.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items = widget.supa.fetchInventory();
      // keep selection unchanged on manual pull-to-refresh? We'll clear to be safe
      _clearSelection();
    });
  }

  void _toggleSelection(String id, Map<String, dynamic> item) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedItems.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedItems[id] = item;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _selectedItems.clear();
    });
  }

  Future<void> _confirmAndPerformBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected items?'),
        content: Text('Remove ${_selectedIds.length} item(s) permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      for (final id in List<String>.from(_selectedIds)) {
        await widget.supa.deleteInventoryItem(id);
      }
      await refresh();
    }
  }

  Future<void> _performBulkWaste() async {
    if (_selectedIds.isEmpty) return;
    // Ask for optional reason
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) {
        String r = '';
        return AlertDialog(
          title: const Text('Log waste for selected items'),
          content: TextFormField(
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
            onChanged: (v) => r = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, r.trim()), child: const Text('OK')),
          ],
        );
      },
    );
    if (reason == null) return; // cancelled
    for (final id in List<String>.from(_selectedIds)) {
      final item = _selectedItems[id];
      final qty = (item?['quantity'] as int?) ?? 1;
      await widget.supa.logWaste(id, qty, reason.isEmpty ? null : reason);
    }
    await refresh();
  }

  Future<void> _performBulkDonate() async {
    if (_selectedIds.isEmpty) return;
    final recipient = await showDialog<String?>(
      context: context,
      builder: (_) {
        String r = '';
        return AlertDialog(
          title: const Text('Offer donation for selected items'),
          content: TextFormField(
            decoration: const InputDecoration(labelText: 'Recipient info (email / text)'),
            onChanged: (v) => r = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, r.trim()), child: const Text('Offer')),
          ],
        );
      },
    );
    if (recipient == null || recipient.isEmpty) return;
    for (final id in List<String>.from(_selectedIds)) {
      await widget.supa.offerDonation(id, recipient);
    }
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    final selectionActive = _selectedIds.isNotEmpty;

    return Stack(
      children: [
        RefreshIndicator(
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
                  final id = item['id']?.toString() ?? i.toString();
                  final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
                  final cats = links
                      .map((link) => (link['categories'] as Map<String, dynamic>? ?? {}))
                      .toList();

                  final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
                  final now = DateTime.now();
                  final diff = expiry.difference(now);
                  final daysLeft = diff.inDays;
                  final hoursLeft = diff.inHours % 24;
                  final quantity = (item['quantity'] as int?) ?? 1;
                  final firstCat = cats.isNotEmpty ? cats.first : null;
                  final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
                  final name = (item['name'] as String?)?.trim().isNotEmpty == true ? (item['name'] as String) : 'Unnamed';
                  final isSelected = _selectedIds.contains(id);

                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    child: InkWell(
                      onLongPress: () => _toggleSelection(id, item),
                      onTap: () {
                        if (selectionActive) {
                          _toggleSelection(id, item);
                          return;
                        }
                        // Normal tap: maybe open item details/other actions (not implemented)
                      },
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
                                if (isSelected)
                                  const Positioned(
                                    right: -2,
                                    top: -2,
                                    child: CircleAvatar(radius: 10, backgroundColor: Colors.blueAccent, child: Icon(Icons.check, size: 12, color: Colors.white)),
                                  )
                                else
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
                                  Text(daysLeft >= 0 ? 'Expires in $daysLeft day(s) ${hoursLeft}h' : 'Expired ${-daysLeft} day(s) ago'),
                                  if (cats.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      clipBehavior: Clip.hardEdge,
                                      children: cats.map((c) {
                                        final iconUrl = (c['icon_url'] as String?) ?? '';
                                        final label = (c['name'] as String?) ?? '';
                                        final catId = (c['id']?.toString() ?? '');
                                        final pill = Container(
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

                                        // clickable like dashboard: navigate to category page
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            if (catId.isNotEmpty) {
                                              Navigator.of(context).pushNamed(
                                                CategoriesPage.route,
                                                arguments: {'categoryId': catId, 'categoryName': label},
                                              );
                                            }
                                          },
                                          child: pill,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            // TRAILING area: status badge + popup
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
                                  child: Text(daysLeft >= 0 ? '$daysLeft d' : 'Exp', style: const TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    if (val == 'waste') {
                                      await widget.supa.logWaste(id, quantity);
                                      await refresh();
                                    } else if (val == 'donate') {
                                      // ask recipient
                                      final recipient = await showDialog<String?>(
                                        context: context,
                                        builder: (_) {
                                          String r = '';
                                          return AlertDialog(
                                            title: const Text('Offer donation'),
                                            content: TextFormField(
                                              decoration: const InputDecoration(labelText: 'Recipient info'),
                                              onChanged: (v) => r = v,
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
                                              TextButton(onPressed: () => Navigator.pop(context, r.trim()), child: const Text('Offer')),
                                            ],
                                          );
                                        },
                                      );
                                      if (recipient != null && recipient.isNotEmpty) {
                                        await widget.supa.offerDonation(id, recipient);
                                        await refresh();
                                      }
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
                                        await widget.supa.deleteInventoryItem(id);
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
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Bottom action bar for bulk selection
        if (selectionActive)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Text('${_selectedIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Donate selected',
                      onPressed: _performBulkDonate,
                      icon: const Icon(Icons.card_giftcard),
                    ),
                    IconButton(
                      tooltip: 'Log waste',
                      onPressed: _performBulkWaste,
                      icon: const Icon(Icons.delete_forever),
                    ),
                    IconButton(
                      tooltip: 'Delete selected',
                      onPressed: _confirmAndPerformBulkDelete,
                      icon: const Icon(Icons.delete),
                    ),
                    IconButton(
                      tooltip: 'Cancel selection',
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
