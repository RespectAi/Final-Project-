import 'package:flutter/material.dart';

class DashboardStatsCard extends StatelessWidget {
  final Future<Map<String, int>> statsFuture;

  const DashboardStatsCard({
    super.key,
    required this.statsFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'activeItems': 0, 'expiringSoon': 0, 'mealsShared': 0};
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 36,
      width: 1,
      color: const Color(0xFFF3F4F6),
    );
  }
}
