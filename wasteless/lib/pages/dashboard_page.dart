// lib/pages/dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../widgets/common.dart';
import 'categories_page.dart';
import 'user_page.dart';
import 'fridges_page.dart';
import '../pages/auth_page.dart';
import 'add_item_page.dart';
import 'donation_page.dart';
import 'waste_log_page.dart';

class DashboardPage extends StatefulWidget {
  final SupabaseService supa;
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardPage({super.key, required this.supa, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  late Future<Map<String, int>> _statsFuture;
  StreamSubscription<void>? _inventorySub;

  final List<String> announcements = [
    "Upcoming Feature: AI-based expiry prediction",
    "Tip: Donate unused food before it spoils",
    "New: Scan QR codes to add items faster",
  ];

  int expandedIndex = -1;
  bool _isSearchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();

    // Reactive sync: listen for inventory changes from any page
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

  void _refreshData() {
    setState(() {
      _itemsFuture = widget.supa.fetchInventory();
      _statsFuture = widget.supa.fetchDashboardStats();
      expandedIndex = -1;
    });
  }

  void refresh() => _refreshData();

  String _getCurrentUserDisplayName() {
    if (widget.supa.isAdminMode) return 'Admin';
    if (widget.supa.activeLocalUserName != null) return widget.supa.activeLocalUserName!;
    final email = widget.supa.client.auth.currentUser?.email;
    return email?.split('@').first ?? 'User';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final userName = _getCurrentUserDisplayName();
    final greeting = _getGreeting();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(124),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
                        ),
                        child: Icon(
                          widget.supa.isAdminMode ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Greeting & name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text(userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      // Top Action buttons: Search, Add, QR, Logout
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Button (matches mockup)
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
                          // Quick Add (+) Button (matches header gradient theme)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 22),
                              tooltip: 'Add item',
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                Navigator.pushNamed(context, AddItemPage.route).then((_) => refresh());
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          // QR action
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                              tooltip: 'Scan QR',
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              padding: EdgeInsets.zero,
                              onPressed: () => showCornerToast(context, message: 'QR scanner coming soon'),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Logout action
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                              tooltip: 'Logout',
                              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                await widget.supa.client.auth.signOut();
                                widget.supa.clearUserContext();
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => AuthGate(supa: widget.supa)),
                                    (route) => false,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Welcome badge + Marquee
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: const Text('WasteLess', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 24,
                          child: _Marquee(messages: announcements),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Expandable search bar
          if (_isSearchOpen) _buildSearchBar(),

          // Main responsive content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 700;
                if (isSmall) {
                  return _buildMobileFeed();
                } else {
                  return _buildDesktopLayout();
                }
              },
            ),
          ),

          // Quick action buttons at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.list, size: 18),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Inventory')),
                    onPressed: () => widget.onNavigateToTab?.call(1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Waste log')),
                    onPressed: () => widget.onNavigateToTab?.call(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard, size: 18),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Donate')),
                    onPressed: () => widget.onNavigateToTab?.call(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Search Bar ----------
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search items or categories...',
          prefixIcon: const Icon(Icons.search, color: kGradientStart),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      ),
    );
  }

