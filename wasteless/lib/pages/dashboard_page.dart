// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../widgets/common.dart';
import 'categories_page.dart';
import 'user_page.dart';
import 'fridges_page.dart';

class DashboardPage extends StatefulWidget {
  final SupabaseService supa;
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardPage({super.key, required this.supa, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  final List<String> announcements = [
    "Upcoming Feature: AI-based expiry prediction",
    "Tip: Donate unused food before it spoils",
    "New: Scan QR codes to add items faster",
  ];
  int expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.supa.fetchInventory();
  }

  Future<void> _refreshInventory() async {
    setState(() {
      _itemsFuture = widget.supa.fetchInventory();
      expandedIndex = -1;
    });
  }

  void refresh() => _refreshInventory();

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
      // Use a PreferredSize for a custom header but keep the normal scaffold body/Expanded behavior.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 2),
                        ),
                        child: Icon(
                          widget.supa.isAdminMode ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Greeting & name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            Text(userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      // QR action
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: IconButton(
                          icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                          onPressed: () => showCornerToast(context, message: 'QR scanner coming soon'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Welcome line + marquee below it
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Text('Welcome to WasteLess', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      // marquee area - take the rest of the space
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: SizedBox(
                            height: 28,
                            child: _Marquee(messages: announcements),
                          ),
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

      // Body uses the original left/right structure so Expanded and scrolls work like before
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 700;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left pane (Recent items) - keep original behavior
                    Expanded(flex: 2, child: _buildLeftPane(isSmall)),

                    // Right pane: cards area
                    Expanded(
                      flex: 2,
                      child: isSmall ? _buildVerticalCards() : _buildGridCards(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Quick action buttons (kept at bottom)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Inventory')),
                    onPressed: () => widget.onNavigateToTab?.call(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Waste log')),
                    onPressed: () => widget.onNavigateToTab?.call(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Donate')),
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

  // ---------- Cards (right side) ----------
  Widget _buildVerticalCards() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildModernCard('Categories', Icons.category, Colors.purple, () async {
          final cats = await widget.supa.fetchCategories();
          if (cats.isNotEmpty) {
            final id = cats.first['id'].toString();
            final name = cats.first['name'] as String? ?? '';
            Navigator.of(context).pushNamed(CategoriesPage.route, arguments: {'categoryId': id, 'categoryName': name});
          } else {
            Navigator.of(context).pushNamed(CategoriesPage.route);
          }
        }),
        const SizedBox(height: 12),
        _buildModernCard('Fridges', Icons.kitchen, Colors.teal, () {
          Navigator.pushNamed(context, FridgesPage.route);
        }),
        const SizedBox(height: 12),
        _buildModernCard('Users', Icons.people, Colors.indigo, () {
          Navigator.pushNamed(context, UserPage.route);
        }),
      ],
    );
  }

  Widget _buildGridCards() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          _buildModernCard('Categories', Icons.category, Colors.purple, () => Navigator.pushNamed(context, CategoriesPage.route)),
          _buildModernCard('Fridges', Icons.kitchen, Colors.teal, () => Navigator.pushNamed(context, FridgesPage.route)),
          _buildModernCard('Users', Icons.people, Colors.indigo, () => Navigator.pushNamed(context, UserPage.route)),
        ],
      ),
    );
  }

  Widget _buildModernCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
      ]),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Icon(icon, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------- Left pane (recent items) ----------
  Widget _buildLeftPane(bool isSmall) {
    return RefreshIndicator(
      onRefresh: _refreshInventory,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? const [];
          final dateFmt = DateFormat('EEEE, dd-MM-yyyy, h:mm a');

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: const LinearGradient(colors: [kGradientStart, kGradientEnd]), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Text('Recent Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ]),
              const SizedBox(height: 12),

              // The ListView is inside an Expanded so it gets a bounded height from the parent Column
              Expanded(
                child: items.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No items yet', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Add items to your inventory to get started', style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
                      ]))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
                          final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
                          final firstCat = cats.isNotEmpty ? cats.first : null;
                          final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
                          final name = (item['name'] as String?)?.trim().isNotEmpty == true ? (item['name'] as String) : 'Unnamed';
                          final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
                          final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();
                          final now = DateTime.now();
                          final diff = expiry.difference(now);
                          final daysLeft = diff.inDays;
                          final hoursLeft = diff.inHours % 24;
                          final isExpanded = expandedIndex == index;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: Column(children: [
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green.withOpacity(0.06), Colors.green.withOpacity(0.12)]), borderRadius: BorderRadius.circular(12)),
                                  child: (catIcon != null && catIcon.isNotEmpty)
                                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(catIcon, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.eco)))
                                      : const Icon(Icons.eco, size: 24, color: Colors.green),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(daysLeft >= 0 ? 'Expires in $daysLeft day(s) ${hoursLeft}h' : 'Expired ${-daysLeft} day(s) ago',
                                    style: TextStyle(color: daysLeft <= 1 ? Colors.red : Colors.grey[600], fontWeight: daysLeft <= 1 ? FontWeight.w600 : FontWeight.normal)),
                                trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
                                onTap: () => setState(() => expandedIndex = isExpanded ? -1 : index),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: Text('Added: ${dateFmt.format(createdAt.toLocal())}', style: TextStyle(color: Colors.grey[600]))) ]),
                                    const SizedBox(height: 8),
                                    Row(children: [Icon(Icons.event, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: Text('Expires: ${dateFmt.format(expiry.toLocal())}', style: TextStyle(color: Colors.grey[600]))) ]),
                                    const SizedBox(height: 12),
                                    const Text('Categories', style: TextStyle(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, runSpacing: 6, children: cats.map((c) {
                                      final iconUrl = (c['icon_url'] as String?) ?? '';
                                      final label = (c['name'] as String?) ?? '';
                                      final catId = (c['id']?.toString() ?? '');
                                      return InkWell(onTap: () {
                                        if (catId.isNotEmpty) Navigator.of(context).pushNamed(CategoriesPage.route, arguments: {'categoryId': catId, 'categoryName': label});
                                      }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (iconUrl.isNotEmpty) Padding(padding: const EdgeInsets.only(right: 6), child: Image.network(iconUrl, width: 16, height: 16, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 16))),
                                        Text(label, style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w500))
                                      ])));
                                    }).toList()),
                                  ])),
                                ),
                            ]),
                          );
                        }),
              ),

              const SizedBox(height: 12),
              // Other reminders card
              Container(
                height: 120,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.08), Colors.teal.withOpacity(0.14)]), borderRadius: BorderRadius.circular(16)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => showCornerToast(context, message: 'Other Reminders — coming soon', alignment: Alignment.topLeft),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.withOpacity(0.14), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.alarm, color: Colors.teal)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('Other Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                          const SizedBox(height: 4),
                          Text('Non-expiry reminders and tasks', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                        ])),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
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
  static const double _gap = 48.0;
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
      final textWidth = tp.width;

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
              // OverflowBox allows the large Row to be measured without throwing the RenderFlex overflow warning.
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