// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
// import 'package:intl/intl.dart';
import '../widgets/common.dart';

class DashboardPage extends StatefulWidget {
  final SupabaseService supa;
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardPage({super.key, required this.supa, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  // Real data from Supabase
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  final List<String> announcements = [
    "Upcoming Feature: AI-based expiry prediction",
    "Tip: Donate unused food before it spoils",
    "New: Scan QR codes to add items faster"
  ];

  int expandedIndex = -1; // For inline expansion

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

  // Exposed for parent tab to request a refresh when user navigates back
  void refresh() => _refreshInventory();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        'WasteLess',
        showBackIfCanPop: false,
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              showCornerToast(context, message: 'QR scanner coming soon');
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 700;
                // Keep a left-right split on all sizes. On small screens,
                // the right side becomes a vertical stack of square cards.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildLeftPane()),
                    Expanded(
                      flex: 2,
                      child: isSmall
                          ? ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildBigCard('Categories', Icons.category, onTap: () => showCornerToast(context, message: 'Categories — coming soon', alignment: Alignment.topLeft)),
                                ),
                                const SizedBox(height: 12),
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildBigCard('Fridges', Icons.kitchen, onTap: () => showCornerToast(context, message: 'Fridges — coming soon', alignment: Alignment.topLeft)),
                                ),
                                const SizedBox(height: 12),
                                AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildBigCard('Users', Icons.people, onTap: () => showCornerToast(context, message: 'Users — coming soon', alignment: Alignment.topLeft)),
                                ),
                              ],
                            )
                          : GridView.count(
                              padding: const EdgeInsets.all(12),
                              crossAxisCount: 2,
                              childAspectRatio: 1.1,
                              children: [
                                _buildBigCard('Categories', Icons.category, onTap: () => showCornerToast(context, message: 'Categories — coming soon', alignment: Alignment.topLeft)),
                                _buildBigCard('Fridges', Icons.kitchen, onTap: () => showCornerToast(context, message: 'Fridges — coming soon', alignment: Alignment.topLeft)),
                                _buildBigCard('Users', Icons.people, onTap: () => showCornerToast(context, message: 'Users — coming soon', alignment: Alignment.topLeft)),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Larger quick buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Inventory'),
                    ),
                    onPressed: () => widget.onNavigateToTab?.call(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Waste log'),
                    ),
                    onPressed: () => widget.onNavigateToTab?.call(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Donate'),
                    ),
                    onPressed: () => widget.onNavigateToTab?.call(3),
                  ),
                ),
              ],
            ),
          ),

          // Bottom announcements bar (placeholder content for now)
          SizedBox(
            height: 32,
            child: ClipRect(child: _Marquee(messages: announcements)),
          ),
        ],
      ),
    );
  }

  Widget _buildBigCard(String title, IconData icon, {VoidCallback? onTap}) {
    return Card(
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // _buildSmallCard removed (no longer used)

  Widget _buildLeftPane() {
    return RefreshIndicator(
      onRefresh: _refreshInventory,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const [];
          // Make the list scrollable while keeping Other Reminders visible at bottom
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
                      final cats = links
                          .map((link) => (link['categories'] as Map<String, dynamic>? ?? {}))
                          .toList();
                      final firstCat = cats.isNotEmpty ? cats.first : null;
                      final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
                      final name = (item['name'] as String?)?.trim().isNotEmpty == true
                          ? (item['name'] as String)
                          : 'Unnamed';
                      final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
                      final createdAt = DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now();
                      final now = DateTime.now();
                      final diff = expiry.difference(now);
                      final daysLeft = diff.inDays;
                      final hoursLeft = diff.inHours % 24;

                      final isExpanded = expandedIndex == index;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: [
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green[50],
                                child: (catIcon != null && catIcon.isNotEmpty)
                                    ? ClipOval(
                                        child: Image.network(
                                          catIcon,
                                          width: 30,
                                          height: 30,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.eco, size: 22),
                              ),
                              title: Text(name),
                              subtitle: Text(
                                daysLeft >= 0
                                    ? 'Expires in $daysLeft day(s) ${hoursLeft}h'
                                    : 'Expired ${-daysLeft} day(s) ago',
                              ),
                              trailing: IconButton(
                                icon: Icon(isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down),
                                onPressed: () => setState(() {
                                  expandedIndex = isExpanded ? -1 : index;
                                }),
                              ),
                            ),
                            if (isExpanded)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Entry: ${createdAt.toLocal()}'),
                                    const SizedBox(height: 6),
                                    const Text('Categories:'),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: cats.map((c) {
                                        final iconUrl = (c['icon_url'] as String?) ?? '';
                                        final label = (c['name'] as String?) ?? '';
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.black12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (iconUrl.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Image.network(iconUrl, width: 16, height: 16),
                                                ),
                                              Text(label, style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: Card(
                    color: Colors.teal[50],
                    child: ListTile(
                      title: const Text('Other Reminders'),
                      subtitle: const Text('Non-expiry reminders and tasks'),
                      trailing: const Icon(Icons.alarm),
                      onTap: () => showCornerToast(
                        context,
                        message: 'Other Reminders — coming soon',
                        alignment: Alignment.topLeft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _Marquee extends StatefulWidget {
  final List<String> messages;
  const _Marquee({required this.messages});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _anim = Tween<double>(begin: 1, end: -1).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.messages.join('     •     ');
    return Container(
      color: Colors.green[800],
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          return FractionalTranslation(
            translation: Offset(_anim.value, 0),
            child: Row(children: [
              const SizedBox(width: 16),
              Text(text, style: const TextStyle(color: Colors.white)),
            ]),
          );
        },
      ),
    );
  }
}
