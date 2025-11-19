import 'package:flutter/material.dart';

class TrackingGraphScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const TrackingGraphScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  height: 260,
                  child: history.isEmpty
                      ? const Center(child: Text('No data yet'))
                      : CustomPaint(
                          painter: _LineChartPainter(history),
                          child: Container(),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? const Center(child: Text('No readings yet'))
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final idx = history.length - 1 - index;
                        final item = history[idx];
                        final t = item['t'] as DateTime;
                        final v = item['v'] as int;
                        return ListTile(
                          dense: true,
                          title: Text('$v mV'),
                          subtitle: Text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}'),
                        );
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> history;

  _LineChartPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.blueAccent;

    final bg = Paint()..color = Colors.grey.shade200;
    final padding = 24.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    // background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, bg);

    if (history.isEmpty) return;

    // extract values
    final values = history.map<int>((e) => e['v'] as int).toList();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = padding + (i / (values.length - 1)) * w;
      final y = padding + (1 - (values[i] - minV) / range) * h;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }

    // grid lines
    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final gy = padding + (i / 4) * h;
      canvas.drawLine(Offset(padding, gy), Offset(padding + w, gy), gridPaint);
    }

    // draw path
    canvas.drawPath(path, paint);

    // draw min/max labels
    final tpMax = TextPainter(
      text: TextSpan(text: maxV.toStringAsFixed(0), style: const TextStyle(color: Colors.black54, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMax.paint(canvas, Offset(2, padding - tpMax.height / 2));

    final tpMin = TextPainter(
      text: TextSpan(text: minV.toStringAsFixed(0), style: const TextStyle(color: Colors.black54, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMin.paint(canvas, Offset(2, padding + h - tpMin.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
