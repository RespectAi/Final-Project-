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

  // Multi-item state
  final List<Map<String, dynamic>> _items = [];
  bool _isAddingMultiple = false;

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

  void _addToList() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _items.add({
        'name': _name,
        'expiry': _expiry,
        'quantity': _quantity,
        'reminderDaysBefore': _remindDays,
        'reminderHoursBefore': _remindHours,
        'categoryIds': _selectedCatIds.toList(),
      });

      // Reset form for next item
      _formKey.currentState!.reset();
      _name = '';
      _expiry = DateTime.now().add(const Duration(days: 7));
      _quantity = 1;
      _remindDays = 1;
      _remindHours = 0;
      _selectedCatIds.clear();
    });

    showCornerToast(context, message: 'Item added to list (${_items.length})');
  }

  void _removeFromList(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    // If already submitting, ignore
    if (_loading) return;

    // In single mode, validate and add current item
    if (!_isAddingMultiple) {
      if (!_formKey.currentState!.validate()) return;

      if (_selectedCatIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one category')),
        );
        return;
      }

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

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (err, stack) {
        debugPrint('Error in addItem: $err\n$stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add item: $err')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // Multi-item mode: submit all items in the list
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item to the list')),
        );
        return;
      }

      setState(() => _loading = true);

      try {
        await widget.supa.addMultipleItems(_items);

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } catch (err, stack) {
        debugPrint('Error in addMultipleItems: $err\n$stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add items: $err')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: gradientAppBar(_isAddingMultiple ? 'Add Multiple Items' : 'Add Inventory Item'),
      body: Column(
        children: [
          // Mode toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Mode:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Single Item'), icon: Icon(Icons.add_circle_outline)),
                      ButtonSegment(value: true, label: Text('Multiple Items'), icon: Icon(Icons.library_add)),
                    ],
                    selected: {_isAddingMultiple},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() {
                        _isAddingMultiple = selection.first;
                        // Clear list when switching modes
                        if (!_isAddingMultiple) {
                          _items.clear();
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Form
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item name
                          TextFormField(
                            focusNode: _nameFocus,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Item Name'),
                            onSaved: (v) => _name = v!.trim(),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_quantityFocus),
                          ),
                          const SizedBox(height: 12),

                          // Quantity
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
                              if (_isAddingMultiple) {
                                _addToList();
                              } else {
                                _submit();
                              }
                            },
                          ),

                          const SizedBox(height: 12),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _allCats,
                            builder: (ctx, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
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
                                            if (url != null && url.isNotEmpty)
                                              Image.network(url, width: 20, height: 20)
                                            else
                                              const Icon(Icons.eco, size: 18),
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
                                      child: Text(
                                        'Please select at least one category',
                                        style: TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Expiry: ${_expiry.toLocal().toIso8601String().split('T')[0]}'),
                              ),
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

                          // Action buttons
                          if (_isAddingMultiple)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _addToList,
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('Add to List'),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
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
                ),

                // Right side: Items list (only in multiple mode)
                if (_isAddingMultiple)
                  Expanded(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(left: BorderSide(color: Colors.grey[300]!)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.list_alt, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Items List (${_items.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: _items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No items yet',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Fill the form and tap\n"Add to List"',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _items.length,
                                    itemBuilder: (_, i) {
                                      final item = _items[i];
                                      return Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.green[100],
                                            child: Text('${i + 1}'),
                                          ),
                                          title: Text(
                                            item['name'],
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          subtitle: Text('Qty: ${item['quantity']} • Expiry: ${(item['expiry'] as DateTime).toLocal().toString().split(' ')[0]}'),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            onPressed: () => _removeFromList(i),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          if (_items.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(top: BorderSide(color: Colors.grey[300]!)),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _loading ? null : _submit,
                                  icon: const Icon(Icons.check_circle),
                                  label: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text('Submit All (${_items.length})'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}