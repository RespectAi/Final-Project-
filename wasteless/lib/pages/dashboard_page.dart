// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class DashboardPage extends StatefulWidget {
  final SupabaseService supa;
  const DashboardPage({super.key, required this.supa});

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
    return Column(
      children: [
        // QR Button Row
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 28),
            onPressed: () {
              // TODO: integrate QR scanner plugin
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("QR scan coming soon")),
              );
            },
          ),
        ),

        // Main dashboard layout
        Expanded(
          child: Row(
            children: [
              // Left column - Item cards
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isExpanded = expandedIndex == index;
                    return Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(item['name']),
                            subtitle: Text(item['category']),
                            trailing: IconButton(
                              icon: Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                              onPressed: () {
                                setState(() {
                                  expandedIndex =
                                      isExpanded ? -1 : index;
                                });
                              },
                            ),
                          ),
                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text("Time of entry: ${item['entry']}"),
                                  Text("Time to expire: ${item['expiry']}"),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Right column - big cards
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  children: [
                    _buildBigCard("Categories", Icons.category),
                    _buildBigCard("Fridges", Icons.kitchen),
                    _buildBigCard("Users", Icons.people),
                    _buildBigCard("Other Reminders", Icons.alarm),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom row of three cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallCard("Inventory", Icons.list),
            _buildSmallCard("Waste", Icons.delete),
            _buildSmallCard("Donate", Icons.card_giftcard),
          ],
        ),

        // Scrolling announcement bar
        Container(
          color: Colors.green[800],
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: announcements
                .map((msg) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: Text(
                          msg,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBigCard(String title, IconData icon) {
    return Card(
      elevation: 3,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(String title, IconData icon) {
    return Card(
      color: Colors.teal[100],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
