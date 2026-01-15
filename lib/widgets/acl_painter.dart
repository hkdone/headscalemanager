import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';

class AclPainter extends CustomPainter {
  final Map<String, GlobalKey> nodeKeys;
  final List<Node> nodes;
  final Map<String, NodePermission> allPermissions;
  final BuildContext context;

  AclPainter({
    required this.nodeKeys,
    required this.nodes,
    required this.allPermissions,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintInternal = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;

    final paintExternal = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..strokeWidth = 2.5;

    final bodyRenderBox = context.findRenderObject() as RenderBox?;
    if (bodyRenderBox == null) return;

    for (var sourceNode in nodes) {
      final sourcePermissions = allPermissions[sourceNode.id];
      if (sourcePermissions == null) continue;

      for (var peer in sourcePermissions.allowedPeers) {
        final destNode = peer.node;

        // Draw line only once for a pair
        if (sourceNode.id.compareTo(destNode.id) > 0) continue;

        final sourceKey = nodeKeys[sourceNode.id];
        final destKey = nodeKeys[destNode.id];

        final sourceCtx = sourceKey?.currentContext;
        final destCtx = destKey?.currentContext;

        if (sourceCtx == null || destCtx == null) continue;

        final sourceRenderBox = sourceCtx.findRenderObject() as RenderBox;
        final destRenderBox = destCtx.findRenderObject() as RenderBox;

        // Get the global position of the widgets
        final sourceGlobalOffset = sourceRenderBox.localToGlobal(Offset.zero);
        final destGlobalOffset = destRenderBox.localToGlobal(Offset.zero);

        // Convert global position to local position within the CustomPaint canvas
        final sourceLocalOffset =
            bodyRenderBox.globalToLocal(sourceGlobalOffset);
        final destLocalOffset = bodyRenderBox.globalToLocal(destGlobalOffset);

        // Calculate the connection points (center-right of the widget)
        final sourcePoint = Offset(
          sourceLocalOffset.dx +
              sourceRenderBox.size.width -
              24, // Adjust to be on the side of the expansion tile
          sourceLocalOffset.dy + sourceRenderBox.size.height / 2,
        );
        final destPoint = Offset(
          destLocalOffset.dx + destRenderBox.size.width - 24,
          destLocalOffset.dy + destRenderBox.size.height / 2,
        );

        final isExternal = sourceNode.user != destNode.user;
        final paint = isExternal ? paintExternal : paintInternal;

        canvas.drawLine(sourcePoint, destPoint, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AclPainter oldDelegate) {
    // We want to repaint whenever the widget is rebuilt, which now happens
    // only on scroll end. This is more efficient.
    return true;
  }
}
