// lib/pages/inventory_list.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../features/categories/categories_page.dart';
import '../features/categories/widgets/category_action_dialogs.dart';
import '../pages/add_item_page.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

enum _InventoryFilter { all, expiringSoon, fresh, expired }
enum _InventorySort { expiringSoonest, nameAZ, quantityDesc, recentlyAdded }

class InventoryList extends StatefulWidget {
  final SupabaseService supa;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onBackToHome;

  const InventoryList({
    required this.supa,
    this.onSelectionChanged,
    this.onBackToHome,
    super.key,
  });

  @override
  InventoryListState createState() => InventoryListState();
}

class InventoryListState extends State<InventoryList> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  StreamSubscription<void>? _inventorySub;

  // Multi-selection state
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedItems = {};

  // Inline expansion state
  final Set<String> _expandedIds = {};

  // Search, Filter & Sort state
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _InventoryFilter _selectedFilter = _InventoryFilter.all;
  _InventorySort _selectedSort = _InventorySort.expiringSoonest;

  bool get isSelectionActive => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadItems();

    // Subscribe to reactive inventory updates
    _inventorySub = widget.supa.onInventoryChanged.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      _itemsFuture = widget.supa.fetchInventory();
    });
  }

  Future<void> refresh() async {
    setState(() {
      _itemsFuture = widget.supa.fetchInventory();
      _clearSelection();
    });
  }

  // ---------- Selection Management ----------

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
    widget.onSelectionChanged?.call();
  }

  void _clearSelection() {
    if (_selectedIds.isNotEmpty) {
      setState(() {
        _selectedIds.clear();
        _selectedItems.clear();
      });
      widget.onSelectionChanged?.call();
    }
  }

  void _selectAll(List<Map<String, dynamic>> visibleItems) {
    setState(() {
      for (final item in visibleItems) {
        final id = item['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          _selectedIds.add(id);
          _selectedItems[id] = item;
        }
      }
    });
    widget.onSelectionChanged?.call();
  }

  // ---------- Expansion Management ----------

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  // ---------- Bulk Actions ----------

  Future<void> _performBulkConsume() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_outline, color: Color(0xFF00B074), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Consume Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text('Mark all $count selected item(s) as consumed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B074),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in List<String>.from(_selectedIds)) {
        final item = _selectedItems[id];
        final qty = (item?['quantity'] as int?) ?? 1;
        await widget.supa.consumeItem(id, qty);
      }
      if (mounted) {
        showCornerToast(context, message: 'Consumed $count item(s)');
        await refresh();
      }
    }
  }

  Future<void> _performBulkWaste() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    String selectedReason = 'Expired';
    final reasons = ['Expired', 'Spoiled', 'Leftover', 'Moldy', 'Other'];

    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Log Waste for Selected', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log $count item(s) as waste.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              const SizedBox(height: 12),
              const Text('Reason:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedReason,
                borderRadius: BorderRadius.circular(12),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, selectedReason),
              child: const Text('Log Waste'),
            ),
          ],
        ),
      ),
    );

    if (reason != null) {
      for (final id in List<String>.from(_selectedIds)) {
        final item = _selectedItems[id];
        final qty = (item?['quantity'] as int?) ?? 1;
        await widget.supa.logWaste(id, qty, reason);
      }
      if (mounted) {
        showCornerToast(context, message: 'Logged $count item(s) as waste');
        await refresh();
      }
    }
  }

  Future<void> _performBulkDonate() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    String recipient = '';

    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.card_giftcard, color: Color(0xFF0277BD), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Donate Selected Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offering $count item(s) for donation.', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Recipient / Organization info',
                hintText: 'e.g. Local Food Bank, John Doe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => recipient = v.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0277BD),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, recipient.isEmpty ? 'General Donation' : recipient),
            child: const Text('Donate'),
          ),
        ],
      ),
    );

    if (res != null) {
      for (final id in List<String>.from(_selectedIds)) {
        await widget.supa.offerDonation(id, res);
      }
      if (mounted) {
        showCornerToast(context, message: 'Offered $count item(s) for donation');
        await refresh();
      }
    }
  }

  Future<void> _performBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Selected Items?'),
        content: Text('Remove $count item(s) permanently from inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      for (final id in List<String>.from(_selectedIds)) {
        await widget.supa.deleteInventoryItem(id);
      }
      if (mounted) {
        showCornerToast(context, message: 'Deleted $count item(s)');
        await refresh();
      }
    }
  }

  // ---------- Sort Selector Bottom Sheet ----------

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sort Inventory By',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Expiring Soonest (Default)', _InventorySort.expiringSoonest, Icons.access_time_rounded),
                _buildSortOption('Alphabetical (A - Z)', _InventorySort.nameAZ, Icons.sort_by_alpha_rounded),
                _buildSortOption('Quantity (Highest first)', _InventorySort.quantityDesc, Icons.format_list_numbered_rounded),
                _buildSortOption('Recently Added', _InventorySort.recentlyAdded, Icons.calendar_today_rounded),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, _InventorySort sortValue, IconData icon) {
    final isSelected = _selectedSort == sortValue;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _selectedSort = sortValue);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? AppColors.primary : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ---------- Filtering & Sorting Helpers ----------

  List<Map<String, dynamic>> _filterAndSortItems(List<Map<String, dynamic>> rawItems) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Filter by search query
    var items = rawItems.where((item) {
      if (_searchQuery.isEmpty) return true;
      final name = (item['name'] as String?)?.toLowerCase() ?? '';
      final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
      final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
      final catNames = cats.map((c) => (c['name'] as String?)?.toLowerCase() ?? '').join(' ');
      return name.contains(_searchQuery) || catNames.contains(_searchQuery);
    }).toList();

    // 2. Filter by status chip
    items = items.where((item) {
      final expiryStr = item['expiry_date'] as String?;
      final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
      final expiryDay = expiry != null ? DateTime(expiry.year, expiry.month, expiry.day) : today;
      final daysLeft = expiryDay.difference(today).inDays;

      switch (_selectedFilter) {
        case _InventoryFilter.all:
          return true;
        case _InventoryFilter.expiringSoon:
          return daysLeft >= 0 && daysLeft <= 3;
        case _InventoryFilter.fresh:
          return daysLeft > 3;
        case _InventoryFilter.expired:
          return daysLeft < 0;
      }
    }).toList();

    // 3. Sort
    items.sort((a, b) {
      switch (_selectedSort) {
        case _InventorySort.expiringSoonest:
          final expA = DateTime.tryParse(a['expiry_date'] as String? ?? '') ?? DateTime(2099);
          final expB = DateTime.tryParse(b['expiry_date'] as String? ?? '') ?? DateTime(2099);
          return expA.compareTo(expB);

        case _InventorySort.nameAZ:
          final nameA = (a['name'] as String?)?.toLowerCase() ?? '';
          final nameB = (b['name'] as String?)?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);

        case _InventorySort.quantityDesc:
          final qtyA = (a['quantity'] as int?) ?? 1;
          final qtyB = (b['quantity'] as int?) ?? 1;
          return qtyB.compareTo(qtyA);

        case _InventorySort.recentlyAdded:
          final createdA = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(1970);
          final createdB = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(1970);
          return createdB.compareTo(createdA);
      }
    });

    return items;
  }

  String _getSortDisplayLabel() {
    switch (_selectedSort) {
      case _InventorySort.expiringSoonest:
        return 'Expiry';
      case _InventorySort.nameAZ:
        return 'A-Z';
      case _InventorySort.quantityDesc:
        return 'Qty';
      case _InventorySort.recentlyAdded:
        return 'Recent';
    }
  }

  // ---------- Build Method ----------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? const [];
        final filteredItems = _filterAndSortItems(allItems);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        int expiringSoonCount = 0;
        int freshCount = 0;
        int expiredCount = 0;

        for (final item in allItems) {
          final expiryStr = item['expiry_date'] as String?;
          final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
          final expiryDay = expiry != null ? DateTime(expiry.year, expiry.month, expiry.day) : today;
          final daysLeft = expiryDay.difference(today).inDays;
          if (daysLeft < 0) {
            expiredCount++;
          } else if (daysLeft <= 3) {
            expiringSoonCount++;
          } else {
            freshCount++;
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: _buildCurvedGradientHeader(
            totalCount: allItems.length,
            filteredCount: filteredItems.length,
            expiringSoonCount: expiringSoonCount,
          ),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: refresh,
                color: AppColors.gradientStart,
                child: ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  children: [
                    // Filter Chips + Sort Row right below the curved header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('All', _InventoryFilter.all, allItems.length),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Expiring', _InventoryFilter.expiringSoon, expiringSoonCount),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Fresh', _InventoryFilter.fresh, freshCount),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('Expired', _InventoryFilter.expired, expiredCount),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSortButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Items List Content or Empty State
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (snapshot.hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                              const SizedBox(height: 12),
                              Text('Error loading inventory: ${snapshot.error}', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: refresh, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    else if (filteredItems.isEmpty)
                      _buildEmptyState(hasActiveFilters: allItems.isNotEmpty)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: filteredItems.map((item) => _buildItemCard(item)).toList(),
                        ),
                      ),
                  ],
                ),
              ),

              // Floating Soft Silver Bulk Action Toolbar
              if (isSelectionActive)
                _buildFloatingBulkToolbar(visibleItems: filteredItems),
            ],
          ),
        );
      },
    );
  }

  // ---------- Curved Gradient Header (Identical height & styling to Category Page) ----------

  PreferredSizeWidget _buildCurvedGradientHeader({
    required int totalCount,
    required int filteredCount,
    required int expiringSoonCount,
  }) {
    final String headerSubtitle;
    if (_searchQuery.isNotEmpty) {
      headerSubtitle = 'Search results for "$_searchQuery" ($filteredCount items)';
    } else if (_selectedFilter == _InventoryFilter.expiringSoon) {
      headerSubtitle = 'Filtered: $filteredCount item(s) expiring soon';
    } else if (_selectedFilter == _InventoryFilter.fresh) {
      headerSubtitle = 'Filtered: $filteredCount fresh item(s)';
    } else if (_selectedFilter == _InventoryFilter.expired) {
      headerSubtitle = 'Filtered: $filteredCount expired item(s)';
    } else {
      headerSubtitle = '$totalCount items across inventory • $expiringSoonCount expiring soon';
    }

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
                    // Back Button (exact match to Category Page header)
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
                          } else if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Dynamic Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Inventory',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            headerSubtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Search Toggle Button (matching Category Page)
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

                    // Refresh Button (matching Category Page)
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
                        onPressed: refresh,
                      ),
                    ),
                  ],
                ),

                // Expandable Search Bar (displayed ONLY when search button is clicked)
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

  // ---------- Filter Chips & Sort Button Widgets ----------

  Widget _buildFilterChip(String label, _InventoryFilter filter, int count) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return InkWell(
      onTap: _showSortBottomSheet,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 15, color: Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              _getSortDisplayLabel(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  // ---------- Item Card Widget ----------

  Widget _buildItemCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final name = (item['name'] as String?)?.trim().isNotEmpty == true
        ? (item['name'] as String)
        : 'Unnamed Item';
    final quantity = (item['quantity'] as int?) ?? 1;

    final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
    final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
    final firstCat = cats.isNotEmpty ? cats.first : null;
    final catName = firstCat != null ? (firstCat['name'] as String? ?? 'General') : 'General';
    final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;

    final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
    final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = expiryDay.difference(today).inDays;

    final isSelected = _selectedIds.contains(id);
    final isExpanded = _expandedIds.contains(id);

    // Urgency pill styling matching Dashboard & Categories
    final Color urgencyBg;
    final Color urgencyText;
    final String urgencyLabel;

    if (daysLeft < 0) {
      urgencyBg = const Color(0xFFFDE8E8);
      urgencyText = const Color(0xFFE02424);
      urgencyLabel = 'Expired ${-daysLeft}d ago';
    } else if (daysLeft == 0) {
      urgencyBg = const Color(0xFFFDE8E8);
      urgencyText = const Color(0xFFE02424);
      urgencyLabel = 'Expires Today';
    } else if (daysLeft == 1) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = '1 Day Left';
    } else if (daysLeft <= 3) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = '$daysLeft Days Left';
    } else {
      urgencyBg = const Color(0xFFDEF7EC);
      urgencyText = const Color(0xFF046C4E);
      urgencyLabel = '$daysLeft Days Left';
    }

    final dateFmt = DateFormat('EEE, dd MMM yyyy, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _toggleSelection(id, item),
          onTap: () {
            if (isSelectionActive) {
              _toggleSelection(id, item);
            } else {
              _toggleExpanded(id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name & Subtitle + Urgency Badge + Chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading Avatar (with selection indicator badge)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF86EFAC).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Center(
                            child: (catIcon != null && catIcon.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      catIcon,
                                      width: 26,
                                      height: 26,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: AppColors.primary, size: 24),
                                    ),
                                  )
                                : const Icon(Icons.eco, color: AppColors.primary, size: 24),
                          ),
                        ),
                        if (isSelected)
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Title + Category + Quantity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  catName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(' • ', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                              // Prominent Quantity Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  'Qty: $quantity',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Urgency Pill + Chevron
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: urgencyBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            urgencyLabel,
                            style: TextStyle(
                              color: urgencyText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),

                // Inline Expanded Details Section
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timestamps Row 1: Date Added
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Added: ${dateFmt.format(createdAt.toLocal())}',
                                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Timestamps Row 2: Expiration Date
                        Row(
                          children: [
                            Icon(Icons.event_available_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Expires: ${dateFmt.format(expiry.toLocal())}',
                                style: TextStyle(
                                  color: daysLeft <= 1 ? const Color(0xFFDC2626) : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: daysLeft <= 1 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Categories Tag Wrap (Clickable)
                        if (cats.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: cats.map((c) {
                              final label = (c['name'] as String?) ?? '';
                              final iconUrl = (c['icon_url'] as String?) ?? '';
                              final catId = (c['id']?.toString() ?? '');

                              return InkWell(
                                onTap: () {
                                  if (catId.isNotEmpty) {
                                    Navigator.of(context).pushNamed(
                                      CategoriesPage.route,
                                      arguments: {'categoryId': catId, 'categoryName': label},
                                    ).then((_) => refresh());
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (iconUrl.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4),
                                          child: Image.network(iconUrl, width: 13, height: 13, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 13, color: Colors.blue)),
                                        ),
                                      Text(
                                        label,
                                        style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // 4 Direct Actions: Consume, Donate, Waste, Delete
                        Row(
                          children: [
                            // 1. Consume Button
                            Expanded(
                              child: _buildActionBtn(
                                label: 'Consume',
                                icon: Icons.check_circle_outline,
                                bg: const Color(0xFFDCFCE7),
                                fg: const Color(0xFF00B074),
                                borderColor: const Color(0xFF86EFAC),
                                onTap: () {
                                  CategoryActionDialogs.showConsumeDialog(
                                    context: context,
                                    supa: widget.supa,
                                    item: item,
                                    onMutated: refresh,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 2. Donate Button
                            Expanded(
                              child: _buildActionBtn(
                                label: 'Donate',
                                icon: Icons.card_giftcard_outlined,
                                bg: const Color(0xFFE0F2FE),
                                fg: const Color(0xFF0277BD),
                                borderColor: const Color(0xFFBAE6FD),
                                onTap: () {
                                  CategoryActionDialogs.showDonateDialog(
                                    context: context,
                                    supa: widget.supa,
                                    item: item,
                                    onMutated: refresh,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 3. Waste Button
                            Expanded(
                              child: _buildActionBtn(
                                label: 'Waste',
                                icon: Icons.delete_sweep_outlined,
                                bg: const Color(0xFFFEE2E2),
                                fg: const Color(0xFFEF4444),
                                borderColor: const Color(0xFFFECACA),
                                onTap: () {
                                  CategoryActionDialogs.showLogWasteDialog(
                                    context: context,
                                    supa: widget.supa,
                                    item: item,
                                    onMutated: refresh,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6),

                            // 4. Delete / Remove Button
                            Expanded(
                              child: _buildActionBtn(
                                label: 'Delete',
                                icon: Icons.delete_outline,
                                bg: const Color(0xFFF1F5F9),
                                fg: const Color(0xFF475569),
                                borderColor: const Color(0xFFCBD5E1),
                                onTap: () {
                                  CategoryActionDialogs.showRemoveDialog(
                                    context: context,
                                    supa: widget.supa,
                                    item: item,
                                    onMutated: refresh,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildActionBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Floating Bulk Action Toolbar ----------

  Widget _buildFloatingBulkToolbar({required List<Map<String, dynamic>> visibleItems}) {
    final allSelected = visibleItems.isNotEmpty && visibleItems.every((i) => _selectedIds.contains(i['id']?.toString()));

    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Toolbar Row: Count, Select All, Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedIds.length} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (allSelected) {
                      _clearSelection();
                    } else {
                      _selectAll(visibleItems);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _clearSelection,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bulk Actions Buttons Row
            Row(
              children: [
                // Bulk Consume
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Consume',
                    icon: Icons.check_circle_outline,
                    bg: const Color(0xFF00B074),
                    onTap: _performBulkConsume,
                  ),
                ),
                const SizedBox(width: 8),

                // Bulk Donate
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Donate',
                    icon: Icons.card_giftcard_outlined,
                    bg: const Color(0xFF0277BD),
                    onTap: _performBulkDonate,
                  ),
                ),
                const SizedBox(width: 8),

                // Bulk Waste
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Waste',
                    icon: Icons.delete_sweep_outlined,
                    bg: const Color(0xFFEF4444),
                    onTap: _performBulkWaste,
                  ),
                ),
                const SizedBox(width: 8),

                // Bulk Delete
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Delete',
                    icon: Icons.delete_outline,
                    bg: const Color(0xFF475569),
                    onTap: _performBulkDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
      ),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---------- Empty State ----------

  Widget _buildEmptyState({required bool hasActiveFilters}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  hasActiveFilters ? Icons.search_off_rounded : Icons.kitchen_outlined,
                  size: 32,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasActiveFilters
                    ? (_searchQuery.isNotEmpty ? 'No items matching "$_searchQuery"' : 'No items match filter')
                    : 'Inventory is Empty',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                hasActiveFilters
                    ? 'Try clearing the search query or selecting a different status filter'
                    : 'Add items to track expiry dates and reduce food waste',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              if (hasActiveFilters)
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedFilter = _InventoryFilter.all;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Reset Filters'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AddItemPage.route).then((_) => refresh());
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Your First Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
