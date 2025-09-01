// lib/pages/fridges_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';
import 'donation_page.dart';
import 'waste_log_page.dart';
import 'package:flutter/services.dart';

class FridgesPage extends StatefulWidget {
  static const route = '/fridges';
  final SupabaseService supa;
  const FridgesPage({required this.supa, Key? key}) : super(key: key);

  @override
  State<FridgesPage> createState() => _FridgesPageState();
}

class _FridgesPageState extends State<FridgesPage> {
  late Future<List<Map<String, dynamic>>> _fridgesFuture;
  final TextEditingController _joinCtrl = TextEditingController();
  final DateFormat _dateFmt = DateFormat.yMMMd().add_jm();
  final Set<String> _selectedFridgeIds = {};
  final Map<String, Map<String, dynamic>> _selectedFridges = {};
  
  void _toggleSelection(String fridgeId, Map<String, dynamic> fridge) {
  if (!widget.supa.isAdminMode) return; // Only admins can select for deletion
  
  setState(() {
    if (_selectedFridgeIds.contains(fridgeId)) {
      _selectedFridgeIds.remove(fridgeId);
      _selectedFridges.remove(fridgeId);
    } else {
      _selectedFridgeIds.add(fridgeId);
      _selectedFridges[fridgeId] = fridge;
    }
  });
}

void _clearSelection() {
  setState(() {
    _selectedFridgeIds.clear();
    _selectedFridges.clear();
  });
}

Future<void> _confirmAndPerformBulkDelete() async {
  if (_selectedFridgeIds.isEmpty) return;
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Selected Fridges'),
      content: Text('Are you sure you want to delete ${_selectedFridgeIds.length} fridge(s)? This action cannot be undone and will remove all items and members.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete All'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    int successCount = 0;
    for (final fridgeId in List<String>.from(_selectedFridgeIds)) {
      final success = await widget.supa.deleteFridge(fridgeId);
      if (success) successCount++;
    }
    
    showCornerToast(
      context, 
      message: successCount == _selectedFridgeIds.length 
        ? 'All fridges deleted successfully'
        : '$successCount/${_selectedFridgeIds.length} fridges deleted'
    );
    
    _clearSelection();
    _refresh();
  }
}

  @override
  void initState() {
    super.initState();
    _fridgesFuture = widget.supa.fetchConnectedFridges();
  }

  @override
  void dispose() {
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _fridgesFuture = widget.supa.fetchConnectedFridges();
    });
    await _fridgesFuture;
  }

  Future<void> _createFridge() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Fridge'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Fridge name')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    final id = await widget.supa.createFridge(name: nameCtrl.text.trim());
    if (id != null) {
      showCornerToast(context, message: 'Fridge created');
      _refresh();
    } else {
      showCornerToast(context, message: 'Failed to create fridge');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        'Fridges',
        actions: [
          if (widget.supa.isAdminMode)
            IconButton(icon: const Icon(Icons.add), tooltip: 'Create fridge', onPressed: _createFridge),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fridgesFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
            final fridges = snap.data ?? [];
            if (fridges.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(child: Text('No fridges found')),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(controller: _joinCtrl, decoration: const InputDecoration(hintText: 'Enter fridge code to join')),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
  onPressed: () async {
    final code = _joinCtrl.text.trim();
    if (code.isEmpty) return;
    final result = await widget.supa.joinFridgeWithCode(code);
if (result['success'] == true) {
  final fridgeName = result['fridgeName'] ?? 'Unknown Fridge';
  final already = result['alreadyMember'] == true;
  showCornerToast(context, message: already ? 'Already member of $fridgeName' : 'Joined $fridgeName');
  _joinCtrl.clear();
  await _refresh(); // ensure UI waits for the fresh list
  setState(() {});
} else {
  showCornerToast(context, message: result['message'] ?? 'Failed to join');
}

  },
  child: const Text('Join'),
),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Stack(
  children: [
    ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: fridges.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        if (i == fridges.length) {
          // join-by-code footer
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _joinCtrl, decoration: const InputDecoration(hintText: 'Enter fridge code to join'))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final code = _joinCtrl.text.trim();
                    if (code.isEmpty) return;
                    final result = await widget.supa.joinFridgeWithCode(code);
                    if (result['success'] == true) {
                      final fridgeName = result['fridgeName'] ?? 'Unknown Fridge';
                      showCornerToast(context, message: 'Joined $fridgeName');
                      _joinCtrl.clear();
                      _refresh();
                    } else {
                      showCornerToast(context, message: result['message'] ?? 'Failed to join');
                    }
                  },
                  child: const Text('Join'),
                ),
              ],
            ),
          );
        }

        final f = fridges[i];
        final fridgeId = f['id']?.toString() ?? '';
        final isSelected = _selectedFridgeIds.contains(fridgeId);
        final created = f['created_at'] != null ? DateTime.tryParse(f['created_at'].toString()) : null;
        
        return Card(
          color: isSelected ? Colors.blue.shade50 : null,
          child: ListTile(
            leading: isSelected 
              ? const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                )
              : null,
            title: Text((f['name'] as String?) ?? 'Fridge', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: created != null ? Text('Created: ${_dateFmt.format(created.toLocal())}') : null,
            trailing: _selectedFridgeIds.isEmpty ? const Icon(Icons.chevron_right) : null,
            onTap: () async {
              if (_selectedFridgeIds.isNotEmpty) {
                _toggleSelection(fridgeId, f);
                return;
              }
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => FridgeDetailPage(supa: widget.supa, fridge: f)),
              );
              if (changed == true) _refresh();
            },
            onLongPress: () => _toggleSelection(fridgeId, f),
          ),
        );
      },
    ),
    
    // Bottom action bar for bulk selection
    if (_selectedFridgeIds.isNotEmpty && widget.supa.isAdminMode)
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Text('${_selectedFridgeIds.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete selected fridges',
                  onPressed: _confirmAndPerformBulkDelete,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
                IconButton(
                  tooltip: 'Cancel selection',
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
  ],
);
          },
        ),
      ),
    );
  }
}

