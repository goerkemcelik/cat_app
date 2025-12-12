import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ble.dart';
import 'tracking_graph.dart';
import 'settings.dart';

const Color wisteriaColor = Color(0xFFC9A0DC);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadDarkModePreference();
  }

  // Load dark mode setting from storage
  Future<void> _loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _isDarkMode = isDark;
    });
  }

  // Save dark mode setting to storage
  Future<void> _saveDarkModePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C.A.T.',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: wisteriaColor, brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFCF8FF),
        textTheme: GoogleFonts.montserratTextTheme().copyWith(
          headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          bodyLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          bodySmall: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: wisteriaColor, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.montserratTextTheme().copyWith(
          headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          bodyLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          bodySmall: GoogleFonts.montserrat(fontWeight: FontWeight.w400),
          titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MyHomePage(
        title: 'C.A.T.',
        onDarkModeChanged: (isDark) {
          setState(() => _isDarkMode = isDark);
          _saveDarkModePreference(isDark);
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.onDarkModeChanged,
  });

  final String title;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with TickerProviderStateMixin {
  final BleService _ble = BleService(); // BLE connection service
  int _selectedIndex = 0; // Bottom nav bar index
  final List<Map<String, dynamic>> _history = []; // Measurement snapshots
  Timer? _countdownTimer; // Updates feed time countdown
  Timer? _snapshotTimer; // Takes measurements every 30s
  TimeOfDay _feedTime1 = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _feedTime2 = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadFeedTimes();
    _requestPermissionsAndConnect();
    
    // Snapshot timer: saves BLE value to history every 30 seconds
    _snapshotTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final val = _ble.value.value;
      setState(() {
        _history.add({'t': DateTime.now(), 'v': val});
        // Keep only last 2000 measurements
        if (_history.length > 2000) {
          _history.removeRange(0, _history.length - 2000);
        }
        _saveHistory();
      });
    });
    
    // Countdown timer: refreshes UI every minute for feed time display
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  // Load measurement history from storage
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('measurement_history');
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _history.clear();
        for (final item in jsonList) {
          _history.add({
            't': DateTime.parse(item['t'] as String),
            'v': item['v'] as int,
          });
        }
      } catch (e) {
        // ignore
        // print('Error loading history: $e');
      }
    }
  }

  // Load saved feed times from storage
  Future<void> _loadFeedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final time1Hour = prefs.getInt('feedTime1_hour');
    final time1Minute = prefs.getInt('feedTime1_minute');
    final time2Hour = prefs.getInt('feedTime2_hour');
    final time2Minute = prefs.getInt('feedTime2_minute');
    
    if (time1Hour != null && time1Minute != null) {
      setState(() {
        _feedTime1 = TimeOfDay(hour: time1Hour, minute: time1Minute);
      });
    }
    if (time2Hour != null && time2Minute != null) {
      setState(() {
        _feedTime2 = TimeOfDay(hour: time2Hour, minute: time2Minute);
      });
    }
  }

  // Save feed times to storage
  Future<void> _saveFeedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('feedTime1_hour', _feedTime1.hour);
    await prefs.setInt('feedTime1_minute', _feedTime1.minute);
    await prefs.setInt('feedTime2_hour', _feedTime2.hour);
    await prefs.setInt('feedTime2_minute', _feedTime2.minute);
  }

  // Save measurement history to storage
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _history.map((entry) {
      return {
        't': (entry['t'] as DateTime).toIso8601String(),
        'v': entry['v'] as int,
      };
    }).toList();
    await prefs.setString('measurement_history', jsonEncode(jsonList));
  }

  // Clear all measurement history
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('measurement_history');
    setState(() {
      _history.clear();
    });
  }

  // Request BLE permissions and connect to device
  Future<void> _requestPermissionsAndConnect() async {
    final status = await Future.wait<PermissionStatus>([
      Permission.bluetoothConnect.request(),
      Permission.bluetoothScan.request(),
      Permission.location.request(),
    ]);
    final allGranted = status.every((s) => s.isGranted);
    if (!allGranted) {
      _ble.status.value = 'Permissions denied';
      return;
    }

    await _ble.connect();
  }

  @override
  void dispose() {
    _ble.dispose();
    _countdownTimer?.cancel();
    _snapshotTimer?.cancel();
    super.dispose();
  }

  void _selectNavItem(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHome(context),
      TrackingGraphScreen(history: _history),
      SettingsScreen(
        onDarkModeChanged: widget.onDarkModeChanged,
        onClearHistory: _clearHistory,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectNavItem,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            children: [
              // Title
              // Title with custom font
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  textStyle: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                        color: wisteriaColor,
                        letterSpacing: 0.5,
                      ),
                ),
              ),
              const SizedBox(height: 32),

              // Füllstand Surface (color-based elevation)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Füllstand',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<int>(
                      valueListenable: _ble.value,
                      builder: (context, val, _) {
                        // New mapping: 0-2500 range
                        final percentage = ((val / 2500) * 100).clamp(0, 100).toStringAsFixed(1);
                        final progressValue = ((val / 2500) * 100).clamp(0, 100) / 100;
                        // Old mapping: 1641-1491 range (inverted)
                        // final percentage = (((1641 - val) / 150) * 100).clamp(0, 100).toStringAsFixed(1);
                        // final progressValue = (((1641 - val) / 150) * 100).clamp(0, 100) / 100;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$percentage%',
                              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: wisteriaColor,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progressValue,
                                minHeight: 10,
                                backgroundColor: wisteriaColor.withAlpha(60),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  wisteriaColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Futterzeit Surface
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Futterzeit',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTimePicker(
                          context,
                          _feedTime1,
                          (time) {
                            setState(() => _feedTime1 = time);
                            _saveFeedTimes();
                          },
                        ),
                        _buildTimePicker(
                          context,
                          _feedTime2,
                          (time) {
                            setState(() => _feedTime2 = time);
                            _saveFeedTimes();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Countdown to next feed
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _nextFeedCountdown(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Connection Surface
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20.0),
                child: ValueListenableBuilder<String>(
                  valueListenable: _ble.status,
                  builder: (context, status, _) {
                    final isConnected = status.toLowerCase().contains('connected');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Verbindung',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green.withAlpha(200) : Colors.orange.withAlpha(200),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _ble.disconnect();
                              if (!mounted) return;
                              await Future.delayed(const Duration(seconds: 1));
                              if (!mounted) return;
                              await _ble.connect();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Erneut verbinden'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: wisteriaColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Calculate time until next feeding
  String _nextFeedCountdown() {
    final now = DateTime.now();
    DateTime nextFor(TimeOfDay tod) {
      final candidate = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      if (candidate.isAfter(now)) return candidate;
      return candidate.add(const Duration(days: 1));
    }

    final a = nextFor(_feedTime1);
    final b = nextFor(_feedTime2);
    final next = a.isBefore(b) ? a : b;
    final diff = next.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return 'Nächste Futterzeit in: ${hours}h${minutes.toString().padLeft(2, '0')}min';
  }

  Widget _buildTimePicker(
    BuildContext context,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onTimeChanged,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) {
          onTimeChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: wisteriaColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: wisteriaColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}