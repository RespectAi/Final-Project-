// lib/pages/add_item_page.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/common.dart';


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
  DateTime _expiry = DateTime.now().add(const Duration(days: 7));
  int _quantity = 1;
  int _remindDays = 1;
  int _remindHours = 0;

  @override
  void initState() {
    super.initState();
    _allCats = widget.supa.fetchCategories();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }
    _formKey.currentState!.save();

    try {
      await widget.supa.addItem(
        name: _name,
        expiry: _expiry,
        quantity: _quantity,
        reminderDaysBefore: _remindDays,
        reminderHoursBefore: _remindHours,
        categoryIds: _selectedCatIds.toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err, stack) {
      debugPrint('Error in addItem: $err\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add item: $err')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar('Add Inventory Item'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Item Name'),
                onSaved: (v) => _name = v!.trim(),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      onSaved: (v) => _quantity = int.tryParse(v ?? '1') ?? 1,
                      validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) < 1) ? 'Enter a positive number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Remind (days)'),
                      SizedBox(
                        width: 110,
                        child: TextFormField(
                          decoration: const InputDecoration(hintText: '1'),
                          keyboardType: TextInputType.number,
                          initialValue: '1',
                          onSaved: (v) => _remindDays = int.tryParse(v ?? '1') ?? 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Remind (hours)'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _remindHours = int.tryParse(v ?? '0') ?? 0,
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _allCats,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Text('Error loading categories: ${snap.error}');
                  final cats = snap.data ?? [];
                  if (cats.isEmpty) return const Text('No categories found');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: cats.map((c) {
                          final id = c['id'] as String;
                          final name = c['name'] as String;
                          final url = c['icon_url'] as String?;
                          final selected = _selectedCatIds.contains(id);
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (url != null && url.isNotEmpty) Image.network(url, width: 20, height: 20) else const Icon(Icons.eco, size: 18),
                                const SizedBox(width: 8),
                                Text(name),
                              ],
                            ),
                            selected: selected,
                            onSelected: (sel) {
                              setState(() {
                                if (sel)
                                  _selectedCatIds.add(id);
                                else
                                  _selectedCatIds.remove(id);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (_selectedCatIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text('Please select at least one category', style: TextStyle(color: Colors.redAccent)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text('Expiry: ${_expiry.toLocal().toIso8601String().split('T')[0]}')),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiry,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _expiry = picked);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: const Text('Add Item')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
