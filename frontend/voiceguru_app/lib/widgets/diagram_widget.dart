import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';

/// Renders simple educational diagrams using CustomPainter based on [type].
class DiagramWidget extends StatelessWidget {
  const DiagramWidget({
    super.key,
    required this.type,
    required this.description,
  });

  final String type;
  final String description;

  void _showZoomableDiagram(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: kBackground,
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Interactive Diagram',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: kTextPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextPrimary,
                  ),
                ),
              ),
              Container(
                height: 350,
                color: Colors.white,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(60),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: 350,
                      child: CustomPaint(
                        painter: _DiagramPainter(type: type, description: description),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (type == 'none' || type.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showZoomableDiagram(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description label
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.zoom_out_map, size: 16, color: kGoogleBlue),
                ],
              ),
            ),
            // Diagram canvas
            SizedBox(
              width: double.infinity,
              height: 180,
              child: CustomPaint(
                painter: _DiagramPainter(type: type, description: description),
              ),
            ),
            // Caption
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                'Tap diagram to zoom and explore interactively',
                style: TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────â”€
//  Custom Painter
// ────────────────────────────────────────────────â”€
class _DiagramPainter extends CustomPainter {
  _DiagramPainter({required this.type, required this.description});

  final String type;
  final String description;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case 'ray_diagram':
        _drawRayDiagram(canvas, size);
        break;
      case 'food_chain':
        _drawFoodChain(canvas, size);
        break;
      case 'water_cycle':
        _drawWaterCycle(canvas, size);
        break;
      case 'number_line':
        _drawNumberLine(canvas, size);
        break;
      case 'geometric_shape':
        _drawGeometricShape(canvas, size);
        break;
      case 'human_body':
        _drawHumanBody(canvas, size);
        break;
      case 'solar_system':
        _drawSolarSystem(canvas, size);
        break;
      case 'circuit':
        _drawCircuit(canvas, size);
        break;
      case 'bar_chart':
        _drawBarChart(canvas, size);
        break;
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  // ─── Colors & helpers ───
  static const Color _blue = kGoogleBlue;
  static const Color _green = kGoogleGreen;
  static const Color _yellow = kGoogleYellow;
  static const Color _red = kGoogleRed;

  Paint get _bluePaint => Paint()
    ..color = _blue
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  Paint get _greenPaint => Paint()
    ..color = _green
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke;

  Paint get _fillBlue => Paint()
    ..color = _blue.withOpacity(0.15)
    ..style = PaintingStyle.fill;

  Paint get _fillGreen => Paint()
    ..color = _green.withOpacity(0.15)
    ..style = PaintingStyle.fill;

  void _drawLabel(Canvas canvas, String text, Offset position,
      {double fontSize = 10, Color color = kTextPrimary, bool center = true}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = center
        ? Offset(position.dx - tp.width / 2, position.dy - tp.height / 2)
        : position;
    tp.paint(canvas, offset);
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(from, to, paint);
    // Arrow head
    final angle = (to - from).direction;
    const headLength = 8.0;
    final p1 = to - Offset.fromDirection(angle - 0.4, headLength);
    final p2 = to - Offset.fromDirection(angle + 0.4, headLength);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;
  }

  // ─── Ray Diagram ───
  void _drawRayDiagram(Canvas canvas, Size size) {
    final paint = _bluePaint..strokeWidth = 2;
    final cy = size.height / 2;

    // Light source (circle)
    canvas.drawCircle(Offset(40, cy), 15, _fillBlue);
    canvas.drawCircle(Offset(40, cy), 15, paint);
    _drawLabel(canvas, 'Source', Offset(40, cy + 26));

    // Rays going to scattering point
    final scatterX = size.width * 0.5;
    _drawArrow(canvas, Offset(55, cy), Offset(scatterX - 10, cy), paint);

    // Scattering particles
    final scatter = Paint()
      ..color = _yellow
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final dx = scatterX + (i % 3 - 1) * 10.0;
      final dy = cy + (i ~/ 3 - 0.5) * 14;
      canvas.drawCircle(Offset(dx, dy), 4, scatter);
    }
    _drawLabel(canvas, 'Particles', Offset(scatterX, cy + 30));

