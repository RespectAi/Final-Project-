// lib/pages/categories_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class CategoriesPage extends StatefulWidget {
  static const route = '/categories';
  final SupabaseService supa;
  const CategoriesPage({required this.supa, Key? key}) : super(key: key);

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<List<Map<String, dynamic>>> _catsFuture;

  String? _selectedCatId;
  String? _selectedCatName;
  Future<List<Map<String, dynamic>>>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _catsFuture = widget.supa.fetchCategories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final incomingId = args['categoryId']?.toString();
      final incomingName = args['categoryName']?.toString();
      if (incomingId != null && incomingId.isNotEmpty) {
        _selectCategory(incomingId, incomingName);
      }
    }
  }

  void _selectCategory(String id, String? name) {
    setState(() {
      _selectedCatId = id;
      _selectedCatName = name;
      _itemsFuture = widget.supa.fetchInventoryByCategory(id);
    });
  }

  Future<void> _refreshItems() async {
    if (_selectedCatId != null) {
      setState(() {
        _itemsFuture = widget.supa.fetchInventoryByCategory(_selectedCatId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        'Categories',
        showBackIfCanPop: true,
      ),
      body: Column(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _catsFuture,
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading categories: ${snap.error}'),
                );
              }
              final cats = snap.data ?? [];
              if (cats.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No categories found'),
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats.map((c) {
                    final id = c['id']?.toString() ?? '';
                    final name = (c['name'] as String?) ?? '';
                    final iconUrl = (c['icon_url'] as String?) ?? '';
                    final selected = _selectedCatId == id;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (iconUrl.isNotEmpty)
                            Image.network(iconUrl, width: 18, height: 18)
                          else
                            const Icon(Icons.eco, size: 16),
                          const SizedBox(width: 6),
                          Text(name),
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) => _selectCategory(id, name),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          if (_selectedCatId == null)
            Expanded(
              child: Center(
                child: Text(
                  'Select a category to view its items',
                  style: TextStyle(color: Colors.black.withOpacity(0.6)),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshItems,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _itemsFuture,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Text(
                              'No items in "${_selectedCatName ?? 'Category'}"',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      );
                    }

                    final dateFmt = DateFormat('yMMMd');
                    return ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];

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
                        final name = (item['name'] as String?)?.trim().isNotEmpty == true
                            ? (item['name'] as String)
                            : 'Unnamed';

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[50],
                              child: (catIcon != null && catIcon.isNotEmpty)
                                  ? ClipOval(
                                      child: Image.network(
                                        catIcon,
                                        width: 28,
                                        height: 28,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.eco, size: 20),
                            ),
                            title: Text(name),
                            subtitle: Text(
                              daysLeft >= 0
                                  ? 'Expires in $daysLeft day(s) ${hoursLeft}h • ${dateFmt.format(expiry.toLocal())}'
                                  : 'Expired ${-daysLeft} day(s) ago • ${dateFmt.format(expiry.toLocal())}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: daysLeft <= 1 ? Colors.red[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Text('x$quantity', style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
