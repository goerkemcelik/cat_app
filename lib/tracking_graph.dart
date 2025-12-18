import 'package:flutter/material.dart';

/// Hauptfarbe der App (identisch mit main.dart)
const Color wisteriaColor = Color(0xFFC9A0DC);

/// Tracking-Screen Widget
/// Zeigt einen Linien-Graph der letzten 10 Minuten und eine Tabelle aller Messwerte
class TrackingGraphScreen extends StatefulWidget {
  /// Messwertverlauf als Liste von Maps mit Zeitstempel 't' und Wert 'v'
  final List<Map<String, dynamic>> history;

  const TrackingGraphScreen({super.key, required this.history});

  @override
  State<TrackingGraphScreen> createState() => _TrackingGraphScreenState();
}

class _TrackingGraphScreenState extends State<TrackingGraphScreen> {
  /// Baut die Tracking-UI mit Graph oben und Datentabelle unten
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Graph-Container: Zeigt die letzten 10 Minuten als Linien-Chart
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                height: 260,
                child: widget.history.isEmpty
                    ? const Center(child: Text('Noch keine Daten'))
                    : CustomPaint(
                        // Verwendet eigenen Painter für Graph-Darstellung
                        painter: _LineChartPainter(widget.history, context),
                        child: Container(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Datentabelle: Zeigt alle Messungen in tabellarischer Form
            Expanded(
              child: widget.history.isEmpty
                  ? const Center(child: Text('Noch keine Messwerte'))
                  : _buildDataTable(),
            )
          ],
        ),
      ),
    );
  }

  /// Erstellt eine scrollbare Datentabelle mit allen Messwerten
  /// Zeigt Zeit (HH:MM:SS) und Füllstand in Prozent
  Widget _buildDataTable() {
    final filtered = widget.history;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text('Zeit', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
              DataColumn(label: Text('Füllstand', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
            ],
            // Zeigt Einträge in umgekehrter Reihenfolge (neueste zuerst)
            rows: filtered.reversed.map((entry) {
              final t = entry['t'] as DateTime;
              final v = entry['v'] as int;
              // Konvertierung: Potentiometer-Rohwert -> Prozent
              final percentage = ((v / 2500) * 100).clamp(0, 100).toStringAsFixed(1);
              // Altes Mapping für Wägezelle (auskommentiert):
              // final percentage = (((1641 - v) / 15) * 100).clamp(0, 100).toStringAsFixed(1);
              final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
              return DataRow(cells: [
                DataCell(Text(timeStr)),
                DataCell(Text('$percentage%')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

/// Custom Painter für das Zeichnen des Linien-Diagramms
/// Zeigt die letzten 10 Minuten des Messwertverlaufs mit Grid und Achsenbeschriftungen
class _LineChartPainter extends CustomPainter {
  /// Messwertverlauf
  final List<Map<String, dynamic>> history;
  
  /// BuildContext für Theme-Zugriff (Dark/Light Mode)
  final BuildContext context;

  _LineChartPainter(this.history, this.context);

  /// Zeichnet das Linien-Diagramm auf den Canvas
  @override
  void paint(Canvas canvas, Size size) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Linienstil für den Graph
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = wisteriaColor;

    // Hintergrundfarbe (abhängig vom Theme)
    final bg = Paint()..color = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    // Padding für Achsenbeschriftungen
    final padding = 40.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    canvas.drawRRect(rect, bg);

    if (history.isEmpty) return;

    final now = DateTime.now();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10));

    // Filtert Daten: Nur die letzten 10 Minuten werden angezeigt
    final recentHistory = history.where((entry) {
      final t = entry['t'] as DateTime;
      return t.isAfter(tenMinutesAgo) && t.isBefore(now.add(const Duration(seconds: 1)));
    }).toList();

    if (recentHistory.isEmpty) return;

    // Reduziert Datenpunkte auf einen pro 30-Sekunden-Intervall
    // Verhindert Überlappung bei vielen Datenpunkten
    final Map<int, Map<String, dynamic>> bucketMap = {};
    for (final entry in recentHistory) {
      final t = entry['t'] as DateTime;
      final totalSeconds = t.difference(tenMinutesAgo).inSeconds;
      final bucket = (totalSeconds ~/ 30);
      // Behält nur den neuesten Wert pro Bucket
      if (!bucketMap.containsKey(bucket) || t.isAfter(bucketMap[bucket]!['t'] as DateTime)) {
        bucketMap[bucket] = entry;
      }
    }
    
    // Sortiert die gefilterten Datenpunkte chronologisch
    final filtered30SecHistory = bucketMap.values.toList()
      ..sort((a, b) => (a['t'] as DateTime).compareTo(b['t'] as DateTime));

    // Konvertiert Rohwerte in Prozent und speichert Zeitstempel
    final values = <double>[];
    final times = <DateTime>[];
    
    for (final entry in filtered30SecHistory) {
      final t = entry['t'] as DateTime;
      final v = entry['v'] as int;
      // Mapping: Potentiometer (0-2500) -> Prozent (0-100)
      final percentage = ((v / 2500) * 100).clamp(0, 100).toDouble();
      // Altes Mapping für Wägezelle (auskommentiert):
      // final percentage = (((1641 - v) / 15) * 100).clamp(0, 100).toDouble();
      values.add(percentage);
      times.add(t);
    }

    const minY = 0.0;
    const maxY = 100.0;

    const timeRangeSeconds = 600.0; // 10 Minuten in Sekunden

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    // Zeichnet horizontale Gitterlinien bei 0%, 25%, 50%, 75%, 100%
    for (int pct = 0; pct <= 100; pct += 25) {
      final yNorm = (pct - minY) / (maxY - minY);
      final gy = padding + (1 - yNorm) * h;
      canvas.drawLine(Offset(padding, gy), Offset(padding + w, gy), gridPaint);
    }

    // Zeichnet vertikale Gitterlinien bei -10, -8, -6, -4, -2, 0 Minuten
    for (int minAgo = -10; minAgo <= 0; minAgo += 2) {
      final secAgo = minAgo * 60.0;
      final xNorm = (secAgo + 600) / timeRangeSeconds;
      final gx = padding + xNorm * w;
      canvas.drawLine(Offset(gx, padding), Offset(gx, padding + h), gridPaint);
    }

    // Zeichnet die Datenpunkte als durchgehende Linie
    final path = Path();
    bool firstPoint = true;
    for (int i = 0; i < values.length; i++) {
      final t = times[i];
      final secAgo = t.difference(now).inSeconds.toDouble();
      // Normalisierung auf X-Achse (0 = 10 Min her, 1 = jetzt)
      final xNorm = (secAgo + 600) / timeRangeSeconds;
      // Normalisierung auf Y-Achse (0 = 0%, 1 = 100%)
      final yNorm = (values[i] - minY) / (maxY - minY);
      
      final x = padding + xNorm * w;
      final y = padding + (1 - yNorm) * h; // Invertiert für Canvas-Koordinaten

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Y-Achsen-Beschriftung: Prozent-Werte (0%, 25%, 50%, 75%, 100%)
    final labelColor = isDarkMode ? Colors.white : Colors.black54;
    for (int pct = 0; pct <= 100; pct += 25) {
      final yNorm = (pct - minY) / (maxY - minY);
      final gy = padding + (1 - yNorm) * h;
      final tp = TextPainter(
        text: TextSpan(text: '$pct%', style: TextStyle(color: labelColor, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, gy - tp.height / 2));
    }

    // X-Achsen-Beschriftung: Zeit relativ zu jetzt (-10, -8, -6, -4, -2, 0 Minuten)
    for (int minAgo = -10; minAgo <= 0; minAgo += 2) {
      final secAgo = minAgo * 60.0;
      final xNorm = (secAgo + 600) / timeRangeSeconds;
      final gx = padding + xNorm * w;
      final label = minAgo == 0 ? '0' : '$minAgo';
      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: labelColor, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(gx - tp.width / 2, padding + h + 8));
    }
    
    // X-Achsen-Untertitel: "Last 10 Minutes"
    final subtitleTp = TextPainter(
      text: TextSpan(text: 'Last 10 Minutes', style: TextStyle(color: labelColor, fontSize: 10, fontStyle: FontStyle.italic)),
      textDirection: TextDirection.ltr,
    )..layout();
    subtitleTp.paint(canvas, Offset((size.width - subtitleTp.width) / 2, padding + h + 24));
  }

  /// Bestimmt, ob der Graph neu gezeichnet werden muss
  /// Neu-Zeichnung erfolgt bei Änderung der Anzahl oder des letzten Zeitstempels
  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.history.length != history.length ||
           (history.isNotEmpty && oldDelegate.history.isNotEmpty &&
            (history.last['t'] as DateTime) != (oldDelegate.history.last['t'] as DateTime));
  }
}
