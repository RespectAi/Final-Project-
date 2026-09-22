import 'package:flutter/material.dart';
import 'dotted_border_painter.dart';

class DashboardShortcutPills extends StatelessWidget {
  final VoidCallback onCategoriesTap;
  final VoidCallback onFridgesTap;
  final VoidCallback onUsersTap;

  const DashboardShortcutPills({
    super.key,
    required this.onCategoriesTap,
    required this.onFridgesTap,
    required this.onUsersTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildPill(
              'Categories',
              Icons.category_outlined,
              Colors.purple,
              onCategoriesTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPill(
              'Fridges',
              Icons.kitchen_outlined,
              Colors.teal,
              onFridgesTap,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildPill(
              'Users',
              Icons.people_outline,
              Colors.indigo,
              onUsersTap,
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
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
}

class DashboardSurplusBanner extends StatelessWidget {
  final VoidCallback onShareMealsTap;

  const DashboardSurplusBanner({
    super.key,
    required this.onShareMealsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CustomPaint(
        foregroundPainter: const DottedBorderPainter(
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Donate nearby to people in need',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onShareMealsTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B074),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Share Meals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
