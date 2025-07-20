// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'pages/add_item_page.dart';
import 'pages/auth_page.dart';
import 'pages/donation_page.dart';
import 'pages/inventory_list.dart';
import 'pages/waste_log_page.dart';
import 'services/supabase_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Timezone setup
  tz.initializeTimeZones();
  final localTz = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTz));

  // 2) Notification plugin init
  final flutterLocal = FlutterLocalNotificationsPlugin();
  await flutterLocal.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await Supabase.initialize(
    url: 'https://doxhjonwexqsrksakpqo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
  );
  // 3) Start app, passing plugin
  runApp(WasteLessApp(
   flutterLocal: flutterLocal,
   supa: SupabaseService(flutterLocal),
 ));
}

class WasteLessApp extends StatelessWidget {
  final FlutterLocalNotificationsPlugin flutterLocal;
  final SupabaseService supa;
  const WasteLessApp({
    Key? key,
    required this.flutterLocal,
   required this.supa,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasteLess',
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.openSansTextTheme(),
      ),
      home: AuthGate(supa: SupabaseService(flutterLocal)),
      routes: {
        AddItemPage.route: (_) => AddItemPage(supa: supa),
        WasteLogPage.route: (_) =>
            WasteLogPage(supa: supa),
        DonationPage.route: (_) =>
            DonationPage(supa: supa),
      },
    );
  }
}




class HomePage extends StatefulWidget {
  final SupabaseService supa;
  const HomePage({required this.supa, super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [];
  final GlobalKey<InventoryListState> _invKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      InventoryList(key: _invKey, supa: widget.supa),
      WasteLogPage(supa: widget.supa),
      DonationPage(supa: widget.supa),
    ]);
    _rescheduleAll();
  }

  Future<void> _rescheduleAll() async {
    final items = await widget.supa.fetchInventory();
    for (var item in items) {
      final expiry = DateTime.parse(item['expiry_date']);
      final days = item['reminder_days_before'] as int? ?? 0;
      final hours = item['reminder_hours_before'] as int? ?? 0;
      final notifyTime = expiry.subtract(Duration(days: days, hours: hours));
      if (notifyTime.isAfter(DateTime.now())) {
        // TODO: Call notification scheduling here, e.g. widget.supa.local.zonedSchedule(...)
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WasteLess Dashboard'),
        actions: [
          // Add actions if needed
        ],
      ),
      body: _pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: () {
                Navigator.pushNamed(context, AddItemPage.route).then((_) {
                  _invKey.currentState?.refresh();
                });
              },
            )
          : null,
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
