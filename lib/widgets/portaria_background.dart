import 'package:flutter/material.dart';

class PortariaBackground extends StatelessWidget {
  const PortariaBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PortariaPainter(),
      size: Size.infinite,
    );
  }
}

class _PortariaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0B1D38),
        const Color(0xFF102D4C),
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    final buildingPaint = Paint()..color = Colors.white24;
    final doorPaint = Paint()..color = Colors.white30;
    final windowPaint = Paint()..color = Colors.white10;
    final personPaint = Paint()..color = Colors.white70;

    final buildingWidth = size.width * 0.6;
    final buildingHeight = size.height * 0.35;
    final buildingLeft = size.width * 0.2;
    final buildingTop = size.height * 0.25;

    final buildingRect = Rect.fromLTWH(
      buildingLeft,
      buildingTop,
      buildingWidth,
      buildingHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(buildingRect, const Radius.circular(16)),
      buildingPaint,
    );

    final doorWidth = buildingWidth * 0.2;
    final doorHeight = buildingHeight * 0.45;
    final doorLeft = buildingLeft + buildingWidth * 0.4;
    final doorTop = buildingTop + buildingHeight * 0.45;
    final doorRect = Rect.fromLTWH(doorLeft, doorTop, doorWidth, doorHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(doorRect, const Radius.circular(8)),
      doorPaint,
    );

    final windowSize = Size(buildingWidth * 0.18, buildingHeight * 0.18);
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 2; j++) {
        final wx = buildingLeft + 0.1 * buildingWidth + i * (windowSize.width + 16);
        final wy = buildingTop + 0.12 * buildingHeight + j * (windowSize.height + 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(wx, wy, windowSize.width, windowSize.height),
            const Radius.circular(6),
          ),
          windowPaint,
        );
      }
    }

    final headRadius = 10.0;

    void drawPerson(double cx, double cy) {
      canvas.drawCircle(Offset(cx, cy), headRadius, personPaint);
      canvas.drawLine(
          Offset(cx, cy + headRadius), Offset(cx, cy + headRadius + 28), personPaint);
      canvas.drawLine(
          Offset(cx - 14, cy + headRadius + 12), Offset(cx + 14, cy + headRadius + 12), personPaint);
      canvas.drawLine(
          Offset(cx, cy + headRadius + 28), Offset(cx - 10, cy + headRadius + 44), personPaint);
      canvas.drawLine(
          Offset(cx, cy + headRadius + 28), Offset(cx + 10, cy + headRadius + 44), personPaint);
    }

    drawPerson(buildingLeft - 60, buildingTop + buildingHeight - 30);
    drawPerson(buildingLeft + buildingWidth + 60, buildingTop + buildingHeight - 30);

    final groundPaint = Paint()..color = Colors.white10..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, buildingTop + buildingHeight + 40),
      Offset(size.width, buildingTop + buildingHeight + 40),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
