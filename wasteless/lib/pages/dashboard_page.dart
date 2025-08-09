// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class DashboardPage extends StatefulWidget {
  final SupabaseService supa;
  final void Function(int tabIndex)? onNavigateToTab;
  const DashboardPage({super.key, required this.supa, this.onNavigateToTab});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Example placeholder data
  final List<Map<String, dynamic>> items = [
    {
      "name": "Milk",
      "category": "Dairy",
      "entry": "2025-08-07 10:00",
      "expiry": "2025-08-10 10:00"
    },
    {
      "name": "Apples",
      "category": "Fruit",
      "entry": "2025-08-06 14:00",
      "expiry": "2025-08-15 14:00"
    },
  ];

  final List<String> announcements = [
    "Upcoming Feature: AI-based expiry prediction",
    "Tip: Donate unused food before it spoils",
    "New: Scan QR codes to add items faster"
  ];

  int expandedIndex = -1; // For inline expansion

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        'WasteLess',
        showBackIfCanPop: false,
        actions: [
          IconButton(
            tooltip: 'Scan to add',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              showCornerToast(context, message: 'QR scan coming soon');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: vertical scroll of inventory-like cards + Other Reminders card
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        final isExpanded = expandedIndex == index;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              ListTile(
                                dense: true,
                                title: Text(item['name']),
                                subtitle: Text(item['category']),
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Entry: ${item['entry']}'),
                                      Text('Expires: ${item['expiry']}'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      Card(
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
                    ],
                  ),
                ),

                // Right: big feature tiles
                Expanded(
                  flex: 2,
                  child: GridView.count(
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
            child: _Marquee(messages: announcements),
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
