import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class WasteLogPage extends StatefulWidget {
  static const route = '/waste';
  final SupabaseService supa;
  const WasteLogPage({required this.supa, Key? key}) : super(key: key);

  @override
  _WasteLogPageState createState() => _WasteLogPageState();
}

class _WasteLogPageState extends State<WasteLogPage> {
  int _qty = 1;
  String _reason = '';

  Future<void> _submit(String itemId) async {
    await widget.supa.logWaste(itemId, _qty, _reason);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final itemId = ModalRoute.of(context)!.settings.arguments as String;
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
            ElevatedButton(onPressed: () => _submit(itemId), child: Text('Submit'))
          ],
        ),
      ),
    );
  }
}
