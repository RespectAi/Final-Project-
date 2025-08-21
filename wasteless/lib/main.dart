// lib/main.dart
import 'dart:async';
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
import 'services/supabase_service.dart';
import 'widgets/common.dart';
import 'pages/categories_page.dart';

GlobalKey navigatorKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // timezone setup // CHANGED: initialize from latest_all (works the same if you keep latest) 
  tz.initializeTimeZones(); // CHANGED
  final localTz = await FlutterNativeTimezone.getLocalTimezone(); 
  tz.setLocalLocation(tz.getLocation(localTz));

  // notification plugin init
  final flutterLocal = FlutterLocalNotificationsPlugin();

  // NEW: Tap callback so we see when a notification is tapped
  void onDidReceiveNotificationResponse(NotificationResponse response) {
    // You can parse response.payload to navigate to a specific item if you set a payload when scheduling.
    debugPrint('Notification tapped. Payload: ${response.payload}');
  }

  await flutterLocal.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
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

  // AppBar helper is centralized in widgets/common.dart as gradientAppBar

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2E7D32);
    return MaterialApp(
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

  Future _initializeNotifications() async {
    await _requestNotificationPermission();
    await _rescheduleAll();
  }

  // NEW: Keep a subscription so we can re-schedule when inventory changes
  StreamSubscription? _invChangedSub;

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
    super.initState(); _initializeNotifications(); // NEW

    // NEW: Whenever inventory changes, cancel all and re-schedule current items.
    // This fixes "ghost" notifications after deletes/log/donate.
   _invChangedSub = widget.supa.onInventoryChanged.listen((_) {
    _rescheduleAll(); // NEW
    });
  }
   
   // ADDED: New method to handle notification permission requests.
  Future<void> _requestNotificationPermission() async { 
    final notificationPlugin = FlutterLocalNotificationsPlugin();
    _rescheduleAll();

    // Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    notificationPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestPermission(); // FIX: v12 uses requestPermission()

    // iOS
    final IOSFlutterLocalNotificationsPlugin? iOSImplementation =
    notificationPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await iOSImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
     );
  }
  
  Future<void> _rescheduleAll() async {
    // FIX: v12 uses androidAllowWhileIdle; no androidScheduleMode here. // Also: one-shot (no matchDateTimeComponents) and payload included for taps.
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      await plugin.cancelAll(); // NEW: avoid duplicates and remove "ghosts"
    } catch (e) {
      debugPrint('Error cancelling existing notifications: $e');
    }
    final items = await widget.supa.fetchInventory();
for (var item in items) {
  try {
    final String itemId = item['id'] as String;
    final String name = item['name'] as String;
    final expiry = DateTime.parse(item['expiry_date'] as String);
    final days = (item['reminder_days_before'] as int?) ?? 0;
    final hours = (item['reminder_hours_before'] as int?) ?? 0;

    final notifyTime = expiry.subtract(Duration(days: days, hours: hours));
    if (notifyTime.isAfter(DateTime.now())) {
      await plugin.zonedSchedule(
        itemId.hashCode, // CHANGED: matches service scheduling to keep IDs consistent
        'Expiry Reminder',
        '$name expires on ${expiry.toLocal()}',
        tz.TZDateTime.from(notifyTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'expiry_channel',
            'Expiry Alerts',
            channelDescription: 'Reminders for inventory expiry',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true, // FIX: v12 param
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // No matchDateTimeComponents => one-shot (FIX for unintended repeats)
        payload: itemId, // NEW: use itemId for potential deep linking
      );
    }
  } catch (e) {
    debugPrint('Error scheduling notification for item ${item['id']}: $e'); // NEW
  }
}
  }

  @override
  void dispose() {
    _invChangedSub?.cancel();
    super.dispose();
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
