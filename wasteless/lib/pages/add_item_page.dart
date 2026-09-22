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

  // Fridge selection
  List<Map<String, dynamic>> _fridges = [];
  String? _selectedFridgeId;

  // Form state
  final TextEditingController _nameController = TextEditingController();
  DateTime _expiry = DateTime.now().add(const Duration(days: 7));
  int _quantity = 1;
  int _remindDays = 1;
  int _remindHours = 0;

  // Multi-item state
  final List<Map<String, dynamic>> _items = [];
  bool _isAddingMultiple = false;

  // Focus nodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();
  final FocusNode _remindDaysFocus = FocusNode();
  final FocusNode _remindHoursFocus = FocusNode();

  // Controllers for reminder fields
  final TextEditingController _remindDaysController = TextEditingController(text: '1');
  final TextEditingController _remindHoursController = TextEditingController(text: '0');

  bool _loading = false;
  List<Map<String, dynamic>> _categoriesCache = [];

  // Common food typo corrections (soft spellcheck)
  static const Map<String, String> _commonFoodCorrections = {
    'tomatos': 'Tomatoes',
    'tomatoe': 'Tomatoes',
    'tomato': 'Tomato',
    'potatos': 'Potatoes',
    'potatoe': 'Potatoes',
    'potato': 'Potato',
    'bannana': 'Banana',
    'bananna': 'Banana',
    'bannanas': 'Bananas',
    'banana': 'Banana',
    'bananas': 'Bananas',
    'chese': 'Cheese',
    'cheeze': 'Cheese',
    'bread': 'Bread',
    'breadd': 'Bread',
    'milke': 'Milk',
    'mlik': 'Milk',
    'yougurt': 'Yogurt',
    'yogert': 'Yogurt',
    'yoghurt': 'Yogurt',
    'egges': 'Eggs',
    'aple': 'Apple',
    'aples': 'Apples',
    'orange': 'Orange',
    'oragnes': 'Oranges',
    'chikcen': 'Chicken',
    'chiken': 'Chicken',
    'beef': 'Beef',
    'fsh': 'Fish',
    'fiish': 'Fish',
    'onoin': 'Onion',
    'onoins': 'Onions',
    'onions': 'Onions',
    'carot': 'Carrot',
    'carrots': 'Carrots',
    'lettuce': 'Lettuce',
    'letuce': 'Lettuce',
    'butter': 'Butter',
    'buter': 'Butter',
    'garlic': 'Garlic',
    'garilc': 'Garlic',
    'ginger': 'Ginger',
    'gingre': 'Ginger',
    'rice': 'Rice',
    'riice': 'Rice',
    'pasta': 'Pasta',
    'spaghetti': 'Spaghetti',
    'spagetti': 'Spaghetti',
    'cereal': 'Cereal',
    'cerial': 'Cereal',
    'flour': 'Flour',
    'suger': 'Sugar',
    'suggar': 'Sugar',
  };

  @override
  void initState() {
    super.initState();
    _allCats = widget.supa.fetchCategories();
    _loadCategories();
    _loadFridges();
  }

  Future<void> _loadCategories() async {
    _categoriesCache = await widget.supa.fetchCategories();
    if (mounted) setState(() {});
  }

  Future<void> _loadFridges() async {
    try {
      final fridges = await widget.supa.fetchConnectedFridges();
      if (mounted) {
        setState(() {
          _fridges = fridges;
          if (_fridges.isNotEmpty) {
            _selectedFridgeId = _fridges.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading fridges: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _quantityFocus.dispose();
    _remindDaysFocus.dispose();
    _remindHoursFocus.dispose();
    _remindDaysController.dispose();
    _remindHoursController.dispose();
    super.dispose();
  }

  /// Soft spellcheck: auto-corrects high confidence food typos, allows all traditional foods
  String _applySoftSpellcheck(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();
    if (_commonFoodCorrections.containsKey(lower)) {
      return _commonFoodCorrections[lower]!;
    }

    // Capitalize first letter of traditional / custom food name
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  /// Get the maximum allowed days from selected categories
  int? _getMaxAllowedDays() {
    if (_selectedCatIds.isEmpty) return null;
    
    int? maxDays;
    for (final catId in _selectedCatIds) {
      final cat = _categoriesCache.firstWhere(
        (c) => c['id'].toString() == catId,
        orElse: () => <String, dynamic>{},
      );
      final defaultDays = cat['default_expiry_days'] as int?;
      if (defaultDays != null) {
        if (maxDays == null || defaultDays > maxDays) {
          maxDays = defaultDays;
        }
      }
    }
    return maxDays;
  }

  /// Check if current reminder days exceed the allowed maximum
  bool _isReminderDaysExceeded() {
    final maxDays = _getMaxAllowedDays();
    if (maxDays == null) return false;
    return _remindDays > maxDays;
  }

  /// Get validation error message for reminder days
  String? _getReminderDaysError() {
    if (_selectedCatIds.isEmpty) {
      return 'Select a category first';
    }
    final maxDays = _getMaxAllowedDays();
    if (maxDays == null) {
      return null;
    }
    if (_remindDays > maxDays) {
      return 'Cannot exceed $maxDays day(s)';
    }
    return null;
  }

  /// Get validation error message for reminder hours
  String? _getHoursError() {
    if (_remindDays <= 0) return null;
    
    final maxHours = _remindDays * 24;
    if (_remindHours > maxHours) {
      return 'Max ${maxHours}h for ${_remindDays} day(s)';
    }
    return null;
  }

  void _addToList() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    if (_isReminderDaysExceeded()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder days cannot exceed ${_getMaxAllowedDays()} day(s) for selected categories')),
      );
      return;
    }

    if (_getHoursError() != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getHoursError()!)),
      );
      return;
    }

    _formKey.currentState!.save();

    final rawName = _nameController.text.trim();
    final correctedName = _applySoftSpellcheck(rawName);
    final wasTypoFixed = correctedName.toLowerCase() != rawName.toLowerCase();

    setState(() {
      _items.add({
        'name': correctedName,
        'originalName': rawName,
        'expiry': _expiry,
        'quantity': _quantity,
        'reminderDaysBefore': _remindDays,
        'reminderHoursBefore': _remindHours,
        'categoryIds': _selectedCatIds.toList(),
        'fridgeId': _selectedFridgeId,
      });

      // Reset input fields for next item
      _nameController.clear();
      _expiry = DateTime.now().add(const Duration(days: 7));
      _quantity = 1;
      _remindDays = 1;
      _remindHours = 0;
      _remindDaysController.text = '1';
      _remindHoursController.text = '0';
      _selectedCatIds.clear();
    });

    if (wasTypoFixed) {
      final addedIndex = _items.length - 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Corrected to "$correctedName"'),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.amberAccent,
            onPressed: () {
              if (mounted && addedIndex < _items.length) {
                setState(() {
                  _items[addedIndex]['name'] = rawName;
                });
              }
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      showCornerToast(context, message: 'Item added to list (${_items.length})');
    }
  }

  void _removeFromList(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (!_isAddingMultiple) {
      if (!_formKey.currentState!.validate()) return;

      if (_selectedCatIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one category')),
        );
        return;
      }

      if (_isReminderDaysExceeded()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder days cannot exceed ${_getMaxAllowedDays()} day(s) for selected categories')),
        );
        return;
      }

      if (_getHoursError() != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getHoursError()!)),
        );
        return;
      }

      _formKey.currentState!.save();

      final rawName = _nameController.text.trim();
      final correctedName = _applySoftSpellcheck(rawName);

      setState(() => _loading = true);

      try {
        await widget.supa.addItem(
          name: correctedName,
          expiry: _expiry,
          quantity: _quantity,
          reminderDaysBefore: _remindDays,
          reminderHoursBefore: _remindHours,
          categoryIds: _selectedCatIds.toList(),
          fridgeId: _selectedFridgeId,
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
      // Multi-item mode: submit all staged items
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one item to the list')),
        );
        return;
      }

      setState(() => _loading = true);

      try {
        await widget.supa.addMultipleItems(_items, _selectedFridgeId);

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
    final reminderDaysError = _getReminderDaysError();
    final isReminderDaysInvalid = reminderDaysError != null && _selectedCatIds.isNotEmpty;
    final hoursError = _getHoursError();
    final isReminderHoursInvalid = hoursError != null;
    final isReminderInvalid = isReminderDaysInvalid || isReminderHoursInvalid;

    return Scaffold(
      appBar: buildGradientAppBar(
        context,
        _isAddingMultiple ? 'Add Multiple Items' : 'Add Inventory Item',
        showBackIfCanPop: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 700;

          return Column(
            children: [
              // Mode toggle (Single vs Multiple)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Text('Mode:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: [
                          const ButtonSegment(value: false, label: Text('Single Item'), icon: Icon(Icons.add_circle_outline)),
                          ButtonSegment(
                            value: true,
                            label: Text(_items.isNotEmpty ? 'Multiple (${_items.length})' : 'Multiple Items'),
                            icon: const Icon(Icons.library_add),
                          ),
                        ],
                        selected: {_isAddingMultiple},
                        onSelectionChanged: (Set<bool> selection) {
                          setState(() {
                            _isAddingMultiple = selection.first;
                            // NOTE: We deliberately do NOT clear _items here so user progress is never lost!
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Responsive Layout
              Expanded(
                child: isSmall
                    ? _buildMobileFormAndReview(isReminderInvalid)
                    : _buildDesktopFormAndList(isReminderInvalid),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- Mobile Layout (Full-Width Form with Review Section) ----------
  Widget _buildMobileFormAndReview(bool isReminderInvalid) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFormFields(isReminderInvalid),

        // If in Multiple Items mode, show staged items cleanly below
        if (_isAddingMultiple) ...[
          const SizedBox(height: 24),
          _buildStagedItemsSection(),
        ],
      ],
    );
  }

  // ---------- Desktop Layout (Side-by-Side) ----------
  Widget _buildDesktopFormAndList(bool isReminderInvalid) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormFields(isReminderInvalid),
          ),
        ),
        if (_isAddingMultiple)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: _buildStagedItemsSection(),
            ),
          ),
      ],
    );
  }

  // ---------- Form Fields ----------
  Widget _buildFormFields(bool isReminderInvalid) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Fridge Selector
          if (_fridges.length > 1) ...[
            DropdownButtonFormField<String>(
              value: _selectedFridgeId,
              decoration: const InputDecoration(
                labelText: 'Target Fridge',
                prefixIcon: Icon(Icons.kitchen_outlined),
              ),
              items: _fridges.map((f) {
                return DropdownMenuItem<String>(
                  value: f['id']?.toString(),
                  child: Text(f['name'] as String? ?? 'Fridge'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedFridgeId = val),
            ),
            const SizedBox(height: 12),
          ] else if (_fridges.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.kitchen, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'Fridge: ${_fridges.first['name'] ?? 'Main Fridge'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Item name input
          TextFormField(
            controller: _nameController,
            focusNode: _nameFocus,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              prefixIcon: Icon(Icons.fastfood_outlined),
              hintText: 'e.g. Tomatoes, Milk, Bread, Jollof Rice',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_quantityFocus),
          ),
          const SizedBox(height: 12),

          // Quantity
          TextFormField(
            focusNode: _quantityFocus,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
            initialValue: '1',
            onSaved: (v) => _quantity = int.tryParse(v ?? '1') ?? 1,
            validator: (v) {
              if (v == null) return 'Required';
              final n = int.tryParse(v);
              if (n == null || n < 1) return 'Enter a positive number';
              return null;
            },
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
          const SizedBox(height: 16),

          // Categories section (With overflow-safe wrapping)
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
                    runSpacing: 8,
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
                              Image.network(url, width: 18, height: 18, errorBuilder: (_, __, ___) => const Icon(Icons.eco, size: 16))
                            else
                              const Icon(Icons.eco, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (defaultDays != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($defaultDays d)',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedCatIds.add(id);
                              if (defaultDays != null) {
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
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Reminders
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _remindDaysController,
                  focusNode: _remindDaysFocus,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Remind (days before)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    setState(() {
                      _remindDays = int.tryParse(v) ?? 1;
                    });
                  },
                  onSaved: (v) => _remindDays = int.tryParse(v ?? '1') ?? 1,
                  onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_remindHoursFocus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _remindHoursController,
                  focusNode: _remindHoursFocus,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Remind (hours)'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    setState(() {
                      _remindHours = int.tryParse(v) ?? 0;
                    });
                  },
                  onSaved: (v) => _remindHours = int.tryParse(v ?? '0') ?? 0,
                  onFieldSubmitted: (_) {
                    if (_isAddingMultiple && !isReminderInvalid) {
                      _addToList();
                    } else if (!isReminderInvalid) {
                      _submit();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expiry date selector
          Row(
            children: [
              Expanded(
                child: Text(
                  'Expiry: ${_expiry.toLocal().toIso8601String().split('T')[0]}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Change Date'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiry,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _expiry = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Form Action Buttons
          if (_isAddingMultiple)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isReminderInvalid ? null : _addToList,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add to List'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReminderInvalid ? Colors.grey : const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || isReminderInvalid) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReminderInvalid ? Colors.grey : const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator.adaptive(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Add Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Staged Items Section (Full Width, No Letter-by-Letter Squishing) ----------
  Widget _buildStagedItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.list_alt, size: 20, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text(
                'Staged Items (${_items.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (_items.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: const Icon(Icons.check, size: 16),
                  label: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                      : Text('Submit All (${_items.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B074),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ),

        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text(
                  'No items in list yet',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fill the form above and tap "Add to List"',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final item = _items[i];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFDEF7EC),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF046C4E)),
                    ),
                  ),
                  title: Text(
                    item['name'],
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Qty: ${item['quantity']} • Expiry: ${(item['expiry'] as DateTime).toLocal().toString().split(' ')[0]}\n'
                    'Remind: ${item['reminderDaysBefore']}d ${item['reminderHoursBefore']}h before',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _removeFromList(i),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}