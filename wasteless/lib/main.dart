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
import 'pages/dashboard_page.dart';
import 'pages/user_page.dart';
import 'pages/local_user_gate.dart';
import 'services/supabase_service.dart';
import 'widgets/common.dart';
import 'pages/categories_page.dart';
import 'pages/fridges_page.dart';
import 'pages/reset_password_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;

  if (event == AuthChangeEvent.passwordRecovery && session != null) {
    navigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
      );
    }
  });

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
    super. key,
    required this.flutterLocal,
    required this.supa,
  });

  // AppBar helper is centralized in widgets/common.dart as gradientAppBar

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2E7D32);
    return MaterialApp(
      navigatorKey: navigatorKey, // 👈 add this
      title: 'WasteLess',
      debugShowCheckedModeBanner: false,
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
        cardTheme: CardThemeData(
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
        CategoriesPage.route: (_) => CategoriesPage(supa: supa),
        FridgesPage.route: (_) => FridgesPage(supa: supa),
        UserPage.route: (_) => UserPage(supa: supa),
        '/local-user': (_) => LocalUserGate(supa: supa),
        '/reset-password': (_) => const ResetPasswordPage(),
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
  int _currentIndex = 0; // 0: Dashboard, 1: Inventory, 2: Waste, 3: Donate
  final GlobalKey<InventoryListState> _invKey = GlobalKey();
  final GlobalKey<WasteLogPageState> _wasteKey = GlobalKey();
  final GlobalKey<DonationPageState> _donKey = GlobalKey();
  final GlobalKey<DashboardPageState> _dashKey = GlobalKey();

  late final List<Widget> _pages = [
    DashboardPage(
      key: _dashKey,
      supa: widget.supa,
      onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
    ), // 0
    InventoryList(key: _invKey, supa: widget.supa), // 1
    WasteLogPage(key: _wasteKey, supa: widget.supa), // 2
    DonationPage(key: _donKey, supa: widget.supa),   // 3
  ];

  static const _titles = ['WasteLess', 'Inventory', 'All Waste Logs', 'All Donations'];

  @override
  void initState() {
    super.initState();
    _rescheduleAll();
    // Load saved user context when app starts
    widget.supa.loadSavedUserContext();
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
          // widget.supa.scheduleNotificationForItem(...);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Dashboard now has its own header; keep headers for other tabs only
      appBar: _currentIndex == 0
          ? null
          : buildGradientAppBar(
              context,
              _titles[_currentIndex],
              showBackIfCanPop: false,
            ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              child: const Icon(Icons.add),
              onPressed: () {
                Navigator.pushNamed(context, AddItemPage.route).then((_) {
                  _invKey.currentState?.refresh();
                  _dashKey.currentState?.refresh();
                });
              },
            )
          : null,
      bottomNavigationBar: _currentIndex == 0
          ? const SizedBox.shrink()
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) {
                setState(() => _currentIndex = idx);
                if (idx == 1) _invKey.currentState?.refresh();
                if (idx == 2) _wasteKey.currentState?.refresh();
                if (idx == 3) _donKey.currentState?.refresh();
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.kitchen), label: 'Inventory'),
                NavigationDestination(icon: Icon(Icons.delete), label: 'Waste'),
                NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Donate'),
              ],
            ),
    );
  }
}
