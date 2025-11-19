import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble.dart';
import 'tracking_graph.dart';
import 'settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C.A.T.',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'C.A.T.'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BleService _ble = BleService();
  int _selectedIndex = 0;
  final List<Map<String, dynamic>> _history = [];
  late VoidCallback _valueListener;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_selectedIndex) {
      case 1:
        body = TrackingGraphScreen(history: _history);
        break;
      case 2:
        body = const SettingsScreen();
        break;
      default:
        body = _buildHome(context);
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade600,
            Colors.deepPurple.shade900,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _ble.value,
                    builder: (context, val, _) {
                      final percentage = ((val / 2528) * 100).toStringAsFixed(1);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$percentage%',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 250,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: val / 2528,
                                minHeight: 12,
                                backgroundColor: Color.fromRGBO(255, 255, 255, 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.purpleAccent.shade100,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$val mV',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white70,
                                ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ValueListenableBuilder<String>(
                valueListenable: _ble.status,
                builder: (context, s, _) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(255, 255, 255, 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    'Status: $s',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}