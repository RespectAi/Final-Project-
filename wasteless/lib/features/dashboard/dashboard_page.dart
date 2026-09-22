// lib/features/dashboard/dashboard_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../pages/add_item_page.dart';
import '../../pages/auth_page.dart';
import '../../pages/categories_page.dart';
import '../../pages/donation_page.dart';
import '../../pages/fridges_page.dart';
import '../../pages/user_page.dart';
import '../../pages/waste_log_page.dart';
import '../../services/supabase_service.dart';
import '../../widgets/common.dart';
import 'widgets/dashboard_marquee.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_stats_card.dart';

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
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
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
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
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
                          // Search Button
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
                          // Quick Add (+) Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
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
                              color: Colors.white.withValues(alpha: 0.15),
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
                              color: Colors.white.withValues(alpha: 0.15),
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                        ),
                        child: const Text('WasteLess', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 24,
                          child: DashboardMarquee(messages: announcements),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search items or categories...',
          prefixIcon: const Icon(Icons.search, color: AppColors.gradientStart),
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

  // ---------- Mobile Single-Column Feed ----------
  Widget _buildMobileFeed() {
    return RefreshIndicator(
      onRefresh: () async => refresh(),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        children: [
          DashboardStatsCard(statsFuture: _statsFuture),
          DashboardShortcutPills(
            onCategoriesTap: () => Navigator.pushNamed(context, CategoriesPage.route),
            onFridgesTap: () => Navigator.pushNamed(context, FridgesPage.route),
            onUsersTap: () => Navigator.pushNamed(context, UserPage.route),
          ),
          DashboardSurplusBanner(
            onShareMealsTap: () => widget.onNavigateToTab?.call(3),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.kitchen_outlined, size: 18, color: AppColors.gradientStart),
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
                    const Icon(Icons.kitchen_outlined, size: 20, color: AppColors.gradientStart),
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
              DashboardStatsCard(statsFuture: _statsFuture),
              const SizedBox(height: 12),
              _buildGridCards(),
              DashboardSurplusBanner(
                onShareMealsTap: () => widget.onNavigateToTab?.call(3),
              ),
              const SizedBox(height: 12),
              _buildOtherRemindersCard(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Items List Content ----------
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
              pillBg = const Color(0xFFFEF08A).withValues(alpha: 0.5);
              pillTextColor = const Color(0xFFD97706);
              pillLabel = '1 Day Left';
            } else if (daysLeft <= 3) {
              pillBg = const Color(0xFFFEF08A).withValues(alpha: 0.5);
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                        color: Colors.green.withValues(alpha: 0.08),
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
                      '$catName • Qty: $quantity',
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
                          color: Colors.grey.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
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
                                      color: Colors.blue.withValues(alpha: 0.08),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ],
            ),
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
        gradient: LinearGradient(colors: [Colors.teal.withValues(alpha: 0.06), Colors.teal.withValues(alpha: 0.12)]),
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
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
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
