// lib/pages/donation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../models/charity_organization.dart';
import '../models/donation_item.dart';
import '../services/communication_service.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class DonationPage extends StatefulWidget {
  static const route = '/donate';
  final SupabaseService supa;
  final VoidCallback? onBackToHome;
  const DonationPage({required this.supa, this.onBackToHome, super.key});

  @override
  DonationPageState createState() => DonationPageState();
}

class DonationPageState extends State<DonationPage> {
  // Navigation arguments for single-item donation flow
  String? _itemId;
  String _itemName = '';
  DateTime? _itemExpiry;
  int _itemQuantity = 1;

  // Data state
  bool _isLoading = true;
  List<DonationItem> _donations = [];
  List<CharityOrganization> _charities = [];

  // Tab controller: 0 = My Donations, 1 = Charity Directory
  int _currentTabIndex = 0;

  // Filter & Search state
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSearchOpen = false;

  String _selectedStatusFilter = 'All'; // 'All', 'pending', 'scheduled', 'completed'
  String _selectedCharityCategory = 'All'; // 'All', 'Orphanage', 'Food Bank', 'NGO', 'Shelter'

  // Single-item offer form controllers
  CharityOrganization? _selectedCharity;
  String _logisticsType = 'pickup'; // 'pickup' or 'drop_off'
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  int _offerQuantity = 1;
  bool _isSubmittingOffer = false;

  // Calendar Window style pickup date & time slot
  DateTime _pickupDate = DateTime.now();
  String _timeSlot = 'Morning (9:00 AM - 12:00 PM)';

  bool get _isPickupAfterExpiry {
    if (_itemExpiry == null) return false;
    final pDate = DateTime(_pickupDate.year, _pickupDate.month, _pickupDate.day);
    final eDate = DateTime(_itemExpiry!.year, _itemExpiry!.month, _itemExpiry!.day);
    return pDate.isAfter(eDate);
  }

  // Multi-selection state for Donations tab
  final Set<String> _selectedDonationIds = {};
  bool get isSelectionMode => _selectedDonationIds.isNotEmpty;

  void _toggleDonationSelection(String id) {
    setState(() {
      if (_selectedDonationIds.contains(id)) {
        _selectedDonationIds.remove(id);
      } else {
        _selectedDonationIds.add(id);
      }
    });
  }

  void _selectAllDonations(List<DonationItem> visible) {
    setState(() {
      _selectedDonationIds.addAll(visible.map((d) => d.id));
    });
  }

  void _clearDonationSelection() {
    setState(() {
      _selectedDonationIds.clear();
    });
  }

