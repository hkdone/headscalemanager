import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class AnimatedEdgePainter extends EdgeRenderer {
  final Animation<double> animation;
  final BuchheimWalkerConfiguration configuration;

  AnimatedEdgePainter(this.configuration, this.animation);

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    var source = edge.source;
    var destination = edge.destination;

    var startPoint = getStartPoint(source);
    var endPoint = getEndPoint(destination);

    var x1 = startPoint.dx;
    var y1 = startPoint.dy;
    var x2 = endPoint.dx;
    var y2 = endPoint.dy;

    var path = Path();
    path.moveTo(x1, y1);
    path.lineTo(x2, y2);

    var edgePaint = edge.paint ?? paint;
    canvas.drawPath(path, edgePaint);

    // Animation part
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      if (metric.length == 0) continue;
      final offset = metric.length * animation.value;
      final length = 15.0; // The length of the pulse
      final extractedPath = metric.extractPath(offset, offset + length);

      final pulsePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = edgePaint.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);

      canvas.drawPath(extractedPath, pulsePaint);
    }
  }

  Offset getStartPoint(Node node) {
    switch (configuration.orientation) {
      case BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM:
        return Offset(node.x + node.width / 2, node.y + node.height);
      case BuchheimWalkerConfiguration.ORIENTATION_BOTTOM_TOP:
        return Offset(node.x + node.width / 2, node.y);
      case BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT:
        return Offset(node.x + node.width, node.y + node.height / 2);
      case BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT:
        return Offset(node.x, node.y + node.height / 2);
      default:
        return Offset(node.x + node.width / 2, node.y + node.height / 2);
    }
  }

  Offset getEndPoint(Node node) {
    switch (configuration.orientation) {
      case BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM:
        return Offset(node.x + node.width / 2, node.y);
      case BuchheimWalkerConfiguration.ORIENTATION_BOTTOM_TOP:
        return Offset(node.x + node.width / 2, node.y + node.height);
      case BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT:
        return Offset(node.x, node.y + node.height / 2);
      case BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT:
        return Offset(node.x + node.width, node.y + node.height / 2);
      default:
        return Offset(node.x + node.width / 2, node.y + node.height / 2);
    }
  }
}
