// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class DashboardPage extends StatelessWidget {
  final SupabaseService supa;
  final void Function(int tabIndex) onNavigateToTab;

  const DashboardPage({
    Key? key,
    required this.supa,
    required this.onNavigateToTab,
  }) : super(key: key);

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('WasteLess'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: [
                    _Tile(
                      label: 'Categories',
                      icon: Icons.category,
                      onTap: () => _comingSoon(context, 'Categories'),
                    ),
                    _Tile(
                      label: 'Fridges',
                      icon: Icons.kitchen,
                      onTap: () => _comingSoon(context, 'Fridges'),
                    ),
                    _Tile(
                      label: 'Other Reminders',
                      icon: Icons.alarm,
                      onTap: () => _comingSoon(context, 'Other Reminders'),
                    ),
                    _Tile(
                      label: 'Users',
                      icon: Icons.group,
                      onTap: () => _comingSoon(context, 'Users'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _QuickButton(
                      label: 'Inventory',
                      icon: Icons.inventory,
                      onPressed: () => onNavigateToTab(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickButton(
                      label: 'Waste log',
                      icon: Icons.delete,
                      onPressed: () => onNavigateToTab(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickButton(
                      label: 'Donate',
                      icon: Icons.card_giftcard,
                      onPressed: () => onNavigateToTab(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _Tile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      onPressed: onPressed,
      label: Text(label),
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
    );
  }
}


