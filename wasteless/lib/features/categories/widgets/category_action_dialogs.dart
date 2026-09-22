import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/common.dart';

class CategoryActionDialogs {
  CategoryActionDialogs._();

  static void showItemDetailsBottomSheet({
    required BuildContext context,
    required SupabaseService supa,
    required Map<String, dynamic> item,
    required VoidCallback onMutated,
  }) {
    final name = (item['name'] as String?) ?? 'Unnamed Item';
    final quantity = (item['quantity'] as int?) ?? 1;
    final expiryStr = item['expiry_date'] as String?;
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final links = item['inventory_item_categories'] as List<dynamic>? ?? [];
    final cats = links.map((l) => (l['categories'] as Map<String, dynamic>? ?? {})).toList();
    final catName = cats.isNotEmpty ? (cats.first['name'] as String? ?? 'General') : 'General';
    final catIcon = cats.isNotEmpty ? (cats.first['icon_url'] as String?) : null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = expiry != null ? DateTime(expiry.year, expiry.month, expiry.day) : today;
    final daysLeft = expiryDay.difference(today).inDays;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Center(
                        child: (catIcon != null && catIcon.isNotEmpty)
                            ? Image.network(catIcon, width: 28, height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.eco, color: AppColors.primary, size: 26))
                            : const Icon(Icons.eco, color: AppColors.primary, size: 26),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('Category: $catName • Qty: $quantity', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: daysLeft <= 1
                        ? const Color(0xFFFEF2F2)
                        : (daysLeft <= 3 ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: daysLeft <= 1
                          ? const Color(0xFFFECACA)
                          : (daysLeft <= 3 ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        daysLeft <= 1 ? Icons.warning_amber_rounded : Icons.access_time_filled,
                        color: daysLeft <= 1
                            ? const Color(0xFFDC2626)
                            : (daysLeft <= 3 ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              daysLeft < 0
                                  ? 'Item expired ${-daysLeft} day(s) ago'
                                  : (daysLeft == 0 ? 'Item expires today' : '$daysLeft days remaining until expiry'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: daysLeft <= 1
                                    ? const Color(0xFFDC2626)
                                    : (daysLeft <= 3 ? const Color(0xFF92400E) : const Color(0xFF166534)),
                              ),
                            ),
                            if (expiry != null)
                              Text('Expiry: ${DateFormat.yMMMd().format(expiry)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Actions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Consume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B074),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showConsumeDialog(context: context, supa: supa, item: item, onMutated: onMutated);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.card_giftcard, size: 16),
                        label: const Text('Donate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0277BD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showDonateDialog(context: context, supa: supa, item: item, onMutated: onMutated);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Waste'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          showLogWasteDialog(context: context, supa: supa, item: item, onMutated: onMutated);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showConsumeDialog({
    required BuildContext context,
    required SupabaseService supa,
    required Map<String, dynamic> item,
    required VoidCallback onMutated,
  }) {
    final itemId = item['id']?.toString() ?? '';
    final itemName = (item['name'] as String?) ?? 'Item';
    final maxQty = (item['quantity'] as int?) ?? 1;
    int consumeQty = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: Color(0xFF00B074), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Mark as Consumed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity consumed:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: consumeQty > 1 ? () => setDialogState(() => consumeQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$consumeQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: consumeQty < maxQty ? () => setDialogState(() => consumeQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B074),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await supa.consumeItem(itemId, consumeQty);
                    if (context.mounted) {
                      final remaining = maxQty - consumeQty;
                      final msg = remaining > 0
                          ? 'Consumed $consumeQty of $itemName ($remaining remaining)'
                          : 'Consumed all $itemName!';
                      showCornerToast(context, message: msg);
                      onMutated();
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showRemoveDialog({
    required BuildContext context,
    required SupabaseService supa,
    required Map<String, dynamic> item,
    required VoidCallback onMutated,
  }) {
    final itemId = item['id']?.toString() ?? '';
    final itemName = (item['name'] as String?) ?? 'Item';
    final maxQty = (item['quantity'] as int?) ?? 1;
    int removeQty = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Remove from Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity to remove:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: removeQty > 1 ? () => setDialogState(() => removeQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$removeQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: removeQty < maxQty ? () => setDialogState(() => removeQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final remaining = maxQty - removeQty;
                    if (remaining <= 0) {
                      await supa.deleteInventoryItem(itemId);
                    } else {
                      await supa.updateItemQuantity(itemId, remaining);
                    }
                    if (context.mounted) {
                      showCornerToast(context, message: 'Removed $removeQty of $itemName');
                      onMutated();
                    }
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showLogWasteDialog({
    required BuildContext context,
    required SupabaseService supa,
    required Map<String, dynamic> item,
    required VoidCallback onMutated,
  }) {
    final itemId = item['id']?.toString() ?? '';
    final itemName = (item['name'] as String?) ?? 'Item';
    final maxQty = (item['quantity'] as int?) ?? 1;
    String selectedReason = 'Expired';
    int wasteQty = 1;
    final reasons = ['Expired', 'Spoiled', 'Leftover', 'Moldy', 'Other'];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Log Waste', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  const Text('Reason for waste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    borderRadius: BorderRadius.circular(16),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity to waste:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: wasteQty > 1 ? () => setDialogState(() => wasteQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$wasteQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: wasteQty < maxQty ? () => setDialogState(() => wasteQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    await supa.logWaste(itemId, wasteQty, selectedReason);
                    if (context.mounted) {
                      showCornerToast(context, message: 'Logged $wasteQty of $itemName as waste');
                      onMutated();
                    }
                  },
                  child: const Text('Log Waste'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static void showDonateDialog({
    required BuildContext context,
    required SupabaseService supa,
    required Map<String, dynamic> item,
    required VoidCallback onMutated,
  }) {
    final itemId = item['id']?.toString() ?? '';
    final itemName = (item['name'] as String?) ?? 'Item';
    final maxQty = (item['quantity'] as int?) ?? 1;
    final recipientCtrl = TextEditingController();
    int donateQty = 1;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogInnerCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.card_giftcard, color: Color(0xFF0277BD), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Offer Donation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: $itemName', style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: recipientCtrl,
                    decoration: InputDecoration(
                      labelText: 'Recipient info (shelter, person, etc.)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Quantity to donate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: donateQty > 1 ? () => setDialogState(() => donateQty--) : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('$donateQty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                              onPressed: donateQty < maxQty ? () => setDialogState(() => donateQty++) : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0277BD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final info = recipientCtrl.text.trim();
                    if (info.isEmpty) return;
                    Navigator.pop(dialogCtx);
                    await supa.offerDonation(itemId, info, donateQty);
                    if (context.mounted) {
                      showCornerToast(context, message: 'Offered $donateQty of $itemName to $info');
                      onMutated();
                    }
                  },
                  child: const Text('Donate'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
