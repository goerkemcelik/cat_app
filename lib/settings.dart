import 'package:flutter/material.dart';

/// Hauptfarbe der App (identisch mit main.dart)
const Color wisteriaColor = Color(0xFFC9A0DC);

/// Settings-Screen Widget
/// Ermöglicht Umschalten zwischen Dark/Light Mode und Löschen des Messverlaufs
class SettingsScreen extends StatefulWidget {
  /// Callback, der aufgerufen wird, wenn der Dark Mode geändert wird
  final ValueChanged<bool> onDarkModeChanged;
  
  /// Callback zum Löschen des gesamten Messverlaufs
  final VoidCallback onClearHistory;

  const SettingsScreen({
    super.key,
    required this.onDarkModeChanged,
    required this.onClearHistory,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Baut die Settings-UI mit zwei Sektionen: Erscheinungsbild und Daten
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
            // Sektion: Erscheinungsbild
            Text(
              'Erscheinungsbild',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            // Dark Mode Toggle
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
            const SizedBox(height: 24),
            // Sektion: Daten
            Text(
              'Daten',
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
                title: const Text('Verlauf zurücksetzen'),
                subtitle: const Text('Löscht alle gespeicherten Messwerte'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    // Bestätigungsdialog anzeigen
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Verlauf löschen?'),
                        content: const Text('Alle gespeicherten Messwerte werden dauerhaft gelöscht.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Abbrechen'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    // Wenn bestätigt, lösche Verlauf und zeige Snackbar
                    if (confirm == true) {
                      widget.onClearHistory();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verlauf wurde gelöscht')),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
