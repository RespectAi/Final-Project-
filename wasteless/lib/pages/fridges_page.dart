// lib/pages/fridges_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../features/categories/widgets/category_action_dialogs.dart';
import '../pages/add_item_page.dart';
import '../pages/donation_page.dart';
import '../pages/waste_log_page.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class FridgesPage extends StatefulWidget {
  static const route = '/fridges';
  final SupabaseService supa;
  const FridgesPage({required this.supa, super.key});

  @override
  State<FridgesPage> createState() => _FridgesPageState();
}

class _FridgesPageState extends State<FridgesPage> {
  late Future<List<Map<String, dynamic>>> _fridgesFuture;

  // Controllers
  final TextEditingController _joinCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  // State
  String _searchQuery = '';
  bool _isSearchOpen = false;
  bool _isJoinOpen = false;
  bool _isJoining = false;

  // Multi-select state
  final Set<String> _selectedFridgeIds = {};
  final Map<String, Map<String, dynamic>> _selectedFridges = {};

  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _fridgesFuture = widget.supa.fetchConnectedFridges();
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _fridgesFuture = widget.supa.fetchConnectedFridges();
    });
    await _fridgesFuture;
  }

  // ---------- Selection Handlers ----------

  void _toggleSelection(String fridgeId, Map<String, dynamic> fridge) {
    if (!widget.supa.isAdminMode) return;

    setState(() {
      if (_selectedFridgeIds.contains(fridgeId)) {
        _selectedFridgeIds.remove(fridgeId);
        _selectedFridges.remove(fridgeId);
      } else {
        _selectedFridgeIds.add(fridgeId);
        _selectedFridges[fridgeId] = fridge;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFridgeIds.clear();
      _selectedFridges.clear();
    });
  }

  Future<void> _confirmAndPerformBulkDelete() async {
    if (_selectedFridgeIds.isEmpty) return;

    final count = _selectedFridgeIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Selected Fridges', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete $count fridge(s)?\n\n'
          'This action cannot be undone and will permanently remove all shared items, members, and requests.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      int successCount = 0;
      for (final fridgeId in List<String>.from(_selectedFridgeIds)) {
        final success = await widget.supa.deleteFridge(fridgeId);
        if (success) successCount++;
      }

      if (mounted) {
        showCornerToast(
          context,
          message: successCount == count
              ? 'All $count fridges deleted successfully'
              : '$successCount/$count fridges deleted',
        );
      }

      _clearSelection();
      _refresh();
    }
  }

  // ---------- Fridge Creation & Joining ----------

  Future<void> _createFridge() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gradientStart.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.kitchen_rounded, color: AppColors.gradientStart, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('New Shared Fridge', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up a shared fridge to coordinate food with family, flatmates, or colleagues.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Fridge Name *',
                hintText: 'e.g. Kitchen Main, Office Breakroom',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Location (Optional)',
                hintText: 'e.g. Ground Floor, Room 204',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.place_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gradientStart,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Create Fridge'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final fridgeName = nameCtrl.text.trim();
    final fridgeLoc = locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null;

    final id = await widget.supa.createFridge(name: fridgeName, location: fridgeLoc);
    if (id != null) {
      if (mounted) showCornerToast(context, message: 'Fridge "$fridgeName" created successfully');
      _refresh();
    } else {
      if (mounted) showCornerToast(context, message: 'Failed to create fridge');
    }
  }

  Future<void> _handleJoinFridge([String? explicitCode]) async {
    final code = (explicitCode ?? _joinCtrl.text).trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isJoining = true);

    try {
      final result = await widget.supa.joinFridgeWithCode(code);
      if (result['success'] == true) {
        final fridgeName = result['fridgeName'] ?? 'Fridge';
        final already = result['alreadyMember'] == true;
        if (mounted) {
          showCornerToast(
            context,
            message: already ? 'Already a member of $fridgeName' : 'Joined $fridgeName successfully',
          );
        }
        _joinCtrl.clear();
        setState(() => _isJoinOpen = false);
        await _refresh();
      } else {
        if (mounted) {
          showCornerToast(context, message: result['message'] ?? 'Failed to join fridge');
        }
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _copyFridgeCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showCornerToast(context, message: 'Invite code copied: $code');
  }

  // ---------- Filtering ----------

  List<Map<String, dynamic>> _filterFridges(List<Map<String, dynamic>> raw) {
    if (_searchQuery.isEmpty) return raw;
    final q = _searchQuery.toLowerCase();
    return raw.where((f) {
      final name = (f['name'] as String?)?.toLowerCase() ?? '';
      final location = (f['location'] as String?)?.toLowerCase() ?? '';
      final code = (f['code'] as String?)?.toLowerCase() ?? '';
      return name.contains(q) || location.contains(q) || code.contains(q);
    }).toList();
  }

  // ---------- Build Method ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fridgesFuture,
        builder: (context, snapshot) {
          final allFridges = snapshot.data ?? const [];
          final filteredFridges = _filterFridges(allFridges);
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          // Metrics
          int adminCount = 0;
          int memberCount = 0;
          for (final f in allFridges) {
            final role = (f['role'] as String?)?.toLowerCase() ?? 'member';
            if (role == 'admin' || role == 'owner') {
              adminCount++;
            } else {
              memberCount++;
            }
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.gradientStart,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Collapsible Curved Gradient Header
                    _buildCurvedHeader(
                      totalCount: allFridges.length,
                      filteredCount: filteredFridges.length,
                      adminCount: adminCount,
                    ),

                    // Top High-Level Stats Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: _buildStatsBar(
                          total: allFridges.length,
                          admins: adminCount,
                          members: memberCount,
                        ),
                      ),
                    ),

                    // Content
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
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading fridges: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _refresh,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (filteredFridges.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(isSearch: _searchQuery.isNotEmpty),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          _selectedFridgeIds.isNotEmpty ? 96 : 32,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, idx) {
                              final f = filteredFridges[idx];
                              return _buildFridgeCard(f);
                            },
                            childCount: filteredFridges.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Floating Multi-select Action Bar
              if (_selectedFridgeIds.isNotEmpty && widget.supa.isAdminMode)
                _buildFloatingBulkActionBar(),
            ],
          );
        },
      ),
    );
  }

  // ---------- Curved Collapsible Header ----------

  Widget _buildCurvedHeader({
    required int totalCount,
    required int filteredCount,
    required int adminCount,
  }) {
    String subtitle;
    if (_searchQuery.isNotEmpty) {
      subtitle = '$filteredCount of $totalCount fridges found';
    } else {
      subtitle = '$totalCount Connected • $adminCount Admin';
    }

    final isExpanded = _isSearchOpen || _isJoinOpen;

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: isExpanded ? 142 : 106,
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
                            'Fridges',
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

                    // Join by Code Toggle Button
                    Container(
                      decoration: BoxDecoration(
                        color: _isJoinOpen ? Colors.white : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.group_add_rounded,
                          color: _isJoinOpen ? AppColors.gradientStart : Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Join with code',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _isJoinOpen = !_isJoinOpen;
                            if (_isJoinOpen) _isSearchOpen = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Create Fridge Button
                    if (widget.supa.isAdminMode) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          tooltip: 'Create fridge',
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          padding: EdgeInsets.zero,
                          onPressed: _createFridge,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Search Toggle Button
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
                        tooltip: 'Search fridges',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _isSearchOpen = !_isSearchOpen;
                            if (_isSearchOpen) _isJoinOpen = false;
                            if (!_isSearchOpen) {
                              _searchCtrl.clear();
                              _searchQuery = '';
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Refresh Button
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
                        onPressed: _refresh,
                      ),
                    ),
                  ],
                ),

                // Expandable Search Bar
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
                        hintText: 'Search fridges by name or location...',
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

                // Expandable Join Code Bar
                if (_isJoinOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 6),
                        const Icon(Icons.vpn_key_rounded, size: 18, color: AppColors.gradientStart),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _joinCtrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ENTER 6-CHAR CODE...',
                              hintStyle: TextStyle(fontSize: 12, letterSpacing: 0.5, color: Colors.grey[400]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onSubmitted: (v) => _handleJoinFridge(v),
                          ),
                        ),
                        if (_isJoining)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gradientStart),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gradientStart,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _handleJoinFridge(),
                            child: const Text('Join', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // ---------- Top Stats Bar ----------

  Widget _buildStatsBar({required int total, required int admins, required int members}) {
    return Row(
      children: [
        Expanded(
          child: _buildStatPill(
            label: 'Connected',
            value: '$total',
            icon: Icons.kitchen_rounded,
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatPill(
            label: 'Admin',
            value: '$admins',
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatPill(
            label: 'Member',
            value: '$members',
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Fridge Card ----------

  Widget _buildFridgeCard(Map<String, dynamic> f) {
    final fridgeId = f['id']?.toString() ?? '';
    final name = (f['name'] as String?) ?? 'Shared Fridge';
    final location = f['location'] as String?;
    final code = f['code'] as String?;
    final role = (f['role'] as String?)?.toLowerCase() ?? 'member';
    final isAdmin = role == 'admin' || role == 'owner';
    final isSelected = _selectedFridgeIds.contains(fridgeId);

    DateTime? created;
    if (f['created_at'] != null) {
      created = DateTime.tryParse(f['created_at'].toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (_selectedFridgeIds.isNotEmpty) {
              _toggleSelection(fridgeId, f);
              return;
            }
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => FridgeDetailPage(supa: widget.supa, fridge: f),
              ),
            );
            if (changed == true) _refresh();
          },
          onLongPress: () => _toggleSelection(fridgeId, f),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading Avatar
                if (isSelected)
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, color: Colors.white, size: 20),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart.withValues(alpha: 0.12),
                          AppColors.gradientEnd.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.kitchen_rounded,
                      color: AppColors.gradientStart,
                      size: 22,
                    ),
                  ),

                const SizedBox(width: 14),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isAdmin ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                                  size: 11,
                                  color: isAdmin ? const Color(0xFFD97706) : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAdmin ? 'Admin' : 'Member',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAdmin ? const Color(0xFFD97706) : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Meta row: Location & Created
                      Row(
                        children: [
                          if (location != null && location.isNotEmpty) ...[
                            Icon(Icons.place_outlined, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Text(
                              location,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                            const SizedBox(width: 8),
                          ],
                          if (created != null)
                            Text(
                              'Created ${_dateFmt.format(created.toLocal())}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                        ],
                      ),

                      // Quick Copy Code Pill (if code exists)
                      if (code != null && code.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _copyFridgeCode(code),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.key_rounded, size: 12, color: AppColors.gradientStart),
                                const SizedBox(width: 6),
                                Text(
                                  'Code: $code',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.copy_rounded, size: 11, color: Colors.grey[500]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing Action
                if (_selectedFridgeIds.isNotEmpty)
                  Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => _toggleSelection(fridgeId, f),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Empty State ----------

  Widget _buildEmptyState({required bool isSearch}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(
                isSearch ? Icons.search_off_rounded : Icons.kitchen_rounded,
                size: 48,
                color: AppColors.gradientStart,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isSearch ? 'No matching fridges' : 'No fridges connected yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'No fridge found matching "$_searchQuery". Try a different search term.'
                  : 'Join an existing shared fridge with an invite code, or create a new fridge to share with household members.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.supa.isAdminMode) ...[
                  ElevatedButton.icon(
                    onPressed: _createFridge,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Fridge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gradientStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isJoinOpen = true;
                      _isSearchOpen = false;
                    });
                  },
                  icon: const Icon(Icons.group_add_rounded, size: 18),
                  label: const Text('Join with Code'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Floating Bulk Action Bar ----------

  Widget _buildFloatingBulkActionBar() {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_selectedFridgeIds.length} Selected',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _confirmAndPerformBulkDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cancel selection',
              onPressed: _clearSelection,
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FRIDGE DETAIL PAGE
// ============================================================================

class FridgeDetailPage extends StatefulWidget {
  final SupabaseService supa;
  final Map<String, dynamic> fridge;
  const FridgeDetailPage({required this.supa, required this.fridge, super.key});

  @override
  State<FridgeDetailPage> createState() => _FridgeDetailPageState();
}

class _FridgeDetailPageState extends State<FridgeDetailPage> {
  late Future<void> _loadFuture;

  Map<String, dynamic> _fridgeData = {};
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _requests = [];

  String? _currentCode;
  bool _isRegenerating = false;
  int _currentTabIndex = 0; // 0: Items, 1: Members, 2: Requests

  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _fridgeData = Map<String, dynamic>.from(widget.fridge);
    _currentCode = _fridgeData['code'] as String?;
    _loadFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    final id = widget.fridge['id']?.toString() ?? '';
    if (id.isEmpty) return;

    // Fetch fridge fresh row (including code)
    final freshFridge = await widget.supa.fetchFridgeById(id);
    if (freshFridge != null) {
      _fridgeData = freshFridge;
      if (freshFridge['code'] != null) {
        _currentCode = freshFridge['code']?.toString();
      }
    }

    final items = await widget.supa.fetchFridgeItems(id);
    final members = await widget.supa.fetchFridgeMembersForFridge(id);
    final requests = await widget.supa.fetchPendingRequestsForFridge(id);

    setState(() {
      _items = items;
      _members = members;
      _requests = requests;
    });
  }

  bool _isUserAdmin() {
    if (widget.supa.isAdminMode) return true;
    final currentUserId = widget.supa.getCurrentUserId();
    if (currentUserId == null) return false;

    if (_fridgeData['user_id'] != null && _fridgeData['user_id'] == currentUserId) {
      return true;
    }

    for (final m in _members) {
      if (m['user_id'] == currentUserId) {
        final r = (m['role'] as String?)?.toLowerCase();
        if (r == 'admin' || r == 'owner') return true;
      }
    }

    final widgetRole = (widget.fridge['role'] as String?)?.toLowerCase();
    if (widgetRole == 'admin' || widgetRole == 'owner') return true;

    return false;
  }

  Future<void> _regenerateCode() async {
    final id = widget.fridge['id']?.toString() ?? '';
    setState(() => _isRegenerating = true);

    try {
      final code = await widget.supa.regenerateFridgeCode(id);
      if (code != null) {
        setState(() => _currentCode = code);
        if (mounted) showCornerToast(context, message: 'New invite code generated: $code');
      } else {
        if (mounted) showCornerToast(context, message: 'Failed to generate code');
      }
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  void _copyCode() {
    if (_currentCode == null) return;
    Clipboard.setData(ClipboardData(text: _currentCode!));
    showCornerToast(context, message: 'Invite code copied: $_currentCode');
  }

  Future<void> _deleteFridge() async {
    final id = widget.fridge['id']?.toString() ?? '';
    final name = (_fridgeData['name'] as String?) ?? (widget.fridge['name'] as String?) ?? 'this fridge';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Fridge', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'This action cannot be undone and will permanently remove all items, members, and requests.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Fridge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.supa.deleteFridge(id);
      if (success) {
        if (mounted) {
          showCornerToast(context, message: 'Fridge deleted successfully');
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) showCornerToast(context, message: 'Failed to delete fridge');
      }
    }
  }

  Future<void> _approveRequest(String reqId) async {
    await widget.supa.approveJoinRequest(reqId);
    if (mounted) showCornerToast(context, message: 'Request approved');
    await _loadAll();
  }

  Future<void> _rejectRequest(String reqId) async {
    await widget.supa.rejectJoinRequest(reqId);
    if (mounted) showCornerToast(context, message: 'Request rejected');
    await _loadAll();
  }

  Future<void> _handleMemberAction(String action, Map<String, dynamic> member) async {
    final memberId = member['user_id'] as String?;
    final fridgeId = widget.fridge['id']?.toString() ?? '';
    final memberName = member['user_name'] ?? 'Member';
    if (memberId == null) return;

    if (action == 'promote') {
      await widget.supa.promoteUser(memberId, fridgeId);
      if (mounted) showCornerToast(context, message: '$memberName promoted to admin');
      await _loadAll();
    } else if (action == 'demote') {
      await widget.supa.demoteUser(memberId, fridgeId);
      if (mounted) showCornerToast(context, message: '$memberName changed to regular member');
      await _loadAll();
    } else if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Remove Member?'),
          content: Text('Remove $memberName from this fridge? They will lose access to shared items.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await widget.supa.removeUserFromFridge(memberId, fridgeId);
        if (mounted) showCornerToast(context, message: '$memberName removed from fridge');
        await _loadAll();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_fridgeData['name'] as String?) ?? (widget.fridge['name'] as String?) ?? 'Shared Fridge';
    final location = (_fridgeData['location'] as String?) ?? (widget.fridge['location'] as String?);
    final isAdmin = _isUserAdmin();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting && _items.isEmpty && _members.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          return CustomScrollView(
            slivers: [
              // Detail Curved Header
              _buildDetailHeader(name: name, location: location, isAdmin: isAdmin),

              // Code Banner + Segmented Switcher
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // Invite Code Banner
                      _buildInviteCodeBanner(isAdmin: isAdmin),
                      const SizedBox(height: 12),

                      // Segmented Tab Controller
                      _buildSegmentedTabs(isAdmin: isAdmin),
                    ],
                  ),
                ),
              ),

              // Tab Views
              if (_currentTabIndex == 0)
                _buildItemsSliver(isAdmin: isAdmin)
              else if (_currentTabIndex == 1)
                _buildMembersSliver(isAdmin: isAdmin)
              else
                _buildRequestsSliver(isAdmin: isAdmin),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 48),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Header Widget ----------

  Widget _buildDetailHeader({
    required String name,
    required String? location,
    required bool isAdmin,
  }) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 96,
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
            child: Row(
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
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
                const SizedBox(width: 12),

                // Fridge Title & Location/Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAdmin ? 'Admin' : 'Member',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (location != null && location.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $location',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Refresh Button
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
                    onPressed: _loadAll,
                  ),
                ),

                // Admin Delete Menu
                if (isAdmin) ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                      tooltip: 'Options',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'delete') _deleteFridge();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                              SizedBox(width: 8),
                              Text('Delete Fridge', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
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

  // ---------- Invite Code Banner ----------

  Widget _buildInviteCodeBanner({required bool isAdmin}) {
    final hasCode = _currentCode != null && _currentCode!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gradientStart.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.vpn_key_rounded, color: AppColors.gradientStart, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INVITE CODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                if (hasCode)
                  SelectableText(
                    _currentCode!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      color: Color(0xFF1E293B),
                    ),
                  )
                else
                  const Text(
                    'No active code',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
          if (hasCode) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Copy code',
              onPressed: _copyCode,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (isAdmin)
            _isRegenerating
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _regenerateCode,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(hasCode ? 'Regenerate' : 'Generate'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
        ],
      ),
    );
  }

  // ---------- Segmented Tabs Switcher ----------

  Widget _buildSegmentedTabs({required bool isAdmin}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildSegmentTabItem(
            index: 0,
            title: 'Items',
            count: _items.length,
            icon: Icons.fastfood_outlined,
          ),
          _buildSegmentTabItem(
            index: 1,
            title: 'Members',
            count: _members.length,
            icon: Icons.people_outline_rounded,
          ),
          if (isAdmin)
            _buildSegmentTabItem(
              index: 2,
              title: 'Requests',
              count: _requests.length,
              icon: Icons.mark_email_unread_outlined,
              isAlert: _requests.isNotEmpty,
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentTabItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    bool isAlert = false,
  }) {
    final isSelected = _currentTabIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isAlert
                      ? Colors.redAccent
                      : (isSelected ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAlert ? Colors.white : (isSelected ? AppColors.primary : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Tab 1: Items List ----------

  Widget _buildItemsSliver({required bool isAdmin}) {
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'No items in this fridge',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add groceries or leftovers so household members know what is in stock.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddItemPage(supa: widget.supa),
                    ),
                  );
                  await _loadAll();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gradientStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, idx) {
            final it = _items[idx];
            return _buildItemCard(it, isAdmin);
          },
          childCount: _items.length,
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> it, bool isAdmin) {
    final currentUserId = widget.supa.getCurrentUserId();
    final ownerId = it['user_id'] as String?;
    final isOwner = ownerId != null && ownerId == currentUserId;
    final canEdit = isOwner || isAdmin;

    final name = (it['name'] as String?) ?? 'Unnamed Item';
    final qty = (it['quantity'] as int?) ?? 1;
    final ownerName = (it['user_name'] as String?) ?? (isOwner ? 'You' : 'Member');

    // Expiry calculation
    DateTime? expiry;
    if (it['expiry_date'] != null) {
      expiry = DateTime.tryParse(it['expiry_date'].toString());
    }

    int? daysLeft;
    bool isExpired = false;
    bool isUrgent = false;

    if (expiry != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expDay = DateTime(expiry.year, expiry.month, expiry.day);
      daysLeft = expDay.difference(today).inDays;
      isExpired = daysLeft < 0;
      isUrgent = daysLeft >= 0 && daysLeft <= 2;
    }

    Color pillBg = const Color(0xFFECFDF5);
    Color pillText = const Color(0xFF059669);
    String pillLabel = 'Fresh';

    if (expiry != null && daysLeft != null) {
      if (isExpired) {
        pillBg = const Color(0xFFFEE2E2);
        pillText = const Color(0xFFDC2626);
        pillLabel = daysLeft == -1 ? 'Expired yesterday' : 'Expired ${-daysLeft}d ago';
      } else if (daysLeft == 0) {
        pillBg = const Color(0xFFFEF3C7);
        pillText = const Color(0xFFD97706);
        pillLabel = 'Expires today';
      } else if (daysLeft == 1) {
        pillBg = const Color(0xFFFEF3C7);
        pillText = const Color(0xFFD97706);
        pillLabel = 'Expires tomorrow';
      } else if (isUrgent) {
        pillBg = const Color(0xFFFEF3C7);
        pillText = const Color(0xFFD97706);
        pillLabel = 'Expires in $daysLeft days';
      } else {
        pillLabel = 'Exp: ${_dateFmt.format(expiry)}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isExpired
                ? Colors.redAccent.withValues(alpha: 0.1)
                : (isUrgent
                    ? Colors.amber.withValues(alpha: 0.15)
                    : AppColors.gradientStart.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.restaurant_rounded,
            color: isExpired
                ? Colors.redAccent
                : (isUrgent ? const Color(0xFFD97706) : AppColors.gradientStart),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Qty: $qty',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pillLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pillText),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added by $ownerName',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) async {
            final id = it['id']?.toString() ?? '';
            if (v == 'consume') {
              CategoryActionDialogs.showConsumeDialog(
                context: context,
                supa: widget.supa,
                item: it,
                onMutated: _loadAll,
              );
            } else if (v == 'donate') {
              Navigator.of(context).pushNamed(DonationPage.route, arguments: {'id': id, 'name': name});
            } else if (v == 'waste') {
              Navigator.of(context).pushNamed(WasteLogPage.route, arguments: {'id': id, 'name': name});
            } else if (v == 'delete') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Delete Item?'),
                  content: Text('Permanently remove "$name" from this fridge?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await widget.supa.deleteInventoryItem(id);
                if (mounted) showCornerToast(context, message: 'Item deleted');
                await _loadAll();
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'consume',
              child: Row(
                children: [
                  Icon(Icons.restaurant_rounded, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Consume Item'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'donate',
              child: Row(
                children: [
                  Icon(Icons.volunteer_activism_rounded, color: Colors.purple, size: 18),
                  SizedBox(width: 8),
                  Text('Offer Donation'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'waste',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_rounded, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text('Log Waste'),
                ],
              ),
            ),
            if (canEdit)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Item', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
          ],
        ),
        onTap: () {
          CategoryActionDialogs.showItemDetailsBottomSheet(
            context: context,
            supa: widget.supa,
            item: it,
            onMutated: _loadAll,
          );
        },
      ),
    );
  }

  // ---------- Tab 2: Members List ----------

  Widget _buildMembersSliver({required bool isAdmin}) {
    if (_members.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('No members found', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ),
      );
    }

    final currentUserId = widget.supa.getCurrentUserId();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, idx) {
            final m = _members[idx];
            final uid = m['user_id'] as String?;
            final isSelf = uid != null && uid == currentUserId;
            final role = (m['role'] as String?)?.toLowerCase() ?? 'member';
            final isMemberAdmin = role == 'admin' || role == 'owner';
            final name = (m['user_name'] as String?) ?? 'Member';

            DateTime? joined;
            if (m['joined_at'] != null) {
              joined = DateTime.tryParse(m['joined_at'].toString());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: isMemberAdmin
                      ? const Color(0xFFFEF3C7)
                      : AppColors.gradientStart.withValues(alpha: 0.12),
                  foregroundColor: isMemberAdmin ? const Color(0xFFD97706) : AppColors.gradientStart,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'M',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isSelf ? '$name (You)' : name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isMemberAdmin ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isMemberAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isMemberAdmin ? const Color(0xFFD97706) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: joined != null
                    ? Text('Joined ${_dateFmt.format(joined.toLocal())}', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                    : null,
                trailing: (isAdmin && !isSelf)
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (action) => _handleMemberAction(action, m),
                        itemBuilder: (_) => [
                          if (!isMemberAdmin)
                            const PopupMenuItem(
                              value: 'promote',
                              child: Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 18),
                                  SizedBox(width: 8),
                                  Text('Promote to Admin'),
                                ],
                              ),
                            )
                          else
                            const PopupMenuItem(
                              value: 'demote',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, color: Color(0xFF475569), size: 18),
                                  SizedBox(width: 8),
                                  Text('Change to Regular Member'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Remove from Fridge', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          },
          childCount: _members.length,
        ),
      ),
    );
  }

  // ---------- Tab 3: Requests List ----------

  Widget _buildRequestsSliver({required bool isAdmin}) {
    if (!isAdmin) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Only fridge administrators can review join requests.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text(
                'No pending join requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 6),
              const Text(
                'When someone enters this fridge\'s invite code, their request will appear here for approval.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, idx) {
            final r = _requests[idx];
            final reqId = r['id']?.toString() ?? '';
            final requesterName = (r['requester_name'] as String?) ?? 'Unknown User';
            final message = (r['message'] as String?) ?? '';

            DateTime? requestedAt;
            if (r['created_at'] != null) {
              requestedAt = DateTime.tryParse(r['created_at'].toString());
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.gradientStart.withValues(alpha: 0.12),
                        foregroundColor: AppColors.gradientStart,
                        child: Text(
                          requesterName.isNotEmpty ? requesterName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              requesterName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                            if (requestedAt != null)
                              Text(
                                'Requested ${_dateFmt.format(requestedAt.toLocal())}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '"$message"',
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _rejectRequest(reqId),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _approveRequest(reqId),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          childCount: _requests.length,
        ),
      ),
    );
  }
}

// Small helper badge widget (kept for backward compatibility)
class Badge extends StatelessWidget {
  final Widget child;
  const Badge({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 16, backgroundColor: Colors.green[100], child: child);
  }
}
