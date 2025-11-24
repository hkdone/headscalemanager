import 'package:headscalemanager/models/node.dart';

/// Modèle pour représenter un événement de basculement HA
class FailoverEvent {
  /// Horodatage de l'événement
  final DateTime timestamp;
  
  /// Route concernée par le basculement
  final String route;
  
  /// Utilisateur propriétaire de la route
  final String user;
  
  /// Nom du nœud qui est tombé en panne
  final String failedNodeName;
  
  /// ID du nœud qui est tombé en panne
  final String failedNodeId;
  
  /// Nom du nœud de remplacement activé
  final String replacementNodeName;
  
  /// ID du nœud de remplacement activé
  final String replacementNodeId;
  
  /// Raison du basculement
  final String reason;
  
  /// Indique si le basculement a été automatique ou manuel
  final bool isAutomatic;

  FailoverEvent({
    required this.timestamp,
    required this.route,
    required this.user,
    required this.failedNodeName,
    required this.failedNodeId,
    required this.replacementNodeName,
    required this.replacementNodeId,
    required this.reason,
    this.isAutomatic = true,
  });

  /// Constructeur d'usine pour créer un événement depuis JSON
  factory FailoverEvent.fromJson(Map<String, dynamic> json) {
    return FailoverEvent(
      timestamp: DateTime.parse(json['timestamp']),
      route: json['route'],
      user: json['user'],
      failedNodeName: json['failedNodeName'],
      failedNodeId: json['failedNodeId'],
      replacementNodeName: json['replacementNodeName'],
      replacementNodeId: json['replacementNodeId'],
      reason: json['reason'],
      isAutomatic: json['isAutomatic'] ?? true,
    );
  }

  /// Convertit l'événement en JSON pour la persistance
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'route': route,
      'user': user,
      'failedNodeName': failedNodeName,
      'failedNodeId': failedNodeId,
      'replacementNodeName': replacementNodeName,
      'replacementNodeId': replacementNodeId,
      'reason': reason,
      'isAutomatic': isAutomatic,
    };
  }

  /// Crée un événement de basculement automatique
  factory FailoverEvent.automatic({
    required String route,
    required String user,
    required Node failedNode,
    required Node replacementNode,
    String? customReason,
  }) {
    return FailoverEvent(
      timestamp: DateTime.now(),
      route: route,
      user: user,
      failedNodeName: failedNode.name,
      failedNodeId: failedNode.id,
      replacementNodeName: replacementNode.name,
      replacementNodeId: replacementNode.id,
      reason: customReason ?? 'Nœud ${failedNode.name} détecté hors ligne',
      isAutomatic: true,
    );
  }

  /// Crée un événement de basculement manuel
  factory FailoverEvent.manual({
    required String route,
    required String user,
    required Node failedNode,
    required Node replacementNode,
    required String reason,
  }) {
    return FailoverEvent(
      timestamp: DateTime.now(),
      route: route,
      user: user,
      failedNodeName: failedNode.name,
      failedNodeId: failedNode.id,
      replacementNodeName: replacementNode.name,
      replacementNodeId: replacementNode.id,
      reason: reason,
      isAutomatic: false,
    );
  }

  @override
  String toString() {
    return 'FailoverEvent(route: $route, failed: $failedNodeName, replacement: $replacementNodeName, time: $timestamp)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailoverEvent &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          route == other.route &&
          failedNodeId == other.failedNodeId &&
          replacementNodeId == other.replacementNodeId;

  @override
  int get hashCode =>
      timestamp.hashCode ^
      route.hashCode ^
      failedNodeId.hashCode ^
      replacementNodeId.hashCode;
}

/// Modèle pour représenter un nœud en panne et ses routes affectées
class FailedNodeInfo {
  /// Le nœud qui est tombé en panne
  final Node node;
  
  /// Liste des routes LAN affectées par la panne
  final List<String> affectedRoutes;
  
  /// Horodatage de la détection de la panne
  final DateTime detectedAt;

  FailedNodeInfo({
    required this.node,
    required this.affectedRoutes,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Obtient uniquement les routes LAN (exclut les routes exit node)
  List<String> get lanRoutes {
    return affectedRoutes
        .where((route) => route != '0.0.0.0/0' && route != '::/0')
        .toList();
  }

  /// Obtient uniquement les routes exit node
  List<String> get exitNodeRoutes {
    return affectedRoutes
        .where((route) => route == '0.0.0.0/0' || route == '::/0')
        .toList();
  }

  /// Indique si ce nœud était un exit node
  bool get wasExitNode => exitNodeRoutes.isNotEmpty;

  /// Indique si ce nœud partageait des routes LAN
  bool get wasLanSharer => lanRoutes.isNotEmpty;

  /// Nombre total de routes affectées
  int get totalAffectedRoutes => affectedRoutes.length;

  /// Crée une instance depuis un nœud en filtrant ses routes partagées
  factory FailedNodeInfo.fromNode(Node node) {
    return FailedNodeInfo(
      node: node,
      affectedRoutes: List<String>.from(node.sharedRoutes),
    );
  }

  @override
  String toString() {
    return 'FailedNodeInfo(node: ${node.name}, routes: ${affectedRoutes.length}, detected: $detectedAt)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailedNodeInfo &&
          runtimeType == other.runtimeType &&
          node.id == other.node.id;

  @override
  int get hashCode => node.id.hashCode;
}

/// Modèle pour représenter les options de remplacement pour un nœud en panne
class ReplacementOption {
  /// Le nœud de remplacement potentiel
  final Node node;
  
  /// Ordre de priorité HA (1 = priorité la plus haute)
  final int priority;
  
  /// Indique si ce nœud est actuellement en ligne
  final bool isOnline;
  
  /// Routes que ce nœud peut reprendre
  final List<String> compatibleRoutes;

  ReplacementOption({
    required this.node,
    required this.priority,
    required this.isOnline,
    required this.compatibleRoutes,
  });

  /// Indique si ce nœud est le meilleur candidat (priorité 1 et en ligne)
  bool get isBestCandidate => priority == 1 && isOnline;

  /// Score de qualité du candidat (plus élevé = meilleur)
  int get qualityScore {
    int score = 0;
    if (isOnline) score += 100;
    score += (10 - priority); // Priorité inversée (1 = 9 points, 2 = 8 points, etc.)
    score += compatibleRoutes.length; // Bonus pour plus de routes compatibles
    return score;
  }

  @override
  String toString() {
    return 'ReplacementOption(node: ${node.name}, priority: $priority, online: $isOnline, routes: ${compatibleRoutes.length})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplacementOption &&
          runtimeType == other.runtimeType &&
          node.id == other.node.id;

  @override
  int get hashCode => node.id.hashCode;
}
