import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AddItemPage extends StatefulWidget {
  static const route = '/add';
  final SupabaseService supa;
  const AddItemPage({required this.supa, Key? key}) : super(key: key);

  @override
    _AddItemPageState createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  late Future<List<Map<String, dynamic>>> _allCats;
  final Set<String> _selectedCatIds = {};
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  DateTime _expiry = DateTime.now().add(Duration(days: 7));
  int _quantity = 1;
  int _remindDays = 1;
  int _remindHours = 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      // 1) Try to add the item (including category links & scheduling)
      await widget.supa.addItem(
        name: _name,
        expiry: _expiry,
        quantity: _quantity,
        reminderDaysBefore: _remindDays,
        reminderHoursBefore: _remindHours,
        categoryIds: _selectedCatIds.toList(),
      );

      // 2) Only pop if this State is still mounted
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (err, stack) {
      // 3) Print/log the error so we can see what's wrong
      debugPrint('Error in addItem: $err\n$stack');

      // 4) Show a snack bar so the user knows something failed
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add item: $err')));
      }
    }
  }


  @override
  void initState() {
    super.initState();
    // ←— right here, inside _AddItemPageState:
    _allCats = widget.supa.fetchCategories().then((cats) {
      print('Fetched categories: $cats');
      return cats;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Inventory Item')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Item Name'),
                onSaved: (v) => _name = v!.trim(),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),

              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                initialValue: '1',
                onSaved: (v) => _quantity = int.tryParse(v!) ?? 1,
                validator: (v) => (int.tryParse(v!) == null || int.parse(v) < 1)
                    ? 'Enter a positive number'
                    : null,
              ),

              // after your quantity TextFormField…
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Remind me _ days before',
                ),
                keyboardType: TextInputType.number,
                initialValue: '1',
                onSaved: (v) => _remindDays = int.parse(v!),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'And _ hours before'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _remindHours = int.parse(v!),
              ),

              // ←— INSERT THIS BLOCK HERE:
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _allCats,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator());
                  if (snap.hasError)
                    return Text('Error loading categories: ${snap.error}');
                  final cats = snap.data ?? [];
                  if (cats.isEmpty) return Text('No categories found');

                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Category'),
                    items: cats.map((c) {
                      final id = c['id'] as String;
                      final name = c['name'] as String;
                      final url = c['icon_url'] as String;
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Row(
                          children: [
                            Image.network(url, width: 24, height: 24),
                            SizedBox(width: 8),
                            Text(name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (sel) {
                      setState(() {
                        _selectedCatIds
                          ..clear()
                          ..add(sel!);
                      });
                    },
                    validator: (_) => _selectedCatIds.isEmpty
                        ? 'Please select a category'
                        : null,
                  );
                },
              ),


              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Expiry: ${_expiry.toLocal().toIso8601String().split('T')[0]}',
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiry,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _expiry = picked);
                    },
                  ),
                ],
              ),
              Spacer(),
              ElevatedButton(onPressed: _submit, child: Text('Add Item'))
            ],
          ),
        ),
      ),
    );
  }
}
