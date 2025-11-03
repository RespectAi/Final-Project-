// lib/pages/waste_log_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';

class WasteLogPage extends StatefulWidget {
  static const route = '/waste';
  final SupabaseService supa;

  const WasteLogPage({required this.supa, super.key});

  @override
  WasteLogPageState createState() => WasteLogPageState();
}

class WasteLogPageState extends State<WasteLogPage> {
  String? itemId;
  String itemName = '';
  int _qty = 1;
  String _reason = '';
  late Future<List<Map<String, dynamic>>> _logs;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      itemId = args['id']?.toString();
      itemName = (args['name'] as String?) ?? '';
    }
  }

  Future<void> _submit(String itemId) async {
    await widget.supa.logWaste(itemId, _qty, _reason);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logs = widget.supa.fetchWasteLogs();
    });
  }

  // Allow parent to trigger refresh when tab becomes active
  void refresh() => _refreshLogs();

  @override
  Widget build(BuildContext context) {
    if (itemId != null && itemId!.isNotEmpty) {
      return Scaffold(
        appBar: buildGradientAppBar(context, 'Log Waste: ${itemName.isEmpty ? "Item" : itemName}'),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Reason (optional)'),
                onChanged: (v) => _reason = v.trim(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Quantity wasted:'),
                  const SizedBox(width: 12),
                  IconButton(onPressed: () => setState(() => _qty = (_qty - 1).clamp(1, 999)), icon: const Icon(Icons.remove)),
                  Text('$_qty'),
                  IconButton(onPressed: () => setState(() => _qty = (_qty + 1).clamp(1, 999)), icon: const Icon(Icons.add)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => _submit(itemId!), child: const Text('Submit')),
              ),
            ],
          ),
        ),
      );
    } else {
      final showOwnAppBar = Navigator.of(context).canPop();
      return Scaffold(
        appBar: showOwnAppBar ? buildGradientAppBar(context, 'All Waste Logs', showBackIfCanPop: true) : null,
        body: RefreshIndicator(
          onRefresh: _refreshLogs,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _logs,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return const Center(child: Text('No waste logged yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  final when = DateTime.parse(log['logged_at']);
                  final formatted = DateFormat.yMMMd().add_jm().format(when);
                  final inv = log['inventory_items'] as Map<String, dynamic>?;
                  final invName = (log['item_name'] as String?) ?? (inv?['name'] as String?) ?? 'Unknown Item';
                  return Dismissible(
                    key: Key(log['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete entry?'),
                          content: const Text('Remove this waste-log permanently?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      return ok == true;
                    },
                    onDismissed: (_) async {
                      await widget.supa.deleteWasteLog(log['id'].toString());
                      await _refreshLogs();
                    },
                    child: Card(
                      child: ListTile(
                        title: Text('$invName — ${log['quantity']}'),
                        subtitle: Text('${log['reason'] ?? 'no reason'} • $formatted'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete entry?'),
                                content: const Text('Remove this waste-log permanently?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await widget.supa.deleteWasteLog(log['id'].toString());
                              await _refreshLogs();
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }
  }
}
