import 'package:flutter/material.dart';

const Color wisteriaColor = Color(0xFFC9A0DC);

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool> onDarkModeChanged;

  const SettingsScreen({super.key, required this.onDarkModeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Erscheinungsbild',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text('Dunkler Modus'),
                trailing: Switch(
                  value: Theme.of(context).brightness == Brightness.dark,
                  onChanged: (value) {
                    widget.onDarkModeChanged(value);
                  },
                  activeThumbColor: wisteriaColor,
                  activeTrackColor: wisteriaColor.withAlpha(120),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
