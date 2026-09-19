// lib/pages/categories_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

enum CategorySortOption {
  expiringSoonest,
  nameAZ,
  quantityHighLow,
}

class CategoriesPage extends StatefulWidget {
  static const route = '/categories';
  final SupabaseService supa;
  const CategoriesPage({required this.supa, super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  StreamSubscription<void>? _inventorySub;

  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _allItems = [];
  bool _isLoading = true;
  String? _loadError;

  // Selected Category (null means 'All Items')
  String? _selectedCatId;
  String? _selectedCatName;

  // Search & Sorting
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  CategorySortOption _sortOption = CategorySortOption.expiringSoonest;

  final ScrollController _categoryScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Auto-refresh when inventory changes elsewhere in the app
    try {
      _inventorySub = widget.supa.onInventoryChanged.listen((_) {
        if (mounted) _refreshData();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _searchCtrl.dispose();
    _categoryScrollCtrl.dispose();
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
        _selectedCatId = incomingId;
        _selectedCatName = incomingName;
        // Schedule scroll to selected category after build
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedCategory());
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        widget.supa.fetchCategories(),
        widget.supa.fetchInventory(),
      ]);

      if (!mounted) return;
      setState(() {
        _allCategories = results[0];
        _allItems = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    try {
      final results = await Future.wait([
        widget.supa.fetchCategories(),
        widget.supa.fetchInventory(),
      ]);
      if (!mounted) return;
      setState(() {
        _allCategories = results[0];
        _allItems = results[1];
      });
    } catch (_) {}
  }

  void _scrollToSelectedCategory() {
    if (_selectedCatId == null || _allCategories.isEmpty || !_categoryScrollCtrl.hasClients) return;
    final index = _allCategories.indexWhere((c) => c['id']?.toString() == _selectedCatId);
    if (index >= 0) {
      // Each chip is roughly 120-140px wide plus 8px spacing, + 1 for 'All Items'
      final targetOffset = (index + 1) * 125.0;
      _categoryScrollCtrl.animateTo(
        targetOffset.clamp(0.0, _categoryScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Filter and sort items based on current selection, search query, and sort mode
  List<Map<String, dynamic>> _getFilteredAndSortedItems() {
    List<Map<String, dynamic>> list = _allItems;

    // 1. Filter by category
    if (_selectedCatId != null) {
      list = list.where((item) {
        final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
        return links.any((l) {
          final catId = (l['category_id'] ?? l['categories']?['id'])?.toString();
          return catId == _selectedCatId;
        });
      }).toList();
    }

    // 2. Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((item) {
        final name = (item['name'] as String?)?.toLowerCase() ?? '';
        return name.contains(q);
      }).toList();
    }

    // 3. Sort items
    final sorted = List<Map<String, dynamic>>.from(list);
    switch (_sortOption) {
      case CategorySortOption.expiringSoonest:
        sorted.sort((a, b) {
          final expA = DateTime.tryParse(a['expiry_date'] as String? ?? '') ?? DateTime.now();
          final expB = DateTime.tryParse(b['expiry_date'] as String? ?? '') ?? DateTime.now();
          return expA.compareTo(expB);
        });
        break;
      case CategorySortOption.nameAZ:
        sorted.sort((a, b) {
          final nameA = (a['name'] as String?)?.toLowerCase() ?? '';
          final nameB = (b['name'] as String?)?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });
        break;
      case CategorySortOption.quantityHighLow:
        sorted.sort((a, b) {
          final qtyA = (a['quantity'] as int?) ?? 1;
          final qtyB = (b['quantity'] as int?) ?? 1;
          return qtyB.compareTo(qtyA);
        });
        break;
    }

    return sorted;
  }

  // Count items belonging to a specific category
  int _getItemCountForCategory(String? categoryId) {
    if (categoryId == null) return _allItems.length;
    return _allItems.where((item) {
      final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
      return links.any((l) {
        final cId = (l['category_id'] ?? l['categories']?['id'])?.toString();
        return cId == categoryId;
      });
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredAndSortedItems();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildCurvedGradientHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGradientStart))
          : _loadError != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: kGradientStart,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    children: [
                      _buildCategoryCarouselSection(),
                      const SizedBox(height: 12),
                      _buildSortAndCountRow(filteredItems.length),
                      const SizedBox(height: 8),
                      if (filteredItems.isEmpty)
                        _buildEmptyItemsState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredItems.length,
                          itemBuilder: (ctx, i) => _buildItemCard(filteredItems[i]),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ==================== 1. CURVED GRADIENT HEADER ====================
  PreferredSizeWidget _buildCurvedGradientHeader() {
    final totalCount = _allItems.length;
    final catCount = _allCategories.length;
    final headerSubtitle = _selectedCatId == null
        ? '$totalCount items across $catCount categories'
        : 'Filtered by ${_selectedCatName ?? 'Category'} (${_getItemCountForCategory(_selectedCatId)} items)';

    return PreferredSize(
      preferredSize: Size.fromHeight(_isSearchOpen ? 142 : 106),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kGradientStart, kGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back button matching dashboard translucent glassmorphism
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        tooltip: 'Back',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Live Counter
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            headerSubtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Search button
                    Container(
                      decoration: BoxDecoration(
                        color: _isSearchOpen ? Colors.white : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.search,
                          color: _isSearchOpen ? kGradientStart : Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Search items',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (!_isSearchOpen) {
                              _searchCtrl.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Refresh button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: _refreshData,
                      ),
                    ),
                  ],
                ),

                // Collapsible Search Input
                if (_isSearchOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search in ${_selectedCatName ?? 'all items'}...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18, color: kGradientStart),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 2. CATEGORY CAROUSEL SECTION ====================
  Widget _buildCategoryCarouselSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with scroll indicator cue for mobile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'CATEGORIES (${_allCategories.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swipe for more',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey[500]),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Horizontal Swipeable Category Carousel
        SizedBox(
          height: 44,
          child: ListView.builder(
            controller: _categoryScrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _allCategories.length + 1, // +1 for "All Items"
            itemBuilder: (context, index) {
              if (index == 0) {
                // "All Items" Chip
                final isSelected = _selectedCatId == null;
                final totalCount = _allItems.length;
                return _buildCategoryPill(
                  id: null,
                  name: 'All Items',
                  iconUrl: null,
                  itemCount: totalCount,
                  isSelected: isSelected,
                  fallbackIcon: Icons.grid_view_rounded,
                );
              }

              final cat = _allCategories[index - 1];
              final id = cat['id']?.toString() ?? '';
              final name = (cat['name'] as String?) ?? 'Category';
              final iconUrl = (cat['icon_url'] as String?) ?? '';
              final isSelected = _selectedCatId == id;
              final count = _getItemCountForCategory(id);

              return _buildCategoryPill(
                id: id,
                name: name,
                iconUrl: iconUrl,
                itemCount: count,
                isSelected: isSelected,
                fallbackIcon: Icons.eco_outlined,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill({
    required String? id,
    required String name,
    required String? iconUrl,
    required int itemCount,
    required bool isSelected,
    required IconData fallbackIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            setState(() {
              if (id == null) {
                _selectedCatId = null;
                _selectedCatName = null;
              } else {
                _selectedCatId = id;
                _selectedCatName = name;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [kGradientStart, Color(0xFF00B074)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[300]!,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: kGradientStart.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconUrl != null && iconUrl.isNotEmpty)
                  Image.network(
                    iconUrl,
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) => Icon(
                      fallbackIcon,
                      size: 18,
                      color: isSelected ? Colors.white : kGradientStart,
                    ),
                  )
                else
                  Icon(
                    fallbackIcon,
                    size: 18,
                    color: isSelected ? Colors.white : kGradientStart,
                  ),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 6),
                // Item count badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$itemCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 3. SORT & COUNT BAR ====================
  Widget _buildSortAndCountRow(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'item' : 'items'} found',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          const Spacer(),
          // Sort Menu
          PopupMenuButton<CategorySortOption>(
            initialValue: _sortOption,
            onSelected: (opt) => setState(() => _sortOption = opt),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 16, color: kGradientStart),
                  const SizedBox(width: 6),
                  Text(
                    _getSortLabel(_sortOption),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                ],
              ),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: CategorySortOption.expiringSoonest,
                child: Text('Expiring Soonest', style: TextStyle(fontSize: 13)),
              ),
              const PopupMenuItem(
                value: CategorySortOption.nameAZ,
                child: Text('Name (A–Z)', style: TextStyle(fontSize: 13)),
              ),
              const PopupMenuItem(
                value: CategorySortOption.quantityHighLow,
                child: Text('Quantity (High–Low)', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSortLabel(CategorySortOption opt) {
    switch (opt) {
      case CategorySortOption.expiringSoonest:
        return 'Expiring';
      case CategorySortOption.nameAZ:
        return 'Name A–Z';
      case CategorySortOption.quantityHighLow:
        return 'Quantity';
    }
  }

  // ==================== 4. MODERN ITEM CARDS ====================
  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = (item['name'] as String?)?.trim().isNotEmpty == true
        ? (item['name'] as String)
        : 'Unnamed Item';
    final quantity = (item['quantity'] as int?) ?? 1;
    final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final diff = expiry.difference(now);
    final daysLeft = diff.inDays;

    final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
    final cats = links.map((link) => (link['categories'] as Map<String, dynamic>? ?? {})).toList();
    final firstCat = cats.isNotEmpty ? cats.first : null;
    final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
    final catName = firstCat != null ? (firstCat['name'] as String?) : null;

    // Urgency Colors
    final Color urgencyBg;
    final Color urgencyText;
    final String urgencyLabel;

    if (daysLeft < 0) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyText = const Color(0xFFDC2626);
      urgencyLabel = 'Expired ${-daysLeft}d ago';
    } else if (daysLeft == 0) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyText = const Color(0xFFDC2626);
      urgencyLabel = 'Expires today';
    } else if (daysLeft == 1) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = 'Expires tomorrow';
    } else if (daysLeft <= 3) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = '$daysLeft days left';
    } else {
      urgencyBg = const Color(0xFFDCFCE7);
      urgencyText = const Color(0xFF16A34A);
      urgencyLabel = '$daysLeft days left';
    }

    final dateFmt = DateFormat('MMM d, y');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showItemDetailsBottomSheet(item, daysLeft, expiry),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC).withOpacity(0.5)),
                  ),
                  child: Center(
                    child: (catIcon != null && catIcon.isNotEmpty)
                        ? Image.network(
                            catIcon,
                            width: 24,
                            height: 24,
                            errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: kGradientStart, size: 22),
                          )
                        : const Icon(Icons.eco, color: kGradientStart, size: 22),
                  ),
                ),
                const SizedBox(width: 12),

                // Name, Category Tag & Expiry Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (catName != null) ...[
                            Text(
                              catName,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                            Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                          Text(
                            dateFmt.format(expiry.toLocal()),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Urgency Pill + Quantity Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        urgencyLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: urgencyText),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 5. INTERACTIVE ITEM DETAILS MODAL ====================
  void _showItemDetailsBottomSheet(Map<String, dynamic> item, int daysLeft, DateTime expiry) {
    final itemId = item['id']?.toString() ?? '';
    final name = (item['name'] as String?)?.trim().isNotEmpty == true
        ? (item['name'] as String)
        : 'Unnamed Item';
    final quantity = (item['quantity'] as int?) ?? 1;

    final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
    final cats = links.map((link) => (link['categories'] as Map<String, dynamic>? ?? {})).toList();
    final firstCat = cats.isNotEmpty ? cats.first : null;
    final catName = firstCat != null ? (firstCat['name'] as String?) : 'General';
    final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;

    final dateFmt = DateFormat('EEEE, MMMM d, y');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Center(
                        child: (catIcon != null && catIcon.isNotEmpty)
                            ? Image.network(catIcon, width: 28, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: kGradientStart, size: 26))
                            : const Icon(Icons.eco, color: kGradientStart, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category: $catName • Qty: $quantity',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Expiry info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: daysLeft <= 1
                        ? const Color(0xFFFEF2F2)
                        : (daysLeft <= 3 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: daysLeft <= 1
                          ? const Color(0xFFFECACA)
                          : (daysLeft <= 3 ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        daysLeft <= 1 ? Icons.warning_amber_rounded : Icons.access_time_filled,
                        color: daysLeft <= 1
                            ? const Color(0xFFDC2626)
                            : (daysLeft <= 3 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              daysLeft < 0
                                  ? 'Item expired ${-daysLeft} day(s) ago'
                                  : (daysLeft == 0 ? 'Item expires today' : '$daysLeft days remaining until expiry'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: daysLeft <= 1
                                    ? const Color(0xFFDC2626)
                                    : (daysLeft <= 3 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Expiry Date: ${dateFmt.format(expiry.toLocal())}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons Row
                Row(
                  children: [
                    // Mark as Consumed Button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Consumed'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B074),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (quantity > 1) {
                            _promptConsumeDialog(itemId, name, quantity);
                          } else {
                            await widget.supa.consumeItem(itemId, 1);
                            if (!mounted) return;
                            showCornerToast(context, message: 'Item marked as consumed!');
                            _refreshData();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Log as Waste Button
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                        label: const Text('Log Waste'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          _promptLogWasteDialog(itemId, name, quantity);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete item icon
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      tooltip: 'Remove',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (quantity > 1) {
                          _promptRemoveDialog(itemId, name, quantity);
                        } else {
                          await widget.supa.deleteInventoryItem(itemId);
                          if (!mounted) return;
                          showCornerToast(context, message: 'Item deleted');
                          _refreshData();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptConsumeDialog(String itemId, String itemName, int maxQty) {
    int consumeQty = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Color(0xFF00B074), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Mark as Consumed',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity consumed:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: consumeQty > 1 ? () => setDialogState(() => consumeQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$consumeQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: consumeQty < maxQty ? () => setDialogState(() => consumeQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B074),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await widget.supa.consumeItem(itemId, consumeQty);
                    if (!mounted) return;
                    final remaining = maxQty - consumeQty;
                    final msg = remaining > 0
                        ? 'Consumed $consumeQty of $itemName ($remaining remaining)'
                        : 'Consumed all $itemName!';
                    showCornerToast(context, message: msg);
                    _refreshData();
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptRemoveDialog(String itemId, String itemName, int maxQty) {
    int removeQty = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Remove from Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity to remove:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: removeQty > 1 ? () => setDialogState(() => removeQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$removeQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: removeQty < maxQty ? () => setDialogState(() => removeQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    if (removeQty >= maxQty) {
                      await widget.supa.deleteInventoryItem(itemId);
                    } else {
                      await widget.supa.updateItemQuantity(itemId, maxQty - removeQty);
                    }
                    if (!mounted) return;
                    final remaining = maxQty - removeQty;
                    final msg = remaining > 0
                        ? 'Removed $removeQty of $itemName ($remaining remaining)'
                        : 'Removed $itemName from inventory';
                    showCornerToast(context, message: msg);
                    _refreshData();
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _promptLogWasteDialog(String itemId, String itemName, int maxQty) {
    String selectedReason = 'Expired';
    int wasteQty = 1;
    final reasons = ['Expired', 'Spoiled', 'Leftover', 'Moldy', 'Other'];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Log Waste',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item: $itemName',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text('Reason for waste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    borderRadius: BorderRadius.circular(16),
                    dropdownColor: Colors.white,
                    elevation: 4,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFEF4444)),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      ),
                    ),
                    items: reasons.map((r) {
                      IconData iconData;
                      switch (r) {
                        case 'Expired':
                          iconData = Icons.alarm_off_outlined;
                          break;
                        case 'Spoiled':
                          iconData = Icons.sentiment_dissatisfied_outlined;
                          break;
                        case 'Leftover':
                          iconData = Icons.restaurant_outlined;
                          break;
                        case 'Moldy':
                          iconData = Icons.warning_amber_rounded;
                          break;
                        default:
                          iconData = Icons.help_outline_rounded;
                      }
                      return DropdownMenuItem(
                        value: r,
                        child: Row(
                          children: [
                            Icon(iconData, size: 16, color: const Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity to waste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: wasteQty > 1
                                  ? () => setDialogState(() => wasteQty--)
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '$wasteQty',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: wasteQty < maxQty
                                  ? () => setDialogState(() => wasteQty++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await widget.supa.logWaste(itemId, wasteQty, selectedReason);
                    if (!mounted) return;
                    final remaining = maxQty - wasteQty;
                    final msg = remaining > 0
                        ? 'Logged $wasteQty of $itemName as waste ($remaining remaining)'
                        : 'Logged all $itemName as waste';
                    showCornerToast(context, message: msg);
                    _refreshData();
                  },
                  child: const Text('Log Waste'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==================== EMPTY & ERROR STATES ====================
  Widget _buildEmptyItemsState() {
    final hasCategory = _selectedCatId != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 40, color: kGradientStart),
          ),
          const SizedBox(height: 14),
          Text(
            hasCategory
                ? 'No items found in "${_selectedCatName ?? 'Category'}"'
                : (_searchQuery.isNotEmpty ? 'No items match "$_searchQuery"' : 'Your inventory is empty'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasCategory
                ? 'Items tagged with this category will appear here.'
                : 'Add food items from the dashboard to organize them by category.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (hasCategory) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _selectedCatId = null;
                _selectedCatName = null;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: kGradientStart,
                side: const BorderSide(color: kGradientStart),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Show All Items'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text('Error loading categories', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_loadError ?? 'Unknown error', style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: kGradientStart, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
