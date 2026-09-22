// lib/pages/waste_log_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

enum _WasteSort { mostRecent, oldestFirst, quantityDesc, nameAZ }

class WasteLogPage extends StatefulWidget {
  static const route = '/waste';
  final SupabaseService supa;
  final VoidCallback? onBackToHome;

  const WasteLogPage({
    required this.supa,
    this.onBackToHome,
    super.key,
  });

  @override
  WasteLogPageState createState() => WasteLogPageState();
}

class WasteLogPageState extends State<WasteLogPage> {
  String? itemId;
  String itemName = '';
  int _qty = 1;
  String _selectedFormReason = 'Expired';
  final List<String> _commonReasons = ['Expired', 'Spoiled', 'Leftover', 'Moldy', 'Other'];

  late Future<List<Map<String, dynamic>>> _logsFuture;
  StreamSubscription<void>? _inventorySub;

  // Search & Filter & Sort state
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedReasonFilter; // null means 'All'
  _WasteSort _selectedSort = _WasteSort.mostRecent;

  // Multi-selection state
  final Set<String> _selectedIds = {};
  final Map<String, Map<String, dynamic>> _selectedItems = {};

  bool get isSelectionActive => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refreshLogs();

    // Auto-refresh when inventory or waste changes
    _inventorySub = widget.supa.onInventoryChanged.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      itemId = args['id']?.toString();
      itemName = (args['name'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _inventorySub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logsFuture = widget.supa.fetchWasteLogs();
      _clearSelection();
    });
  }

  void refresh() => _refreshLogs();

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
  }

  void _clearSelection() {
    if (_selectedIds.isNotEmpty) {
      setState(() {
        _selectedIds.clear();
        _selectedItems.clear();
      });
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
  }

  // ---------- Deletion Handlers ----------

  Future<void> _confirmDeleteSingle(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Waste Entry?'),
        content: Text('Remove log entry for "$name" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.supa.deleteWasteLog(id);
      if (mounted) {
        showCornerToast(context, message: 'Deleted waste log entry');
        await _refreshLogs();
      }
    }
  }

  Future<void> _performBulkDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Selected Entries?'),
        content: Text('Remove $count waste log entry(s) permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      for (final id in List<String>.from(_selectedIds)) {
        await widget.supa.deleteWasteLog(id);
      }
      if (mounted) {
        showCornerToast(context, message: 'Deleted $count waste log entry(s)');
        await _refreshLogs();
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
                  'Sort Waste Logs By',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Most Recent (Default)', _WasteSort.mostRecent, Icons.access_time_rounded),
                _buildSortOption('Oldest First', _WasteSort.oldestFirst, Icons.history_rounded),
                _buildSortOption('Quantity (Highest first)', _WasteSort.quantityDesc, Icons.format_list_numbered_rounded),
                _buildSortOption('Item Name (A - Z)', _WasteSort.nameAZ, Icons.sort_by_alpha_rounded),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, _WasteSort sortValue, IconData icon) {
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

  String _getSortDisplayLabel() {
    switch (_selectedSort) {
      case _WasteSort.mostRecent:
        return 'Recent';
      case _WasteSort.oldestFirst:
        return 'Oldest';
      case _WasteSort.quantityDesc:
        return 'Qty';
      case _WasteSort.nameAZ:
        return 'A-Z';
    }
  }

  // ---------- Filtering & Sorting Helpers ----------

  List<Map<String, dynamic>> _filterAndSortLogs(List<Map<String, dynamic>> rawLogs) {
    var logs = rawLogs.where((log) {
      final inv = log['inventory_items'] as Map<String, dynamic>?;
      final name = ((log['item_name'] as String?) ?? (inv?['name'] as String?) ?? '').toLowerCase();
      final reason = (log['reason'] as String?)?.toLowerCase() ?? '';

      // 1. Search query filter
      if (_searchQuery.isNotEmpty) {
        if (!name.contains(_searchQuery) && !reason.contains(_searchQuery)) {
          return false;
        }
      }

      // 2. Reason filter chip
      if (_selectedReasonFilter != null) {
        final filterLower = _selectedReasonFilter!.toLowerCase();
        if (filterLower == 'other') {
          final isStandard = _commonReasons
              .where((r) => r != 'Other')
              .any((r) => reason.contains(r.toLowerCase()));
          if (isStandard) return false;
        } else {
          if (!reason.contains(filterLower)) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    // 3. Sorting
    logs.sort((a, b) {
      switch (_selectedSort) {
        case _WasteSort.mostRecent:
          final dtA = DateTime.tryParse(a['logged_at'] as String? ?? '') ?? DateTime(1970);
          final dtB = DateTime.tryParse(b['logged_at'] as String? ?? '') ?? DateTime(1970);
          return dtB.compareTo(dtA);

        case _WasteSort.oldestFirst:
          final dtA = DateTime.tryParse(a['logged_at'] as String? ?? '') ?? DateTime(2099);
          final dtB = DateTime.tryParse(b['logged_at'] as String? ?? '') ?? DateTime(2099);
          return dtA.compareTo(dtB);

        case _WasteSort.quantityDesc:
          final qtyA = (a['quantity'] as int?) ?? 1;
          final qtyB = (b['quantity'] as int?) ?? 1;
          return qtyB.compareTo(qtyA);

        case _WasteSort.nameAZ:
          final nameA = (a['item_name'] as String?)?.toLowerCase() ?? '';
          final nameB = (b['item_name'] as String?)?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);
      }
    });

    return logs;
  }

  // ---------- Form Submission for Single Item ----------

  Future<void> _submitSingleItemWaste(String targetItemId) async {
    await widget.supa.logWaste(targetItemId, _qty, _selectedFormReason);
    if (mounted) {
      showCornerToast(context, message: 'Logged $_qty of $itemName as waste');
      Navigator.pop(context, true);
    }
  }

  // ---------- Build Method ----------

  @override
  Widget build(BuildContext context) {
    // If launched to log waste for a specific item
    if (itemId != null && itemId!.isNotEmpty) {
      return _buildSingleItemLogScaffold();
    }

    // Default "All Waste Logs" screen
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snapshot) {
        final allLogs = snapshot.data ?? const [];
        final filteredLogs = _filterAndSortLogs(allLogs);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // Metric calculations
        int totalUnits = 0;
        int expiredCount = 0;
        int spoiledCount = 0;
        int leftoverCount = 0;
        int moldyCount = 0;
        int otherCount = 0;

        for (final l in allLogs) {
          totalUnits += (l['quantity'] as int?) ?? 1;
          final r = (l['reason'] as String?)?.toLowerCase() ?? '';
          if (r.contains('expired')) {
            expiredCount++;
          } else if (r.contains('spoil')) {
            spoiledCount++;
          } else if (r.contains('leftover')) {
            leftoverCount++;
          } else if (r.contains('mold')) {
            moldyCount++;
          } else {
            otherCount++;
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refreshLogs,
                color: AppColors.gradientStart,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Collapsible Curved Gradient Header
                    _buildCurvedCollapsibleHeader(
                      totalLogs: allLogs.length,
                      totalUnits: totalUnits,
                      filteredCount: filteredLogs.length,
                    ),

                    // Filter Chips + Sort Row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', null, allLogs.length),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('Expired', 'Expired', expiredCount),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('Spoiled', 'Spoiled', spoiledCount),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('Leftover', 'Leftover', leftoverCount),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('Moldy', 'Moldy', moldyCount),
                                    const SizedBox(width: 6),
                                    _buildFilterChip('Other', 'Other', otherCount),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildSortButton(),
                          ],
                        ),
                      ),
                    ),

                    // Content list or empty state
                    if (isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (snapshot.hasError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                                const SizedBox(height: 12),
                                Text('Error loading waste logs: ${snapshot.error}', textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _refreshLogs, child: const Text('Retry')),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (filteredLogs.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(hasActiveFilters: allLogs.isNotEmpty),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final log = filteredLogs[index];
                              return _buildLogCard(log);
                            },
                            childCount: filteredLogs.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Floating Soft Silver Bulk Action Toolbar
              if (isSelectionActive)
                _buildFloatingBulkToolbar(visibleItems: filteredLogs),
            ],
          ),
        );
      },
    );
  }

  // ---------- Curved Gradient Collapsible Header ----------

  Widget _buildCurvedCollapsibleHeader({
    required int totalLogs,
    required int totalUnits,
    required int filteredCount,
  }) {
    final String subtitle;
    if (_searchQuery.isNotEmpty) {
      subtitle = 'Search results for "$_searchQuery" ($filteredCount entries)';
    } else if (_selectedReasonFilter != null) {
      subtitle = 'Filtered: $filteredCount entry(s) marked as $_selectedReasonFilter';
    } else {
      subtitle = '$totalLogs entries logged • $totalUnits total unit(s) wasted';
    }

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: _isSearchOpen ? 142 : 106,
      flexibleSpace: Container(
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
                    // Back Button
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
                            'Waste Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Search Toggle button
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
                        tooltip: 'Search waste logs',
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: _refreshLogs,
                      ),
                    ),
                  ],
                ),

                // Expandable Search Bar (when search is toggled open)
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
                        hintText: 'Search items or reasons...',
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

  Widget _buildFilterChip(String label, String? filterValue, int count) {
    final isSelected = _selectedReasonFilter == filterValue;
    return InkWell(
      onTap: () => setState(() => _selectedReasonFilter = filterValue),
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

  // ---------- Card Widget for Each Waste Log Entry ----------

  Widget _buildLogCard(Map<String, dynamic> log) {
    final id = log['id']?.toString() ?? '';
    final inv = log['inventory_items'] as Map<String, dynamic>?;
    final invName = (log['item_name'] as String?) ?? (inv?['name'] as String?) ?? 'Unknown Item';
    final quantity = (log['quantity'] as int?) ?? 1;

    final rawReason = (log['reason'] as String?)?.trim() ?? 'No reason';
    final reason = rawReason.toLowerCase() == 'soilt'
        ? 'Spoilt'
        : (rawReason.isNotEmpty ? rawReason[0].toUpperCase() + rawReason.substring(1) : rawReason);

    final whenStr = log['logged_at'] as String?;
    final when = whenStr != null ? DateTime.tryParse(whenStr) ?? DateTime.now() : DateTime.now();
    final formattedDate = DateFormat('MMM d, y • h:mm a').format(when.toLocal());

    final isSelected = _selectedIds.contains(id);

    // Color code reason badge
    final Color reasonBg;
    final Color reasonFg;
    final reasonLower = reason.toLowerCase();
    if (reasonLower.contains('expired')) {
      reasonBg = const Color(0xFFFEF3C7);
      reasonFg = const Color(0xFFD97706);
    } else if (reasonLower.contains('spoil') || reasonLower.contains('mold')) {
      reasonBg = const Color(0xFFFEE2E2);
      reasonFg = const Color(0xFFDC2626);
    } else if (reasonLower.contains('leftover')) {
      reasonBg = const Color(0xFFF3E8FF);
      reasonFg = const Color(0xFF7E22CE);
    } else {
      reasonBg = const Color(0xFFF1F5F9);
      reasonFg = const Color(0xFF475569);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
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
      child: Dismissible(
        key: Key(id),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_forever_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Text('Delete Entry?'),
              content: Text('Remove log entry for "$invName" permanently?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          return ok == true;
        },
        onDismissed: (_) async {
          await widget.supa.deleteWasteLog(id);
          _refreshLogs();
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onLongPress: () => _toggleSelection(id, log),
            onTap: () {
              if (isSelectionActive) {
                _toggleSelection(id, log);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Leading Trash Icon avatar
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Center(
                          child: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          right: -2,
                          top: -2,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: Color(0xFFEF4444),
                            child: Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // Title + Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Reason Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: reasonBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reason,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: reasonFg,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Formatted Timestamp
                            Flexible(
                              child: Text(
                                formattedDate,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Quantity Badge + Delete Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
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
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Delete entry',
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () => _confirmDeleteSingle(id, invName),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selectedIds.length} selected',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: _performBulkDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: _clearSelection,
            ),
          ],
        ),
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
                  hasActiveFilters ? Icons.search_off_rounded : Icons.delete_outline_rounded,
                  size: 32,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasActiveFilters
                    ? (_searchQuery.isNotEmpty ? 'No logs matching "$_searchQuery"' : 'No logs match filter')
                    : 'No Waste Logged Yet',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                hasActiveFilters
                    ? 'Try clearing the search query or selecting another reason filter'
                    : 'Items marked as waste from your inventory will appear here',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (hasActiveFilters) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedReasonFilter = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Reset Filters'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Single Item Log Scaffold (When launched with args) ----------

  Widget _buildSingleItemLogScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Log Waste',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          itemName.isEmpty ? 'Item' : itemName,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item: $itemName',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              const Text('Reason for waste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedFormReason,
                borderRadius: BorderRadius.circular(12),
                items: _commonReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFormReason = val);
                },
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('Quantity wasted:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          padding: EdgeInsets.zero,
                          onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('$_qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _qty++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Log Waste', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () => _submitSingleItemWaste(itemId!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