    // Scattered rays
    final eyeX = size.width - 50.0;
    _drawArrow(canvas, Offset(scatterX + 15, cy - 8),
        Offset(eyeX - 10, cy - 30), paint..color = _green);
    _drawArrow(canvas, Offset(scatterX + 15, cy + 8),
        Offset(eyeX - 10, cy + 30), paint..color = _green);
    _drawArrow(canvas, Offset(scatterX + 15, cy),
        Offset(eyeX - 10, cy), paint..color = _blue);

    // Observer eye
    canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeX, cy), width: 22, height: 14),
        _bluePaint);
    canvas.drawCircle(Offset(eyeX, cy), 4, Paint()..color = _blue);
    _drawLabel(canvas, 'Observer', Offset(eyeX, cy + 20));
  }

  // ─── Food Chain ───
  void _drawFoodChain(Canvas canvas, Size size) {
    final labels = ['â˜€ï¸ Sun', '🌱 Plant', 'ðŸ° Herbivore', 'ðŸ¦ Carnivore'];
    final boxW = (size.width - 60) / 4;
    const boxH = 40.0;
    final cy = size.height / 2;

    for (var i = 0; i < labels.length; i++) {
      final x = 15 + i * (boxW + 10);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - boxH / 2, boxW, boxH),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, i.isEven ? _fillBlue : _fillGreen);
      canvas.drawRRect(rect, i.isEven ? _bluePaint : _greenPaint);
      _drawLabel(canvas, labels[i], Offset(x + boxW / 2, cy), fontSize: 11);

      if (i < labels.length - 1) {
        _drawArrow(
          canvas,
          Offset(x + boxW + 2, cy),
          Offset(x + boxW + 8, cy),
          Paint()
            ..color = kTextSecondary
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  // ─── Water Cycle ───
  void _drawWaterCycle(Canvas canvas, Size size) {
    final paint = _bluePaint..strokeWidth = 2;

    // Water body
    final waterRect = Rect.fromLTWH(20, size.height - 40, size.width - 40, 25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(6)),
      Paint()..color = _blue.withOpacity(0.2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(waterRect, const Radius.circular(6)),
      paint,
    );
    _drawLabel(canvas, 'Water', Offset(size.width / 2, size.height - 28));

    // Evaporation arrows (up)
    final evapPaint = Paint()..color = _blue..strokeWidth = 2..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final x = size.width * 0.25 + i * size.width * 0.2;
      _drawArrow(canvas, Offset(x, size.height - 48), Offset(x, 60), evapPaint);
    }
    _drawLabel(canvas, 'Evaporation ↑', Offset(size.width * 0.25, size.height - 60),
        fontSize: 9, color: _blue);

    // Cloud
    final cloudPaint = Paint()..color = Colors.grey.shade300..style = PaintingStyle.fill;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width / 2, 40), width: 100, height: 35),
        cloudPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width / 2 - 30, 38), width: 50, height: 28),
        cloudPaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(size.width / 2 + 30, 38), width: 50, height: 28),
        cloudPaint);
    _drawLabel(canvas, 'Cloud', Offset(size.width / 2, 40));

    // Rain arrows (down)
    final rainPaint = Paint()..color = _green..strokeWidth = 2..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final x = size.width * 0.55 + i * 20;
      _drawArrow(canvas, Offset(x, 58), Offset(x, size.height - 48), rainPaint);
    }
    _drawLabel(canvas, '↓ Rain', Offset(size.width * 0.7, 70),
        fontSize: 9, color: _green);
  }

  // ─── Number Line ───
  void _drawNumberLine(Canvas canvas, Size size) {
    final paint = _bluePaint..strokeWidth = 2;
    final cy = size.height / 2;
    const margin = 30.0;

    // Main line
    canvas.drawLine(Offset(margin, cy), Offset(size.width - margin, cy), paint);

    // Ticks and numbers
    final tickCount = 11;
    final span = size.width - margin * 2;
    for (var i = 0; i < tickCount; i++) {
      final x = margin + (span / (tickCount - 1)) * i;
      canvas.drawLine(Offset(x, cy - 8), Offset(x, cy + 8), paint);
      _drawLabel(canvas, '$i', Offset(x, cy + 20), fontSize: 10);
    }

    // Highlighted point at 5
    final highlightX = margin + span / 2;
    canvas.drawCircle(Offset(highlightX, cy), 7,
        Paint()..color = _red..style = PaintingStyle.fill);
    _drawLabel(canvas, '▲', Offset(highlightX, cy - 20),
        fontSize: 12, color: _red);
  }

  // ─── Geometric Shape ───
  void _drawGeometricShape(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final descLower = description.toLowerCase();

    if (descLower.contains('circle')) {
      canvas.drawCircle(Offset(cx, cy), 50, _fillBlue);
      canvas.drawCircle(Offset(cx, cy), 50, _bluePaint..strokeWidth = 2.5);
      // Radius line
      canvas.drawLine(Offset(cx, cy), Offset(cx + 50, cy),
          Paint()..color = _red..strokeWidth = 1.5);
      _drawLabel(canvas, 'r', Offset(cx + 25, cy - 10), color: _red);
    } else if (descLower.contains('rectangle') || descLower.contains('square')) {
      final rect = Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 70);
      canvas.drawRect(rect, _fillGreen);
      canvas.drawRect(rect, _greenPaint..strokeWidth = 2.5);
      _drawLabel(canvas, 'l', Offset(cx, cy + 45), color: _blue);
      _drawLabel(canvas, 'w', Offset(cx + 70, cy), color: _blue);
    } else {
      // Default: triangle
      final path = Path()
        ..moveTo(cx, cy - 55)
        ..lineTo(cx - 60, cy + 40)
        ..lineTo(cx + 60, cy + 40)
        ..close();
      canvas.drawPath(path, _fillBlue);
      canvas.drawPath(path, _bluePaint..strokeWidth = 2.5);
      _drawLabel(canvas, 'A', Offset(cx, cy - 65), color: _blue);
      _drawLabel(canvas, 'B', Offset(cx - 70, cy + 48), color: _blue);
      _drawLabel(canvas, 'C', Offset(cx + 70, cy + 48), color: _blue);
    }
  }

  // ─── Human Body ───
  void _drawHumanBody(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = _bluePaint..strokeWidth = 2;

    // Head
    canvas.drawCircle(Offset(cx, 30), 16, paint);
    // Body
    canvas.drawLine(Offset(cx, 46), Offset(cx, 110), paint);
    // Arms
    canvas.drawLine(Offset(cx, 60), Offset(cx - 35, 85), paint);
    canvas.drawLine(Offset(cx, 60), Offset(cx + 35, 85), paint);
    // Legs
    canvas.drawLine(Offset(cx, 110), Offset(cx - 25, 155), paint);
    canvas.drawLine(Offset(cx, 110), Offset(cx + 25, 155), paint);

    // Labeled arrows
    final arrowPaint = Paint()..color = _green..strokeWidth = 1.5..style = PaintingStyle.stroke;
    // Heart label
    _drawArrow(canvas, Offset(cx + 50, 70), Offset(cx + 5, 70), arrowPaint);
    _drawLabel(canvas, 'Heart', Offset(cx + 70, 70), fontSize: 9, color: _green, center: false);

    // Brain label
    _drawArrow(canvas, Offset(cx - 50, 25), Offset(cx - 17, 28), arrowPaint);
    _drawLabel(canvas, 'Brain', Offset(cx - 80, 25), fontSize: 9, color: _green, center: false);

    // Stomach label
    _drawArrow(canvas, Offset(cx + 50, 95), Offset(cx + 5, 95), arrowPaint);
    _drawLabel(canvas, 'Stomach', Offset(cx + 55, 95), fontSize: 9, color: _green, center: false);
  }

  // ─── Solar System ───
  void _drawSolarSystem(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final orbitPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Sun
    canvas.drawCircle(Offset(cx, cy), 12,
        Paint()..color = _yellow..style = PaintingStyle.fill);
    _drawLabel(canvas, 'Sun', Offset(cx, cy + 20), fontSize: 8, color: _yellow);

    // Planets
    const planets = ['Me', 'Ve', 'Ea', 'Ma', 'Ju', 'Sa'];
    final colors = [Colors.grey, _yellow, _blue, _red, Colors.orange, _green];
    for (var i = 0; i < planets.length; i++) {
      final radius = 28.0 + i * 14;
      canvas.drawCircle(Offset(cx, cy), radius, orbitPaint);

      final angle = -pi / 4 + i * 0.9;
      final px = cx + radius * cos(angle);
      final py = cy + radius * sin(angle);
      canvas.drawCircle(
          Offset(px, py), 4, Paint()..color = colors[i]..style = PaintingStyle.fill);
      _drawLabel(canvas, planets[i], Offset(px, py - 10), fontSize: 7, color: colors[i]);
    }
  }

  // ─── Circuit ───
  void _drawCircuit(Canvas canvas, Size size) {
    final paint = _bluePaint..strokeWidth = 2;
    const m = 30.0;

    // Rectangle circuit path
    final rect = Rect.fromLTRB(m, 30, size.width - m, size.height - 20);
    canvas.drawRect(rect, paint);

    // Battery (top-left)
    final batX = m + 40;
    canvas.drawLine(Offset(batX, 30), Offset(batX, 15), paint..strokeWidth = 3);
    canvas.drawLine(Offset(batX + 12, 30), Offset(batX + 12, 20), paint..strokeWidth = 1.5);
    _drawLabel(canvas, 'Battery', Offset(batX + 6, 8), fontSize: 9);
    paint.strokeWidth = 2;

    // Resistor (top-right) - zigzag
    final resX = size.width - m - 80;
    final path = Path()..moveTo(resX, 30);
    for (var i = 0; i < 4; i++) {
      path.lineTo(resX + 10 + i * 15, i.isEven ? 18 : 42);
    }
    path.lineTo(resX + 70, 30);
    canvas.drawPath(path, paint);
    _drawLabel(canvas, 'Resistor', Offset(resX + 35, 50), fontSize: 9);

    // Bulb (bottom)
    final bulbX = size.width / 2;
    final bulbY = size.height - 20.0;
    canvas.drawCircle(Offset(bulbX, bulbY), 12, paint);
    canvas.drawLine(Offset(bulbX - 6, bulbY + 6), Offset(bulbX + 6, bulbY - 6), paint);
    _drawLabel(canvas, 'Bulb', Offset(bulbX, bulbY + 20), fontSize: 9);

    // Switch (left side)
    final swY = size.height / 2;
    canvas.drawCircle(Offset(m, swY), 4, paint);
    canvas.drawLine(Offset(m, swY), Offset(m + 20, swY - 15), paint);
    _drawLabel(canvas, 'Switch', Offset(m + 25, swY - 5), fontSize: 9, center: false);
  }

  // ─── Bar Chart ───
  void _drawBarChart(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final axisPaint = Paint()..color = kTextSecondary..strokeWidth = 1.5;
    const m = 40.0;
    final chartH = size.height - 30;

    // Axes
    canvas.drawLine(Offset(m, 10), Offset(m, chartH), axisPaint);
    canvas.drawLine(Offset(m, chartH), Offset(size.width - 10, chartH), axisPaint);

    // Bars
    final colors = [_blue, _green, _yellow, _red, _blue.withOpacity(0.7)];
    final labels = ['A', 'B', 'C', 'D', 'E'];
    final values = [0.7, 0.5, 0.9, 0.3, 0.6];
    final barW = (size.width - m - 30) / labels.length - 8;

    for (var i = 0; i < labels.length; i++) {
      final x = m + 10 + i * (barW + 8);
      final barH = (chartH - 20) * values[i];
      final rect = Rect.fromLTWH(x, chartH - barH, barW, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint..color = colors[i],
      );
      _drawLabel(canvas, labels[i], Offset(x + barW / 2, chartH + 10), fontSize: 9);
    }
  }
}

