import 'package:flutter/material.dart';

const Color wisteriaColor = Color(0xFFC9A0DC);

class TrackingGraphScreen extends StatefulWidget {
  final List<Map<String, dynamic>> history;

  const TrackingGraphScreen({super.key, required this.history});

  @override
  State<TrackingGraphScreen> createState() => _TrackingGraphScreenState();
}

class _TrackingGraphScreenState extends State<TrackingGraphScreen> {
  late DateTime _todayStart;
  
  @override
  void initState() {
    super.initState();
    _todayStart = DateTime.now();
    _todayStart = DateTime(_todayStart.year, _todayStart.month, _todayStart.day);
  }

  List<Map<String, dynamic>> _get5MinuteFilteredHistory() {
    if (widget.history.isEmpty) return [];
    final Map<String, Map<String, dynamic>> filtered = {};
    for (final entry in widget.history) {
      final t = entry['t'] as DateTime;
      final minutes = t.hour * 60 + t.minute;
      final bucket = (minutes ~/ 5) * 5;
      final key = '$bucket';
      if (!filtered.containsKey(key) || t.isAfter(filtered[key]!['t'] as DateTime)) {
        filtered[key] = entry;
      }
    }
    return filtered.values.toList()..sort((a, b) => (a['t'] as DateTime).compareTo(b['t'] as DateTime));
  }

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
                        painter: _LineChartPainter(widget.history, _todayStart),
                        child: Container(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
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

  Widget _buildDataTable() {
    final filtered = _get5MinuteFilteredHistory();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Zeit')),
            DataColumn(label: Text('Füllstand')),
          ],
          rows: filtered.reversed.map((entry) {
            final t = entry['t'] as DateTime;
            final v = entry['v'] as int;
            final percentage = ((v / 2528) * 100).toStringAsFixed(1);
            final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
            return DataRow(cells: [
              DataCell(Text(timeStr)),
              DataCell(Text('$percentage%')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;
  final DateTime todayStart;

  _LineChartPainter(this.history, this.todayStart);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = wisteriaColor;

    final bg = Paint()..color = Colors.grey.shade100;
    final padding = 40.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bg);

    if (history.isEmpty) return;

    // convert to percentages
    final values = <double>[];
    final times = <DateTime>[];
    
    for (final entry in history) {
      final t = entry['t'] as DateTime;
      final v = entry['v'] as int;
      final percentage = (v / 2528) * 100;
      values.add(percentage);
      times.add(t);
    }

    // fixed y-axis: 0-100%
    const minY = 0.0;
    const maxY = 100.0;

    // fixed x-axis: 00:00 - 23:59
    final secPerDay = 86400.0;

    // grid lines (vertical: every 4 hours, horizontal: every 25%)
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    // horizontal grid lines (0%, 25%, 50%, 75%, 100%)
    for (int pct = 0; pct <= 100; pct += 25) {
      final yNorm = (pct - minY) / (maxY - minY);
      final gy = padding + (1 - yNorm) * h;
      canvas.drawLine(Offset(padding, gy), Offset(padding + w, gy), gridPaint);
    }

    // vertical grid lines (every 4 hours)
    for (int hour = 0; hour <= 24; hour += 4) {
      final xNorm = hour / 24.0;
      final gx = padding + xNorm * w;
      canvas.drawLine(Offset(gx, padding), Offset(gx, padding + h), gridPaint);
    }

    // plot points
    final path = Path();
    bool firstPoint = true;
    for (int i = 0; i < values.length; i++) {
      final t = times[i];
      final secSinceToday = t.difference(todayStart).inSeconds;
      final xNorm = (secSinceToday % secPerDay) / secPerDay;
      final yNorm = (values[i] - minY) / (maxY - minY);
      
      final x = padding + xNorm * w;
      final y = padding + (1 - yNorm) * h;

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Y-axis labels (0%, 25%, 50%, 75%, 100%)
    for (int pct = 0; pct <= 100; pct += 25) {
      final yNorm = (pct - minY) / (maxY - minY);
      final gy = padding + (1 - yNorm) * h;
      final tp = TextPainter(
        text: TextSpan(text: '$pct%', style: const TextStyle(color: Colors.black54, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, gy - tp.height / 2));
    }

    // X-axis labels (00:00, 04:00, 08:00, ...)
    for (int hour = 0; hour <= 24; hour += 4) {
      final xNorm = hour / 24.0;
      final gx = padding + xNorm * w;
      final hourStr = '${hour.toString().padLeft(2, '0')}:00';
      final tp = TextPainter(
        text: TextSpan(text: hourStr, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(gx - tp.width / 2, padding + h + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
