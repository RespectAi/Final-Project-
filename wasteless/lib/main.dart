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
import 'widgets/common.dart'; //

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // timezone setup
  tz.initializeTimeZones();
  final localTz = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTz));

  // notification plugin init
  final flutterLocal = FlutterLocalNotificationsPlugin();
  await flutterLocal.initialize(
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  // Initialize Supabase once
  await Supabase.initialize(
    url: 'https://doxhjonwexqsrksakpqo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
  );

  // create single instance of SupabaseService and pass the plugin in
  final supa = SupabaseService(flutterLocal);

  runApp(WasteLessApp(
    flutterLocal: flutterLocal,
    supa: supa,
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

  // Reusable gradient AppBar used throughout the app
  static PreferredSizeWidget gradientAppBar(String title) {
    return AppBar(
      title: Text(title),
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF0277BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2E7D32); // vegetable green
    return MaterialApp(
      title: 'WasteLess',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        textTheme: GoogleFonts.openSansTextTheme(),
        scaffoldBackgroundColor: Colors.grey[50],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        cardTheme: CardThemeData( // <-- FIXED: use CardTheme not CardThemeData
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          ),
        ),
      ),
      home: AuthGate(supa: supa),
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
      try {
        final expiry = DateTime.parse(item['expiry_date']);
        final days = (item['reminder_days_before'] as int?) ?? 0;
        final hours = (item['reminder_hours_before'] as int?) ?? 0;
        final notifyTime = expiry.subtract(Duration(days: days, hours: hours));
        if (notifyTime.isAfter(DateTime.now())) {
          // If you want to re-schedule notifications on app start, call a method in SupabaseService.
          // widget.supa.scheduleNotificationForItem(...);
        }
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:gradientAppBar('WasteLess Dashboard'),
      body: _pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              child: const Icon(Icons.add),
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
