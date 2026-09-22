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
import 'package:flutter/foundation.dart';
import 'pages/categories_page.dart';
import 'pages/fridges_page.dart';
import 'pages/reset_password_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final flutterLocal = FlutterLocalNotificationsPlugin();

  if (!kIsWeb) {
    // timezone setup (mobile only)
    tz.initializeTimeZones();
    try {
      final localTz = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (e) {
      debugPrint('Timezone setup error: $e');
    }

    // notification plugin init (mobile only)
    await flutterLocal.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _requestNotificationPermissions(flutterLocal);
  }

  // Initialize Supabase safely (handles offline state and hot restarts)
  bool supabaseReady = false;
  try {
    await Supabase.initialize(
      url: 'https://doxhjonwexqsrksakpqo.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRveGhqb253ZXhxc3Jrc2FrcHFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzMDE5ODAsImV4cCI6MjA2Nzg3Nzk4MH0.YMUqqYHnkIT2tD8wlSJu3qePnLaXXPBZvYUmHf41RGc',
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase initialize error or already initialized: $e');
    try {
      final _ = Supabase.instance.client;
      supabaseReady = true;
    } catch (_) {
      supabaseReady = false;
    }
  }

  if (supabaseReady) {
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
  } else {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Connection Failed',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Could not connect to Supabase. Please verify your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => main(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/// Requests notification permission on platforms that require it. Android 13+
/// and iOS otherwise suppress notifications until the user grants this.
Future<void> _requestNotificationPermissions(
  FlutterLocalNotificationsPlugin notifications,
) async {
  try {
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestPermission();
    await notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } catch (error) {
    debugPrint('Notification permission request failed: $error');
  }
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
    _restoreSavedTabIndex();
  }

  Future<void> _restoreSavedTabIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('home_tab_index') ?? 0;
      if (mounted && savedIndex > 0 && savedIndex < _pages.length) {
        setState(() => _currentIndex = savedIndex);
      }
    } catch (_) {}
  }

  Future<void> _saveTabIndex(int idx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('home_tab_index', idx);
    } catch (_) {}
  }

  Future<void> _rescheduleAll() async {
    try {
      await widget.supa.rescheduleExpiryReminders();
    } catch (error) {
      debugPrint('Could not restore expiry reminders: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Only Dashboard has its own custom greeting header; other tabs use standard gradient app bar
      appBar: (_currentIndex == 0)
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
                _saveTabIndex(idx);
                setState(() => _currentIndex = idx);
                if (idx == 0) _dashKey.currentState?.refresh();
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
