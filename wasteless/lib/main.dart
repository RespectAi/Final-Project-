// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/supabase_service.dart';
import 'pages/inventory_list.dart';
import 'pages/add_item_page.dart';
import 'pages/waste_log_page.dart';
import 'pages/donation_page.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supa = await SupabaseService.init();
  runApp(WasteLessApp(supa));
}

class WasteLessApp extends StatelessWidget {
  final SupabaseService supa;
  const WasteLessApp(this.supa, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasteLess',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.openSansTextTheme(),
      ),
      home: HomePage(supa: supa),
      routes: {
        AddItemPage.route: (_) => AddItemPage(supa: supa),
        WasteLogPage.route: (_) => WasteLogPage(supa: supa),
        DonationPage.route: (_) => DonationPage(supa: supa),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  final SupabaseService supa;
  const HomePage({required this.supa, Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      InventoryList(supa: widget.supa),
      WasteLogPage(supa: widget.supa),
      DonationPage(supa: widget.supa),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WasteLess Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, AddItemPage.route),
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: 'Waste'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Donate'),
        ],
      ),
    );
  }
}

// lib/pages/inventory_list.dart

class InventoryList extends StatelessWidget {
  final SupabaseService supa;
  const InventoryList({required this.supa, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: supa.fetchInventory(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final items = snapshot.data as List<Map<String, dynamic>>;
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final daysLeft = DateTime.parse(item['expiry_date'])
                .difference(DateTime.now())
                .inDays;
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: ListTile(
                title: Text(item['name']),
                subtitle: Text('Expires in $daysLeft days'),
                trailing: PopupMenuButton(
                  onSelected: (val) {
                    if (val == 'waste') Navigator.pushNamed(context, WasteLogPage.route, arguments: item['id']);
                    if (val == 'donate') Navigator.pushNamed(context, DonationPage.route, arguments: item['id']);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'waste', child: Text('Log Waste')),
                    PopupMenuItem(value: 'donate', child: Text('Donate')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// lib/pages/add_item_page.dart

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

  _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    await widget.supa.addItem(name: _name, expiry: _expiry);
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
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Item Name'),
                onSaved: (v) => _name = v!.trim(),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text('Expiry Date: ${_expiry.toLocal().toIso8601String().split('T')[0]}'),
                  Spacer(),
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

// lib/pages/waste_log_page.dart

class WasteLogPage extends StatefulWidget {
  static const route = '/waste';
  final SupabaseService supa;
  const WasteLogPage({required this.supa, Key? key}) : super(key: key);

  @override
  _WasteLogPageState createState() => _WasteLogPageState();
}

class _WasteLogPageState extends State<WasteLogPage> {
  int _qty = 1;
  _submit(String itemId) async {
    await widget.supa.logWaste(itemId, _qty);
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

// lib/pages/donation_page.dart

class DonationPage extends StatefulWidget {
  static const route = '/donate';
  final SupabaseService supa;
  const DonationPage({required this.supa, Key? key}) : super(key: key);

  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final _controller = TextEditingController();
  _submit(String itemId) async {
    await widget.supa.offerDonation(itemId, _controller.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final itemId = ModalRoute.of(context)!.settings.arguments as String;
    return Scaffold(
      appBar: AppBar(title: Text('Offer Donation')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Recipient Info'),
            ),
            Spacer(),
            ElevatedButton(onPressed: () => _submit(itemId), child: Text('Donate'))
          ],
        ),
      ),
    );
  }
}