class FridgeDetailPage extends StatefulWidget {
  final SupabaseService supa;
  final Map<String, dynamic> fridge;
  const FridgeDetailPage({required this.supa, required this.fridge, Key? key}) : super(key: key);

  @override
  State<FridgeDetailPage> createState() => _FridgeDetailPageState();
}

class _FridgeDetailPageState extends State<FridgeDetailPage> {
  late Future<void> _loadFuture;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _requests = [];
  Future<void> _handleFridgeAction(String action) async {
  if (action == 'delete') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Fridge'),
        content: Text('Are you sure you want to delete "${widget.fridge['name'] ?? 'this fridge'}"? This action cannot be undone and will remove all items and members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.supa.deleteFridge(widget.fridge['id'] as String);
      if (success) {
        showCornerToast(context, message: 'Fridge deleted successfully');
        Navigator.pop(context, true); // Return to fridges list
      } else {
        showCornerToast(context, message: 'Failed to delete fridge');
      }
    }
  }
}
  String? _generatedCode;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    final id = widget.fridge['id'] as String;
    final items = await widget.supa.fetchFridgeItems(id);
    final members = await widget.supa.fetchFridgeMembersForFridge(id);
    final requests = await widget.supa.fetchPendingRequestsForFridge(id);
    _items = items;
    _members = members;
    _requests = requests;
  }

  Future<void> _regenerateCode() async {
  final id = widget.fridge['id'] as String;
  final code = await widget.supa.regenerateFridgeCode(id);
  if (code != null) {
    setState(() {
      _generatedCode = code;
    });
  } else {
    showCornerToast(context, message: 'Failed to generate code');
  }
}

void _copyCodeToClipboard(String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  showCornerToast(context, message: 'Code copied to clipboard');
}

  Future<void> _approveRequest(String reqId) async {
    await widget.supa.approveJoinRequest(reqId);
    await _loadAll();
    setState(() {});
  }

  Future<void> _rejectRequest(String reqId) async {
    await widget.supa.rejectJoinRequest(reqId);
    await _loadAll();
    setState(() {});
  }

  Future<void> _deleteItem(String id) async {
    await widget.supa.deleteInventoryItem(id);
    await _loadAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
  final name = (widget.fridge['name'] as String?) ?? 'Fridge';
    final currentUserId = widget.supa.getCurrentUserId();

    return Scaffold(
      appBar: AppBar(
  title: Text(name),
  actions: [
    if (widget.supa.isAdminMode)
      PopupMenuButton<String>(
        onSelected: (value) => _handleFridgeAction(value),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete Fridge')),
        ],
      ),
  ],
),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    if (widget.supa.isAdminMode)
                       TextButton.icon(onPressed: _regenerateCode, icon: const Icon(Icons.refresh), label: const Text('Regenerate Code')),
                        ],
                  ),
                     if (_generatedCode != null) ...[
                         const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                               ),
                              child: Row(
                                 children: [
                                       const Icon(Icons.key, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      const Text('Fridge Code: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                      Expanded(
                                        child: SelectableText(
                                           _generatedCode!,
                                        style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _copyCodeToClipboard(_generatedCode!),
          icon: const Icon(Icons.copy, size: 20),
          tooltip: 'Copy code',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green[100],
            foregroundColor: Colors.green[700],
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(36, 36),
          ),
        ),
      ],
    ),
  ),
],
                const SizedBox(height: 12),
                const Text('Members', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _members.length,
                    itemBuilder: (_, i) {
                      final m = _members[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          avatar: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                          label: Text('${m['user_name']} • ${m['role'] ?? 'user'}'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('No items in this fridge'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, idx) {
                            final it = _items[idx];
                            final ownerId = it['user_id'] as String?;
                            final isOwner = ownerId != null && ownerId == currentUserId;
                            final canEdit = isOwner || widget.supa.isAdminMode;
                            final expiry = DateTime.tryParse(it['expiry_date']?.toString() ?? '');
                            return Card(
                              child: ListTile(
                                leading: isOwner ? const CircleAvatar(child: Icon(Icons.person, size: 16)) : null,
                                title: Text((it['name'] as String?) ?? 'Unnamed'),
                                subtitle: Text('By: ${it['user_name'] ?? (isOwner ? 'You' : 'Other')}${expiry != null ? ' • Exp: ${DateFormat.yMMMd().format(expiry)}' : ''}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'delete') await _deleteItem(it['id'] as String);
                                    if (v == 'donate') Navigator.of(context).pushNamed(DonationPage.route, arguments: {'id': it['id'], 'name': it['name']});
                                    if (v == 'waste') Navigator.of(context).pushNamed(WasteLogPage.route, arguments: {'id': it['id'], 'name': it['name']});
                                    await _loadAll();
                                    setState(() {});
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'donate', child: Text('Offer Donation')),
                                    const PopupMenuItem(value: 'waste', child: Text('Log Waste')),
                                    if (canEdit) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (_requests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Join Requests', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Column(
                    children: _requests.map((r) {
                      return Card(
                        child: ListTile(
                          title: Text(r['requester_name'] ?? 'Unknown'),
                          subtitle: Text(r['message'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _approveRequest(r['id'] as String)),
                              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _rejectRequest(r['id'] as String)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

// small helper badge widget (kept for backward compatibility)
class Badge extends StatelessWidget {
  final Widget child;
  const Badge({required this.child, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: 16, backgroundColor: Colors.green[100], child: child);
  }
}

