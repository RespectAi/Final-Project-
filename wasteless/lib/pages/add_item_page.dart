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
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  DateTime _expiry = DateTime.now().add(Duration(days: 7));
  int _quantity = 1;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await widget.supa.addItem(name: _name, expiry: _expiry, quantity: _quantity);
    Navigator.pop(context);
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
