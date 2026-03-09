import 'package:flutter/material.dart';
import '../services/collaborative_canvas_service.dart';

class CollaborativeCanvasPainter extends CustomPainter {
  final List<DrawingPoint> points;
  final String? currentUserId;
  final Color? highlightColor;

  CollaborativeCanvasPainter({
    required this.points,
    this.currentUserId,
    this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Group consecutive points by user and color
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      final timeDiff = next.timestamp - current.timestamp;

      // Draw line between consecutive points
      if (current.userId == next.userId && timeDiff < 1000) {
        // Within 1 second = same stroke
        final paint = Paint()
          ..color = CollaborativeCanvasService.hexToColor(current.color)
          ..strokeWidth = current.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

        // Add glow effect for current user
        if (current.userId == currentUserId && highlightColor != null) {
          final glowPaint = Paint()
            ..color = highlightColor!.withOpacity(0.3)
            ..strokeWidth = current.strokeWidth + 4
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

          canvas.drawLine(
            Offset(current.x, current.y),
            Offset(next.x, next.y),
            glowPaint,
          );
        }

        canvas.drawLine(
          Offset(current.x, current.y),
          Offset(next.x, next.y),
          paint,
        );
      }
    }

    // Draw dots for individual points
    for (var point in points) {
      final paint = Paint()
        ..color = CollaborativeCanvasService.hexToColor(point.color)
        ..strokeWidth = point.strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(
        Offset(point.x, point.y),
        point.strokeWidth / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CollaborativeCanvasPainter oldDelegate) {
    return points.length != oldDelegate.points.length ||
        highlightColor != oldDelegate.highlightColor;
  }
}