  final DateFormat _dateFmt = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _itemId == null) {
      _itemId = args['id']?.toString();
      _itemName = (args['name'] as String?) ?? '';
      final rawQ = args['quantity'];
      _itemQuantity = (rawQ is num) ? rawQ.toInt() : (int.tryParse(rawQ?.toString() ?? '') ?? 1);
      _offerQuantity = 1;
      if (args['expiry'] != null) {
        _itemExpiry = DateTime.tryParse(args['expiry'].toString());
      }
      _fetchLiveItemDetailsIfAvailable();
    }
  }

  Future<void> _fetchLiveItemDetailsIfAvailable() async {
    if (_itemId == null || _itemId!.isEmpty) return;
    try {
      final res = await widget.supa.client
          .from('inventory_items')
          .select('name, quantity, expiry_date')
          .eq('id', _itemId!)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          final liveName = res['name']?.toString() ?? '';
          if (liveName.isNotEmpty && _itemName.isEmpty) {
            _itemName = liveName;
          }
          final liveQty = res['quantity'];
          if (liveQty != null) {
            final parsed = (liveQty is num) ? liveQty.toInt() : (int.tryParse(liveQty.toString()) ?? 1);
            if (parsed > 0) {
              _itemQuantity = parsed;
              if (_offerQuantity > _itemQuantity) {
                _offerQuantity = _itemQuantity;
              }
            }
          }
          final liveExp = res['expiry_date']?.toString();
          if (liveExp != null && liveExp.isNotEmpty && _itemExpiry == null) {
            _itemExpiry = DateTime.tryParse(liveExp);
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    final donations = await widget.supa.fetchDonationModels();
    final charities = await widget.supa.fetchCharities();

    if (mounted) {
      setState(() {
        _donations = donations;
        _charities = charities;
        _isLoading = false;
        if (_selectedCharity == null && charities.isNotEmpty) {
          _selectedCharity = charities.first;
        }
      });
    }
  }

  Future<void> _refresh() async {
    await _loadAllData();
  }

  /// Allow parent bottom navigation to refresh data
  void refresh() => _refresh();

  // ---------- Form Submission & Dispatch ----------

  Future<void> _submitDonationOffer() async {
    if (_itemId == null) return;
    if (_selectedCharity == null) {
      showCornerToast(context, message: 'Please select a recipient organization');
      return;
    }

    if (_isPickupAfterExpiry) {
      showCornerToast(context, message: 'Pickup date cannot be after item expiry');
      return;
    }

    final address = _addressCtrl.text.trim();
    if (_logisticsType == 'pickup' && address.isEmpty) {
      showCornerToast(context, message: 'Please provide a pickup address');
      return;
    }

    setState(() => _isSubmittingOffer = true);

    final timeWindow = '${_dateFmt.format(_pickupDate)} • $_timeSlot';

    try {
      final recipientJson = DonationItem.encodeRecipientInfo(
        charityName: _selectedCharity!.name,
        charityPhone: _selectedCharity!.phone,
        charityCategory: _selectedCharity!.category,
        logisticsType: _logisticsType,
        address: address.isNotEmpty ? address : _selectedCharity!.address,
        timeWindow: timeWindow,
        donorPhone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        expiry: _itemExpiry,
        quantity: _offerQuantity,
        status: 'pending',
      );

      await widget.supa.offerDonation(
        _itemId!,
        recipientJson,
        _offerQuantity,
        _selectedCharity!.id,
      );

      if (!mounted) return;

      // Prepare WhatsApp template
      final dispatchMsg = CommunicationService.formatDonationWhatsAppMessage(
        itemName: _itemName,
        quantity: _offerQuantity,
        expiry: _itemExpiry,
        charityName: _selectedCharity!.name,
        logisticsType: _logisticsType,
        address: address.isNotEmpty ? address : _selectedCharity!.address,
        timeWindow: timeWindow,
        donorPhone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );

      // Open Instant Multi-Channel Dispatch Modal
      _showDispatchConfirmationSheet(
        charity: _selectedCharity!,
        dispatchMessage: dispatchMsg,
      );
    } catch (e) {
      if (mounted) showCornerToast(context, message: 'Failed to record donation: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingOffer = false);
    }
  }

  void _showDispatchConfirmationSheet({
    required CharityOrganization charity,
    required String dispatchMessage,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 18),

                // Success Icon & Title
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 44),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Donation Recorded!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Item deducted from inventory. Now notify ${charity.name} so they can confirm pickup/drop-off.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                // Organization Quick Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gradientStart.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.gradientStart, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              charity.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                            ),
                            Text(
                              'Phone / WhatsApp: ${charity.phone}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 1-Tap Action: WhatsApp
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                    label: const Text(
                      'Notify via WhatsApp (1-Tap)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      CommunicationService.launchWhatsApp(
                        context: context,
                        phone: charity.whatsapp ?? charity.phone,
                        message: dispatchMessage,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Action: Direct Call & Copy Summary
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 18),
                        label: const Text('Call NGO'),
                        onPressed: () {
                          CommunicationService.launchCall(
                            context: context,
                            phone: charity.phone,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E293B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Details'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: dispatchMessage));
                          showCornerToast(context, message: 'Donation summary copied to clipboard');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Done Button
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    if (_itemId != null) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Done & Return', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Donation Status & Cancellation ----------

  Future<void> _changeDonationStatus(DonationItem item, String newStatus) async {
    try {
      await widget.supa.updateDonationStatus(
        item.id,
        newStatus,
        item.toMap(),
      );
      if (mounted) showCornerToast(context, message: 'Status updated to ${newStatus.toUpperCase()}');
      await _loadAllData();
    } catch (e) {
      if (mounted) showCornerToast(context, message: 'Failed to update status');
    }
  }

  Future<void> _confirmCancelDonation(DonationItem item) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Donation Offer?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Do you want to cancel the donation offer for "${item.itemName}"?\n\n'
          'Would you like to return this item back to your active inventory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Keep Offer'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'delete_only'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete Only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'return_and_delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gradientStart,
              foregroundColor: Colors.white,
            ),
            child: const Text('Return to Inventory'),
          ),
        ],
      ),
    );

    if (result == 'return_and_delete' || result == 'delete_only') {
      final returnToInv = result == 'return_and_delete';
      await widget.supa.cancelDonation(
        item.id,
        returnToInventory: returnToInv,
        donationData: item.toMap(),
      );

      if (mounted) {
        showCornerToast(
          context,
          message: returnToInv
              ? 'Donation cancelled & item returned to inventory'
              : 'Donation record deleted',
        );
      }
      await _loadAllData();
    }
  }

  // ---------- Bulk Actions on Donations ----------

  Future<void> _performBulkMarkCompleted(List<DonationItem> visible) async {
    final selectedItems = visible.where((d) => _selectedDonationIds.contains(d.id)).toList();
    if (selectedItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Mark as Completed?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Mark ${selectedItems.length} selected donation(s) as completed / picked up?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B074),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Completed'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.supa.bulkUpdateDonationStatus(
          selectedItems.map((d) => d.toMap()).toList(),
          'completed',
        );
        _clearDonationSelection();
        if (mounted) showCornerToast(context, message: 'Marked ${selectedItems.length} donation(s) as completed');
      } catch (e) {
        if (mounted) showCornerToast(context, message: 'Failed to update status');
      } finally {
        await _loadAllData();
      }
    }
  }

  Future<void> _performBulkReturnToInventory(List<DonationItem> visible) async {
    final selectedItems = visible.where((d) => _selectedDonationIds.contains(d.id)).toList();
    if (selectedItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Return to Inventory?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Return ${selectedItems.length} selected donation item(s) back to active inventory?\n\n'
          'Original item quantities and expiry dates will be preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gradientStart,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Return to Inventory'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.supa.bulkCancelDonations(
          selectedItems.map((d) => d.toMap()).toList(),
          returnToInventory: true,
        );
        _clearDonationSelection();
        if (mounted) {
          showCornerToast(
            context,
            message: 'Returned ${selectedItems.length} item(s) to inventory',
          );
        }
      } catch (e) {
        if (mounted) showCornerToast(context, message: 'Failed to return items');
      } finally {
        await _loadAllData();
      }
    }
  }

  Future<void> _performBulkDelete(List<DonationItem> visible) async {
    final selectedItems = visible.where((d) => _selectedDonationIds.contains(d.id)).toList();
    if (selectedItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Donation Records?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Permanently delete ${selectedItems.length} donation record(s)?\n\n'
          'Note: Items will NOT be returned to inventory.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Records'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await widget.supa.bulkCancelDonations(
          selectedItems.map((d) => d.toMap()).toList(),
          returnToInventory: false,
        );
        _clearDonationSelection();
        if (mounted) showCornerToast(context, message: 'Deleted ${selectedItems.length} donation record(s)');
      } catch (e) {
        if (mounted) showCornerToast(context, message: 'Failed to delete records');
      } finally {
        await _loadAllData();
      }
    }
  }

  Widget _buildFloatingBulkToolbar({required List<DonationItem> visibleItems}) {
    final allSelected = visibleItems.isNotEmpty && visibleItems.every((d) => _selectedDonationIds.contains(d.id));

    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Toolbar Row: Count, Select All, Close
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_selectedDonationIds.length} selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    if (allSelected) {
                      _clearDonationSelection();
                    } else {
                      _selectAllDonations(visibleItems);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _clearDonationSelection,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bulk Actions Buttons Row
            Row(
              children: [
                // 1. Mark Completed
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Complete',
                    icon: Icons.check_circle_outline,
                    bg: const Color(0xFF00B074),
                    onTap: () => _performBulkMarkCompleted(visibleItems),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Return to Inv
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Return',
                    icon: Icons.undo_rounded,
                    bg: AppColors.gradientStart,
                    onTap: () => _performBulkReturnToInventory(visibleItems),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Delete
                Expanded(
                  child: _buildBulkBtn(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    bg: Colors.redAccent,
                    onTap: () => _performBulkDelete(visibleItems),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkBtn({
    required String label,
    required IconData icon,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Add Custom Charity Dialog ----------

  Future<void> _showAddCustomCharityDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    String category = 'Orphanage';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add Charity Organization', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Organization Name *', hintText: 'e.g. Hope Orphanage'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'Orphanage', child: Text('Orphanage / Children\'s Home')),
                    DropdownMenuItem(value: 'Food Bank', child: Text('Food Bank / Recovery')),
                    DropdownMenuItem(value: 'NGO', child: Text('NGO / Community Relief')),
                    DropdownMenuItem(value: 'Shelter', child: Text('Shelter / Elderly Home')),
                  ],
                  onChanged: (v) => setModalState(() => category = v ?? 'Orphanage'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone / WhatsApp *', hintText: '+234 801 ...'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', hintText: 'Street, Area, City'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gradientStart,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save Organization'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final customCharity = CharityOrganization(
        id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
        name: nameCtrl.text.trim(),
        category: category,
        phone: phoneCtrl.text.trim(),
        whatsapp: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : 'Lagos, Nigeria',
        acceptedItems: ['Packaged Food', 'Canned Food', 'Grains'],
        isVerified: false,
      );

      await widget.supa.addCustomCharity(customCharity);
      if (mounted) showCornerToast(context, message: 'Charity "${customCharity.name}" saved');
      await _loadAllData();
    }
  }

  // ---------- Filtering Helpers ----------

  List<DonationItem> _getFilteredDonations() {
    var list = _donations;

    // Status filter
    if (_selectedStatusFilter != 'All') {
      list = list.where((d) => d.status.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    // Search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) {
        return d.itemName.toLowerCase().contains(q) ||
            d.charityName.toLowerCase().contains(q) ||
            (d.address?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  List<CharityOrganization> _getFilteredCharities() {
    var list = _charities;

    if (_selectedCharityCategory != 'All') {
      list = list.where((c) => c.category.toLowerCase() == _selectedCharityCategory.toLowerCase()).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.category.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  // ---------- Build Method ----------

  @override
  Widget build(BuildContext context) {
    // If opened to offer donation for a specific item
    if (_itemId != null && _itemId!.isNotEmpty) {
      return _buildSingleItemOfferScaffold();
    }

    // Main Donations Hub (My Donations + Charity Directory)
    final filteredDonations = _getFilteredDonations();
    final filteredCharities = _getFilteredCharities();

    int pendingCount = _donations.where((d) => d.status == 'pending').length;
    int completedCount = _donations.where((d) => d.status == 'completed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.gradientStart,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Collapsible Curved Header
                _buildCurvedHeader(
                  totalDonations: _donations.length,
                  pendingCount: pendingCount,
                ),

                // Segmented Tabs Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: _buildSegmentedTabController(),
                  ),
                ),

                // Loading state
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (_currentTabIndex == 0) ...[
                  // Summary Stat Pills
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: _buildDonationStatsRow(
                        total: _donations.length,
                        pending: pendingCount,
                        completed: completedCount,
                      ),
                    ),
                  ),

                  // Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', 'All', _donations.length),
                            const SizedBox(width: 6),
                            _buildFilterChip('Pending', 'pending', pendingCount),
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              'Scheduled',
                              'scheduled',
                              _donations.where((d) => d.status == 'scheduled').length,
                            ),
                            const SizedBox(width: 6),
                            _buildFilterChip('Completed', 'completed', completedCount),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Donations List
                  if (filteredDonations.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyDonationsView(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, isSelectionMode ? 100 : 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, idx) => _buildDonationCard(filteredDonations[idx]),
                          childCount: filteredDonations.length,
                        ),
                      ),
                    ),
                ],

                // Tab 1: Charity Directory
                if (_currentTabIndex == 1) ...[
                  // Charity Category Filter Chips + Add Custom
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCharityCategoryChip('All', 'All'),
                                  const SizedBox(width: 6),
                                  _buildCharityCategoryChip('Orphanages', 'Orphanage'),
                                  const SizedBox(width: 6),
                                  _buildCharityCategoryChip('Food Banks', 'Food Bank'),
                                  const SizedBox(width: 6),
                                  _buildCharityCategoryChip('NGOs', 'NGO'),
                                  const SizedBox(width: 6),
                                  _buildCharityCategoryChip('Shelters', 'Shelter'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Add Custom Charity',
                            onPressed: _showAddCustomCharityDialog,
                            icon: const Icon(Icons.add_location_alt_rounded, color: AppColors.gradientStart),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Charities List
                  if (filteredCharities.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text('No charities match "$_searchQuery"'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, idx) => _buildCharityCard(filteredCharities[idx]),
                          childCount: filteredCharities.length,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (_currentTabIndex == 0 && isSelectionMode)
            _buildFloatingBulkToolbar(visibleItems: filteredDonations),
        ],
      ),
    );
  }

  // ---------- Curved Header ----------

  Widget _buildCurvedHeader({required int totalDonations, required int pendingCount}) {
    final isExpanded = _isSearchOpen;
    String subtitle;
    if (_searchQuery.isNotEmpty) {
      subtitle = 'Search results for "$_searchQuery"';
    } else {
      subtitle = '$totalDonations Offered • $pendingCount Pending Pickup';
    }

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: isExpanded ? 142 : 106,
      flexibleSpace: Container(
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    // Back Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        tooltip: 'Back',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else if (widget.onBackToHome != null) {
                            widget.onBackToHome!();
                          } else {
                            Navigator.of(context).pushReplacementNamed('/');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Dynamic Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Food Donations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Search Toggle Button
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
                        tooltip: 'Search',
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

                    // Refresh Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        padding: EdgeInsets.zero,
                        onPressed: _refresh,
                      ),
                    ),
                  ],
                ),

                // Expandable Search Bar
                if (_isSearchOpen) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search items, charities, or locations...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.gradientStart),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Segmented Tab Controller ----------

  Widget _buildSegmentedTabController() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildSegmentTabItem(
            index: 0,
            title: 'My Donations',
            count: _donations.length,
            icon: Icons.volunteer_activism_rounded,
          ),
          _buildSegmentTabItem(
            index: 1,
            title: 'Charity Directory',
            count: _charities.length,
            icon: Icons.storefront_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTabItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _currentTabIndex == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Donation Stats Row ----------

  Widget _buildDonationStatsRow({required int total, required int pending, required int completed}) {
    return Row(
      children: [
        Expanded(
          child: _buildStatPill(
            label: 'Total',
            value: '$total',
            icon: Icons.volunteer_activism_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatPill(
            label: 'Pending',
            value: '$pending',
            icon: Icons.schedule_rounded,
            color: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatPill(
            label: 'Completed',
            value: '$completed',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Filter Chips ----------

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedStatusFilter.toLowerCase() == value.toLowerCase();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gradientStart : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.gradientStart : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharityCategoryChip(String label, String value) {
    final isSelected = _selectedCharityCategory.toLowerCase() == value.toLowerCase();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selectedCharityCategory = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gradientStart : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppColors.gradientStart : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  // ---------- Donation Card ----------

  Widget _buildDonationCard(DonationItem item) {
    final isPickup = item.logisticsType.toLowerCase() == 'pickup';
    final status = item.status.toLowerCase();

    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFD97706);
    String statusLabel = 'PENDING';

    if (status == 'scheduled') {
      statusBg = const Color(0xFFEFF6FF);
      statusText = const Color(0xFF2563EB);
      statusLabel = 'SCHEDULED';
    } else if (status == 'completed') {
      statusBg = const Color(0xFFECFDF5);
      statusText = const Color(0xFF059669);
      statusLabel = 'COMPLETED';
    }

    final isSelected = _selectedDonationIds.contains(item.id);

    // Reconstruct dispatch message for quick re-dispatch
    final message = CommunicationService.formatDonationWhatsAppMessage(
      itemName: item.itemName,
      quantity: item.quantity,
      expiry: item.itemExpiry,
      charityName: item.charityName,
      logisticsType: item.logisticsType,
      address: item.address,
      timeWindow: item.timeWindow,
      donorPhone: item.donorPhone,
      notes: item.notes,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.gradientStart.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.gradientStart : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? AppColors.gradientStart.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _toggleDonationSelection(item.id),
        onTap: () {
          if (isSelectionMode) {
            _toggleDonationSelection(item.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Checkbox (if in selection mode) + Item name + Status Pill
              Row(
                children: [
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: AppColors.gradientStart,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => _toggleDonationSelection(item.id),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gradientStart.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.gradientStart, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.itemName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (item.quantity > 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Qty: ${item.quantity}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Recipient: ${item.charityName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Logistics & Meta Row
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPickup ? Icons.local_shipping_outlined : Icons.directions_walk_rounded,
                          size: 14,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isPickup
                                ? 'Pickup at: ${item.address ?? "Address provided to coordinator"}'
                                : 'Self Drop-off at: ${item.charityName}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (item.timeWindow != null && item.timeWindow!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            'Time: ${item.timeWindow}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const Spacer(),
                          Text(
                            _dateFmt.format(item.offeredAt.toLocal()),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Actions Row: WhatsApp, Call, Status Change, Delete
              Row(
                children: [
                  // WhatsApp 1-tap dispatch
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                    label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: isSelectionMode
                        ? null
                        : () {
                            final phone = item.charityPhone ?? '';
                            CommunicationService.launchWhatsApp(
                              context: context,
                              phone: phone.isNotEmpty ? phone : '+2348033024825',
                              message: message,
                            );
                          },
                  ),
                  const SizedBox(width: 6),

                  // Call
                  if (item.charityPhone != null && item.charityPhone!.isNotEmpty) ...[
                    IconButton(
                      tooltip: 'Call Charity',
                      icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF334155)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(32, 32),
                      ),
                      onPressed: isSelectionMode
                          ? null
                          : () => CommunicationService.launchCall(context: context, phone: item.charityPhone!),
                    ),
                    const SizedBox(width: 6),
                  ],

                  const Spacer(),

                  // Status Dropdown / Action
                  PopupMenuButton<String>(
                    tooltip: 'Change Status',
                    enabled: !isSelectionMode,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF475569)),
                        ],
                      ),
                    ),
                    onSelected: (newStatus) => _changeDonationStatus(item, newStatus),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'pending', child: Text('Mark as Pending')),
                      const PopupMenuItem(value: 'scheduled', child: Text('Mark as Scheduled / Claimed')),
                      const PopupMenuItem(value: 'completed', child: Text('Mark as Completed / Picked Up')),
                    ],
                  ),
                  const SizedBox(width: 6),

                  // Cancel / Delete
                  IconButton(
                    tooltip: 'Cancel Donation',
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: isSelectionMode ? null : () => _confirmCancelDonation(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Charity Card ----------

  Widget _buildCharityCard(CharityOrganization charity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + Category Badge + Verified
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        charity.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (charity.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gradientStart.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  charity.category,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gradientStart),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Address & Hours
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${charity.address}, ${charity.city}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                charity.operatingHours,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),

          // Accepted Items pills
          if (charity.acceptedItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: charity.acceptedItems.take(4).map((it) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(it, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),

          // Action Buttons: WhatsApp & Call
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 14),
                label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  CommunicationService.launchWhatsApp(
                    context: context,
                    phone: charity.whatsapp ?? charity.phone,
                    message: 'Hello ${charity.name}, I would like to offer food donations through the WasteLess app.',
                  );
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.phone_rounded, size: 14),
                label: const Text('Call Center', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  CommunicationService.launchCall(
                    context: context,
                    phone: charity.phone,
                  );
                },
              ),
              if (charity.email != null && charity.email!.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Send Email',
                  icon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    CommunicationService.launchEmail(
                      context: context,
                      email: charity.email!,
                      subject: 'Food Donation Offer via WasteLess',
                      body: 'Hello ${charity.name},\n\nI have surplus food available for donation.',
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Empty Donations View ----------

  Widget _buildEmptyDonationsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.volunteer_activism_outlined, size: 48, color: AppColors.gradientStart),
            ),
            const SizedBox(height: 16),
            const Text(
              'No food donations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Help reduce hunger and food waste! When you have surplus food in your inventory or fridge, offer it to verified charity homes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentTabIndex = 1),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text('Explore Charity Directory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gradientStart,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Single Item Offer Scaffold ----------

  Widget _buildSingleItemOfferScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(
          'Donate: $_itemName',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gradientStart.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: AppColors.gradientStart, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _itemName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        if (_itemExpiry != null)
                          Text(
                            'Expiry: ${_dateFmt.format(_itemExpiry!)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  // Quantity Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: _offerQuantity > 1 ? () => setState(() => _offerQuantity--) : null,
                          ),
                          Text('$_offerQuantity', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: _offerQuantity < _itemQuantity ? () => setState(() => _offerQuantity++) : null,
                          ),
                        ],
                      ),
                      Text(
                        'In stock: $_itemQuantity',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Select Charity Dropdown
            const Text('Select Recipient Organization *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CharityOrganization>(
                  value: _selectedCharity,
                  isExpanded: true,
                  items: _charities.map((c) {
                    return DropdownMenuItem<CharityOrganization>(
                      value: c,
                      child: Row(
                        children: [
                          Icon(Icons.storefront_rounded, size: 18, color: AppColors.gradientStart),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${c.name} (${c.category})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedCharity = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logistics Toggle: Pickup vs Drop-off
            const Text('Logistics Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _logisticsType = 'pickup'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _logisticsType == 'pickup' ? AppColors.gradientStart : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _logisticsType == 'pickup' ? AppColors.gradientStart : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_shipping_outlined,
                            color: _logisticsType == 'pickup' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Request Pickup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _logisticsType == 'pickup' ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _logisticsType = 'drop_off'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _logisticsType == 'drop_off' ? AppColors.gradientStart : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _logisticsType == 'drop_off' ? AppColors.gradientStart : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_walk_rounded,
                            color: _logisticsType == 'drop_off' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'I Will Drop Off',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _logisticsType == 'drop_off' ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup Address / Drop-off location
            if (_logisticsType == 'pickup') ...[
              TextField(
                controller: _addressCtrl,
                decoration: InputDecoration(
                  labelText: 'Your Pickup Address *',
                  hintText: 'e.g. 14 Admiralty Way, Lekki Phase 1',
                  prefixIcon: const Icon(Icons.place_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Available Time Window (Calendar style with Expiry validation)
            const Text('Pickup Date & Available Time Window *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isPickupAfterExpiry ? const Color(0xFFFEF2F2) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isPickupAfterExpiry ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                  width: _isPickupAfterExpiry ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isPickupAfterExpiry ? Colors.red.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: _isPickupAfterExpiry ? const Color(0xFFDC2626) : AppColors.gradientStart,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pickup: ${_dateFmt.format(_pickupDate)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _isPickupAfterExpiry ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: Icon(
                          Icons.edit_calendar_rounded,
                          size: 15,
                          color: _isPickupAfterExpiry ? Colors.red : AppColors.gradientStart,
                        ),
                        label: Text(
                          'Change Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isPickupAfterExpiry ? Colors.red : AppColors.gradientStart,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _isPickupAfterExpiry ? Colors.redAccent : const Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _pickupDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _pickupDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  if (_isPickupAfterExpiry) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Pickup date (${_dateFmt.format(_pickupDate)}) is after item expiry (${_itemExpiry != null ? _dateFmt.format(_itemExpiry!) : "Expired"}). Charities cannot accept food past expiry. Please select a date on or before expiry.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), height: 1.3, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text('Preferred Time Window', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _timeSlot,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Morning (9:00 AM - 12:00 PM)', child: Text('Morning (9:00 AM - 12:00 PM)', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Afternoon (1:00 PM - 4:00 PM)', child: Text('Afternoon (1:00 PM - 4:00 PM)', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'Evening (4:00 PM - 7:00 PM)', child: Text('Evening (4:00 PM - 7:00 PM)', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'All Day (9:00 AM - 6:00 PM)', child: Text('All Day (9:00 AM - 6:00 PM)', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => setState(() => _timeSlot = v ?? _timeSlot),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Donor Phone
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Your Contact Phone / WhatsApp',
                hintText: 'e.g. +234 801 234 5678',
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Optional Notes
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'Notes for Driver / Coordinator',
                hintText: 'e.g. Kept cold, gate code 1234',
                prefixIcon: const Icon(Icons.notes_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPickupAfterExpiry ? Colors.grey : AppColors.gradientStart,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: (_isSubmittingOffer || _isPickupAfterExpiry) ? null : _submitDonationOffer,
                icon: _isSubmittingOffer
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.volunteer_activism_rounded),
                label: Text(
                  _isSubmittingOffer
                      ? 'Processing...'
                      : _isPickupAfterExpiry
                          ? 'Pickup Date Exceeds Expiry'
                          : 'Offer Food Donation',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}