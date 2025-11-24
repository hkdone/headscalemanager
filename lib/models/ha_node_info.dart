import 'package:headscalemanager/models/node.dart';

/// Modèle pour représenter un nœud dans un groupe HA
class HaNodeInfo {
  final Node node;
  final String route;
  int order;
  bool isActive;

  HaNodeInfo({
    required this.node,
    required this.route,
    required this.order,
    this.isActive = false,
  });

  @override
  String toString() {
    return 'HaNodeInfo(node: ${node.name}, route: $route, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HaNodeInfo &&
        other.node.id == node.id &&
        other.route == route;
  }

  @override
  int get hashCode => node.id.hashCode ^ route.hashCode;
}
