import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class CategoryItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const CategoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] as String?)?.trim().isNotEmpty == true
        ? (item['name'] as String)
        : 'Unnamed Item';
    final quantity = (item['quantity'] as int?) ?? 1;
    final expiry = DateTime.tryParse(item['expiry_date'] as String? ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final diff = expiry.difference(now);
    final daysLeft = diff.inDays;

    final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
    final cats = links.map((link) => (link['categories'] as Map<String, dynamic>? ?? {})).toList();
    final firstCat = cats.isNotEmpty ? cats.first : null;
    final catIcon = firstCat != null ? (firstCat['icon_url'] as String?) : null;
    final catName = firstCat != null ? (firstCat['name'] as String?) : null;

    final Color urgencyBg;
    final Color urgencyText;
    final String urgencyLabel;

    if (daysLeft < 0) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyText = const Color(0xFFDC2626);
      urgencyLabel = 'Expired ${-daysLeft}d ago';
    } else if (daysLeft == 0) {
      urgencyBg = const Color(0xFFFEE2E2);
      urgencyText = const Color(0xFFDC2626);
      urgencyLabel = 'Expires today';
    } else if (daysLeft == 1) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = 'Expires tomorrow';
    } else if (daysLeft <= 3) {
      urgencyBg = const Color(0xFFFEF3C7);
      urgencyText = const Color(0xFFD97706);
      urgencyLabel = '$daysLeft days left';
    } else {
      urgencyBg = const Color(0xFFDCFCE7);
      urgencyText = const Color(0xFF16A34A);
      urgencyLabel = '$daysLeft days left';
    }

    final dateFmt = DateFormat('MMM d, y');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Category Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC).withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: (catIcon != null && catIcon.isNotEmpty)
                        ? Image.network(
                            catIcon,
                            width: 24,
                            height: 24,
                            errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: AppColors.primary, size: 22),
                          )
                        : const Icon(Icons.eco, color: AppColors.primary, size: 22),
                  ),
                ),
                const SizedBox(width: 12),

                // Name, Category Tag & Expiry Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (catName != null) ...[
                            Text(
                              catName,
                              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                            Text(' • ', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                          ],
                          Text(
                            dateFmt.format(expiry.toLocal()),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Urgency Pill + Quantity Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        urgencyLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: urgencyText),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
