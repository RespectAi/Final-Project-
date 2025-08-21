// lib/pages/categories_page.dart
import 'dart:async';
import 'dart:math';
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
  StreamSubscription<void>? _inventorySub;

  String? _selectedCatId;
  String? _selectedCatName;
  Future<List<Map<String, dynamic>>>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _catsFuture = widget.supa.fetchCategories();

    // Listen for inventory changes and refresh selected category automatically.
    try {
      _inventorySub = widget.supa.onInventoryChanged.listen((_) {
        if (mounted && _selectedCatId != null) {
          _refreshItems();
        }
      });
    } catch (_) {
      // ignore if stream unavailable
    }
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    super.dispose();
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

  void _clearSelection() {
    setState(() {
      _selectedCatId = null;
      _selectedCatName = null;
      _itemsFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(context, 'Categories', showBackIfCanPop: true),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _catsFuture,
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error loading categories: ${snap.error}'));
            }

            final cats = snap.data ?? [];
            if (cats.isEmpty) {
              return const Center(child: Text('No categories found'));
            }

            // Layout: left = selected card, right = 3xN grid (shows 2 rows height, scrollable)
            return LayoutBuilder(builder: (ctx, constraints) {
              // Constrain left width and right width to avoid overflow

              // Responsive breakpoint: below this we stack selected card above grid
              const breakpoint = 580.0;
              final gap = 16.0;

              if (constraints.maxWidth < breakpoint) {
                // Small screen: stack selected card above grid
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: double.infinity, child: _buildSelectedCard()),
                    const SizedBox(height: 12),
                    _buildGrid(cats, constraints.maxWidth),
                    const SizedBox(height: 12),
                    Expanded(child: _selectedCatId == null ? _noSelectionBody() : _itemsListView()),
                  ],
                );
              }

              // Large screen: make left and right roughly equal width (half each) with gap
              final usableWidth = constraints.maxWidth - gap - 24; // leave some padding tolerance
              final leftWidth = (usableWidth / 4).clamp(220.0, 640.0);
              final rightWidth = (usableWidth - leftWidth);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: leftWidth, child: _buildSelectedCard()),
                      SizedBox(width: gap),
                      SizedBox(width: rightWidth, child: _buildGrid(cats, rightWidth)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(child: _selectedCatId == null ? _noSelectionBody() : _itemsListView()),
                ],
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> cats, double availableWidth) {
    // determine tile sizes for a 3-column grid and a short height like in your sketch
    const crossCount = 3;
    const spacing = 8.0;
    final availableWidthForTiles = max(0.0, availableWidth - (crossCount - 1) * spacing);
    final tileWidth = (availableWidthForTiles / crossCount).clamp(72.0, 240.0);
    // wide aspect ratio makes tile height small
    const childAspectRatio = 3.8;
    final tileHeight = tileWidth / childAspectRatio;
    const gridVisibleRows = 2;
    final gridHeight = tileHeight * gridVisibleRows + spacing * (gridVisibleRows - 1);

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(right: 4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: cats.length,
        itemBuilder: (context, idx) {
          final c = cats[idx];
          final id = c['id']?.toString() ?? '';
          final name = (c['name'] as String?) ?? '';
          final iconUrl = (c['icon_url'] as String?) ?? '';
          final selected = _selectedCatId == id;

          return GestureDetector(
            onTap: () => _selectCategory(id, name),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.green[50] : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? Colors.green : Colors.black12),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.green.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconUrl.isNotEmpty)
                    Image.network(iconUrl, width: 18, height: 18, errorBuilder: (_, __, ___) => const SizedBox())
                  else
                    const Icon(Icons.eco, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedCard() {
    if (_selectedCatId == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('Select a category to view its items', style: TextStyle(fontWeight: FontWeight.w600))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.label, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedCatName ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
  TextSpan(
    children: [
      const TextSpan(text: 'Showing items for '),
      TextSpan(
        text:'${_selectedCatName ?? 'Unknown'} ',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  ),
  style: const TextStyle(color: Colors.black87),
),

          // Wrap buttons so they won't overflow; on small screens they will wrap to next line.
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton(
                onPressed: _refreshItems,
                child: const Text('Refresh'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
              OutlinedButton(
                onPressed: _clearSelection,
                child: const Text('Clear'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noSelectionBody() {
    return Center(
      child: Text(
        'No category selected.\nPick one from the grid above.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black.withOpacity(0.6)),
      ),
    );
  }

  Widget _itemsListView() {
    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
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
              final cats = links.map((link) => (link['categories'] as Map<String, dynamic>? ?? {})).toList();
              final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
              final now = DateTime.now();
              final diff = expiry.difference(now);
              final daysLeft = diff.inDays;
              final hoursLeft = diff.inHours % 24;
              final quantity = (item['quantity'] as int?) ?? 1;
              final firstCat = cats.isNotEmpty ? cats.first : null;
              final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
              final name = (item['name'] as String?)?.trim().isNotEmpty == true ? (item['name'] as String) : 'Unnamed';

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
                  subtitle: Text(daysLeft >= 0
                      ? 'Expires in $daysLeft day(s) ${hoursLeft}h • ${dateFmt.format(expiry.toLocal())}'
                      : 'Expired ${-daysLeft} day(s) ago • ${dateFmt.format(expiry.toLocal())}'),
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
    );
  }
}
