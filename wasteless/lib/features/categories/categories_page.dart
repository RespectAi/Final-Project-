// lib/features/categories/categories_page.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/supabase_service.dart';
import 'widgets/category_action_dialogs.dart';
import 'widgets/category_carousel.dart';
import 'widgets/category_item_card.dart';

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
      final targetOffset = (index + 1) * 125.0;
      _categoryScrollCtrl.animateTo(
        targetOffset.clamp(0.0, _categoryScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

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
      list = list.where((item) {
        final name = (item['name'] as String?)?.toLowerCase() ?? '';
        final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
        final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
        final catNames = cats.map((c) => (c['name'] as String?)?.toLowerCase() ?? '').join(' ');
        return name.contains(_searchQuery) || catNames.contains(_searchQuery);
      }).toList();
    }

    // 3. Sort items
    final sortedList = List<Map<String, dynamic>>.from(list);
    switch (_sortOption) {
      case CategorySortOption.expiringSoonest:
        sortedList.sort((a, b) {
          final aDate = DateTime.tryParse(a['expiry_date'] as String? ?? '') ?? DateTime(2099);
          final bDate = DateTime.tryParse(b['expiry_date'] as String? ?? '') ?? DateTime(2099);
          return aDate.compareTo(bDate);
        });
        break;
      case CategorySortOption.nameAZ:
        sortedList.sort((a, b) {
          final aName = (a['name'] as String?)?.toLowerCase() ?? '';
          final bName = (b['name'] as String?)?.toLowerCase() ?? '';
          return aName.compareTo(bName);
        });
        break;
      case CategorySortOption.quantityHighLow:
        sortedList.sort((a, b) {
          final aQty = (a['quantity'] as int?) ?? 1;
          final bQty = (b['quantity'] as int?) ?? 1;
          return bQty.compareTo(aQty);
        });
        break;
    }

    return sortedList;
  }

  int _getItemCountForCategory(String? catId) {
    if (catId == null) return _allItems.length;
    return _allItems.where((item) {
      final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
      return links.any((l) {
        final id = (l['category_id'] ?? l['categories']?['id'])?.toString();
        return id == catId;
      });
    }).length;
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

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredAndSortedItems();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildCurvedGradientHeader(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gradientStart))
          : _loadError != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppColors.gradientStart,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    children: [
                      CategoryCarousel(
                        scrollController: _categoryScrollCtrl,
                        allCategories: _allCategories,
                        selectedCatId: _selectedCatId,
                        getItemCountForCategory: _getItemCountForCategory,
                        onSelectCategory: (id, name) {
                          setState(() {
                            _selectedCatId = id;
                            _selectedCatName = name;
                          });
                        },
                      ),
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
                          itemBuilder: (ctx, i) {
                            final item = filteredItems[i];
                            return CategoryItemCard(
                              item: item,
                              onTap: () {
                                CategoryActionDialogs.showItemDetailsBottomSheet(
                                  context: context,
                                  supa: widget.supa,
                                  item: item,
                                  onMutated: _refreshData,
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

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
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
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
                    Container(
                      decoration: BoxDecoration(
                        color: _isSearchOpen ? Colors.white : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.search,
                          color: _isSearchOpen ? AppColors.gradientStart : Colors.white,
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
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
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
                if (_isSearchOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search items or categories...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.gradientStart),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
                  const Icon(Icons.sort, size: 16, color: AppColors.gradientStart),
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
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: CategorySortOption.expiringSoonest,
                child: Text('Expiring Soonest', style: TextStyle(fontSize: 13)),
              ),
              PopupMenuItem(
                value: CategorySortOption.nameAZ,
                child: Text('Name (A–Z)', style: TextStyle(fontSize: 13)),
              ),
              PopupMenuItem(
                value: CategorySortOption.quantityHighLow,
                child: Text('Quantity (High–Low)', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
            child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.gradientStart),
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
                foregroundColor: AppColors.gradientStart,
                side: const BorderSide(color: AppColors.gradientStart),
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
            const Text('Error loading categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_loadError ?? 'Unknown error', style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gradientStart, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
