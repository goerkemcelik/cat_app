import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C.A.T.',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: wisteriaColor, brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFCF8FF),
        textTheme: GoogleFonts.montserratTextTheme().copyWith(
          headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          bodyLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          bodySmall: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: wisteriaColor, brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: GoogleFonts.montserratTextTheme().copyWith(
          headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          bodyLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          bodySmall: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
          titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w200),
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MyHomePage(
        title: 'C.A.T.',
        onDarkModeChanged: (isDark) => setState(() => _isDarkMode = isDark),
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
  final BleService _ble = BleService();
  int _selectedIndex = 0;
  final List<Map<String, dynamic>> _history = [];
  late VoidCallback _valueListener;
  Timer? _countdownTimer;
  TimeOfDay _feedTime1 = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _feedTime2 = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndConnect();
    _valueListener = () {
      final val = _ble.value.value;
      setState(() {
        _history.add({'t': DateTime.now(), 'v': val});
        if (_history.length > 2000) {
          _history.removeRange(0, _history.length - 2000);
        }
      });
    };
    _ble.value.addListener(_valueListener);
    // update countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

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
    _ble.value.removeListener(_valueListener);
    _ble.dispose();
    _countdownTimer?.cancel();
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
      SettingsScreen(onDarkModeChanged: widget.onDarkModeChanged),
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
                        final percentage = ((val / 2528) * 100).toStringAsFixed(1);
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
                                value: val / 2528,
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
                          (time) => setState(() => _feedTime1 = time),
                        ),
                        _buildTimePicker(
                          context,
                          _feedTime2,
                          (time) => setState(() => _feedTime2 = time),
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