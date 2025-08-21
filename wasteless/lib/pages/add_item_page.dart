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

  // Form state
  String _name = '';
  DateTime _expiry = DateTime.now().add(const Duration(days: 7));
  int _quantity = 1;
  int _remindDays = 1;
  int _remindHours = 0;

  // Focus nodes for keyboard "Enter -> next" behavior
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _remindDaysFocus = FocusNode();
  final FocusNode _remindHoursFocus = FocusNode();

  // Loading flag to prevent double submits and show spinner in button
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _allCats = widget.supa.fetchCategories();
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _quantityFocus.dispose();
    _remindDaysFocus.dispose();
    _remindHoursFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // If already submitting, ignore
    if (_loading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    // Save current field values
    _formKey.currentState!.save();

    setState(() => _loading = true);

    try {
      await widget.supa.addItem(
        name: _name,
        expiry: _expiry,
        quantity: _quantity,
        reminderDaysBefore: _remindDays,
        reminderHoursBefore: _remindHours,
        categoryIds: _selectedCatIds.toList(),
      );

      // If add succeeded, pop returning true (so caller can refresh)
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err, stack) {
      debugPrint('Error in addItem: $err\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add item: $err')));
      }
    } finally {
      // If we are still mounted (i.e. didn't pop), clear loading state so UI updates
      if (mounted) setState(() => _loading = false);
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
              // Item name -> pressing enter moves to quantity
              TextFormField(
                focusNode: _nameFocus,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Item Name'),
                onSaved: (v) => _name = v!.trim(),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_quantityFocus),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      focusNode: _quantityFocus,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      initialValue: '1',
                      onSaved: (v) => _quantity = int.tryParse(v ?? '1') ?? 1,
                      validator: (v) {
                        if (v == null) return 'Required';
                        final n = int.tryParse(v);
                        if (n == null || n < 1) return 'Enter a positive number';
                        return null;
                      },
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_remindDaysFocus),
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
                          focusNode: _remindDaysFocus,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(hintText: '1'),
                          keyboardType: TextInputType.number,
                          initialValue: '1',
                          onSaved: (v) => _remindDays = int.tryParse(v ?? '1') ?? 1,
                          onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_remindHoursFocus),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              TextFormField(
                focusNode: _remindHoursFocus,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Remind (hours)'),
                keyboardType: TextInputType.number,
                initialValue: '0',
                onSaved: (v) => _remindHours = int.tryParse(v ?? '0') ?? 0,
                onFieldSubmitted: (_) {
                  // When user presses Enter on the last field, submit the form
                  _submit();
                },
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
                      const Text('Category (required)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: cats.map((c) {
                          final id = c['id'] as String;
                          final name = c['name'] as String;
                          final url = c['icon_url'] as String?;
                          final selected = _selectedCatIds.contains(id);
                          final int? defaultDays = c['default_expiry_days'] as int?;
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
                                if (sel) {
                                  _selectedCatIds.add(id);
                                  if (defaultDays != null && defaultDays > 0) {
                                    _expiry = DateTime.now().add(Duration(days: defaultDays));
                                  }
                                } else {
                                  _selectedCatIds.remove(id);
                                }
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

              // Add button: disabled while loading, shows spinner
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                            SizedBox(width: 12),
                            Text('Adding...'),
                          ],
                        )
                      : const Text('Add Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