  // ---------- 3-Stat Summary Card (RespectAi Mockup) ----------
  Widget _buildStatsCard() {
    return FutureBuilder<Map<String, int>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'activeItems': 0, 'expiringSoon': 0, 'mealsShared': 0};
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              _buildStatColumn('${stats['activeItems']}', 'Active Items', Colors.black87),
              _buildVerticalDivider(),
              _buildStatColumn('${stats['expiringSoon']}', 'Expiring Soon', const Color(0xFFD97706)),
              _buildVerticalDivider(),
              _buildStatColumn('${stats['mealsShared']}', 'Meals Shared', const Color(0xFF00B074)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ---------- Shortcut Pills (Mobile) ----------
  Widget _buildShortcutPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildPill(
              'Categories',
              Icons.category_outlined,
              Colors.purple,
              () => Navigator.pushNamed(context, CategoriesPage.route),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPill(
              'Fridges',
              Icons.kitchen_outlined,
              Colors.teal,
              () => Navigator.pushNamed(context, FridgesPage.route),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPill(
              'Users',
              Icons.people_outline,
              Colors.indigo,
              () => Navigator.pushNamed(context, UserPage.route),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Surplus Food Donation Banner (RespectAi Mockup) ----------
  Widget _buildSurplusFoodCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomPaint(
        foregroundPainter: const _DottedBorderPainter(
          color: Color(0xFF00B074),
          strokeWidth: 1.5,
          dash: 5.0,
          gap: 4.0,
          radius: 16.0,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Surplus food at home?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect with nearby shelters to donate.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateToTab?.call(3),
                icon: const Icon(Icons.card_giftcard, size: 16),
                label: const Text('Donate', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B074),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Mobile Single-Column Feed ----------
  Widget _buildMobileFeed() {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          _buildStatsCard(),
          _buildShortcutPills(),
          _buildSurplusFoodCard(),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.kitchen_outlined, size: 18, color: kGradientStart),
                const SizedBox(width: 8),
                Text(
                  _searchQuery.isEmpty ? 'Inventory' : 'Search Results',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
          _buildItemsListContent(),
          const SizedBox(height: 8),
          _buildOtherRemindersCard(),
        ],
      ),
    );
  }

  // ---------- Desktop Dual-Column Layout ----------
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Items feed
        Expanded(
          flex: 3,
          child: RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Icon(Icons.kitchen_outlined, size: 20, color: kGradientStart),
                    const SizedBox(width: 8),
                    Text(
                      _searchQuery.isEmpty ? 'Inventory' : 'Search Results',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildItemsListContent(),
              ],
            ),
          ),
        ),

        // Right Column: Stats, Shortcuts, Banner
        Expanded(
          flex: 2,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            children: [
              _buildStatsCard(),
              const SizedBox(height: 12),
              _buildGridCards(),
              _buildSurplusFoodCard(),
              const SizedBox(height: 12),
              _buildOtherRemindersCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Items List Content (Mockup Cards with Pill Badges) ----------
  Widget _buildItemsListContent() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        var items = snapshot.data ?? const [];

        // Apply search filter if query is present
        if (_searchQuery.isNotEmpty) {
          items = items.where((item) {
            final name = (item['name'] as String?)?.toLowerCase() ?? '';
            final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
            final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
            final catNames = cats.map((c) => (c['name'] as String?)?.toLowerCase() ?? '').join(' ');
            return name.contains(_searchQuery) || catNames.contains(_searchQuery);
          }).toList();
        }

        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    _searchQuery.isNotEmpty ? 'No items matching "$_searchQuery"' : 'No items yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _searchQuery.isNotEmpty ? 'Try a different search term' : 'Tap (+) at the top to add your first item',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final dateFmt = DateFormat('EEEE, dd-MM-yyyy, h:mm a');

        return Column(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
            final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
            final firstCat = cats.isNotEmpty ? cats.first : null;
            final catName = firstCat != null ? (firstCat['name'] as String? ?? 'General') : 'General';
            final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
            final name = (item['name'] as String?)?.trim().isNotEmpty == true ? (item['name'] as String) : 'Unnamed';
            final quantity = item['quantity'] ?? 1;
            final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
            final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();
            final now = DateTime.now();
            final diff = expiry.difference(now);
            final daysLeft = diff.inDays;
            final isExpanded = expandedIndex == index;

            // Compute Mockup-Styled Urgency Pill Badge
            Color pillBg;
            Color pillTextColor;
            String pillLabel;

            if (daysLeft < 0) {
              pillBg = const Color(0xFFFDE8E8);
              pillTextColor = const Color(0xFFE02424);
              pillLabel = 'Expired ${-daysLeft}d ago';
            } else if (daysLeft == 0) {
              pillBg = const Color(0xFFFDE8E8);
              pillTextColor = const Color(0xFFE02424);
              pillLabel = 'Expires Today';
            } else if (daysLeft == 1) {
              pillBg = const Color(0xFFFEF08A).withOpacity(0.5);
              pillTextColor = const Color(0xFFD97706);
              pillLabel = '1 Day Left';
            } else if (daysLeft <= 3) {
              pillBg = const Color(0xFFFEF08A).withOpacity(0.5);
              pillTextColor = const Color(0xFFD97706);
              pillLabel = '$daysLeft Days Left';
            } else {
              pillBg = const Color(0xFFDEF7EC);
              pillTextColor = const Color(0xFF046C4E);
              pillLabel = '$daysLeft Days Left';
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: (catIcon != null && catIcon.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(catIcon, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: Colors.green)),
                            )
                          : const Icon(Icons.eco, size: 22, color: Colors.green),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      '$catName · Qty: $quantity',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pill badge matching mockup
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pillLabel,
                            style: TextStyle(
                              color: pillTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.grey[500]),
                      ],
                    ),
                    onTap: () => setState(() => expandedIndex = isExpanded ? -1 : index),
                  ),

                  // Expandable details with overflow-safe row widgets
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 15, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Added: ${dateFmt.format(createdAt.toLocal())}', style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.event, size: 15, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Expires: ${dateFmt.format(expiry.toLocal())}', style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 6),
                            // Safe wrapping for categories to eliminate RenderFlex overflow errors
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: cats.map((c) {
                                final iconUrl = (c['icon_url'] as String?) ?? '';
                                final label = (c['name'] as String?) ?? '';
                                final catId = (c['id']?.toString() ?? '');
                                return InkWell(
                                  onTap: () {
                                    if (catId.isNotEmpty) {
                                      Navigator.of(context).pushNamed(CategoriesPage.route, arguments: {'categoryId': catId, 'categoryName': label});
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (iconUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 5),
                                            child: Image.network(iconUrl, width: 14, height: 14, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 14)),
                                          ),
                                        Flexible(
                                          child: Text(
                                            label,
                                            style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            // Direct actions: Donate or Log Waste
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pushNamed(DonationPage.route, arguments: {'id': item['id'], 'name': name}).then((_) => refresh());
                                    },
                                    icon: const Icon(Icons.card_giftcard, size: 16),
                                    label: const Text('Donate', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pushNamed(WasteLogPage.route, arguments: {'id': item['id'], 'name': name}).then((_) => refresh());
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    label: const Text('Log Waste', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ---------- Desktop Grid Cards ----------
  Widget _buildGridCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildModernCard('Categories', Icons.category, Colors.purple, () => Navigator.pushNamed(context, CategoriesPage.route)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModernCard('Fridges', Icons.kitchen, Colors.teal, () => Navigator.pushNamed(context, FridgesPage.route)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModernCard('Users', Icons.people, Colors.indigo, () => Navigator.pushNamed(context, UserPage.route)),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
      ]),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- Other Reminders Card ----------
  Widget _buildOtherRemindersCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.06), Colors.teal.withOpacity(0.12)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showCornerToast(context, message: 'Other Reminders — coming soon', alignment: Alignment.topLeft),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.teal.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.alarm, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Other Reminders', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                      const SizedBox(height: 2),
                      Text('Non-expiry reminders and tasks', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.teal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marquee that avoids the RenderFlex overflow warning by letting the large
/// content exist in an OverflowBox and translating it. It is clipped via ClipRect.
class _Marquee extends StatefulWidget {
  final List<String> messages;
  const _Marquee({required this.messages});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _gap = 64.0;
  static const double _speedPxPerSecond = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.messages.join('     •     ');
    final textStyle = const TextStyle(color: Colors.white, fontSize: 13);

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final tp = TextPainter(text: TextSpan(text: text, style: textStyle), textDirection: ui.TextDirection.ltr, maxLines: 1)..layout();
      final textWidth = tp.width + 16.0;

      // If it fits, show static single-line text
      if (textWidth <= maxWidth - 24) {
        if (_controller.isAnimating) _controller.stop();
        return Container(
          color: Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
        );
      }

      // Animate: compute total distance and duration
      final totalDistance = textWidth + _gap;
      final durationSeconds = (totalDistance / _speedPxPerSecond).clamp(6.0, 40.0);
      _controller.duration = Duration(milliseconds: (durationSeconds * 1000).toInt());
      if (!_controller.isAnimating) _controller.repeat();

      return ClipRect(
        child: Container(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -_controller.value * totalDistance;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(width: textWidth, child: Text(text, style: textStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.visible)),
                      SizedBox(width: _gap),
                      SizedBox(width: textWidth, child: Text(text, style: textStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.visible)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

/// Draws a crisp dashed / dotted border around a rounded rectangle
class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;
  final double radius;

  const _DottedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dash = 5.0,
    this.gap = 4.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final halfStroke = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(halfStroke, halfStroke, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double next = distance + dash;
        final extractPath = metric.extractPath(distance, next > metric.length ? metric.length : next);
        canvas.drawPath(extractPath, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}