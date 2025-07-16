// lib/pages/waste_log_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class WasteLogPage extends StatefulWidget {
  static const route = '/waste';
  final SupabaseService supa;

  const WasteLogPage({required this.supa, Key? key}) : super(key: key);

  @override
  _WasteLogPageState createState() => _WasteLogPageState();
}

class _WasteLogPageState extends State<WasteLogPage> {
  // for the "form" mode
  int _qty = 1;
  String _reason = '';

  // for the "list" mode
  late Future<List<Map<String, dynamic>>> _logs;

  @override
  void initState() {
    super.initState();
    // load logs
    _refreshLogs();
  }

  Future<void> _submit(String itemId) async {
    await widget.supa.logWaste(itemId, _qty, _reason);
    Navigator.pop(context);
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logs = widget.supa.fetchWasteLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final itemId = args is String ? args : null;

    if (itemId != null) {
      // FORM MODE
      return Scaffold(
        appBar: AppBar(title: Text('Log Waste')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Reason (optional)'),
                onChanged: (v) => _reason = v.trim(),
              ),
              SizedBox(height: 16),
              Text('Quantity wasted:'),
              Slider(
                value: _qty.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_qty',
                onChanged: (v) => setState(() => _qty = v.toInt()),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () => _submit(itemId),
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      );
    } else {
      // LIST MODE
      return Scaffold(
        appBar: AppBar(title: Text('All Waste Logs')),
        body: RefreshIndicator(
          onRefresh: _refreshLogs,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _logs,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return Center(child: Text('No waste logged yet.'));
              }
              return ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  final when = DateTime.parse(log['logged_at']);
                  final formatted = DateFormat.yMMMd().add_jm().format(when);
                  final itemName = (log['inventory_items'] as Map)['name'];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('$itemName — ${log['quantity']}'),
                      subtitle: Text(
                        '${log['reason'] ?? 'no reason'} • $formatted',
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('Delete entry?'),
                              content: Text(
                                'Remove this waste-log permanently?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await widget.supa.deleteWasteLog(
                              log['id'].toString(),
                            );
                            await _refreshLogs();
                          }
                        },
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
