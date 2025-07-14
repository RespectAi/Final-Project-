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

