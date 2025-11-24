import 'package:headscalemanager/models/node.dart';

/// Service de validation des conflits de routes LAN avec gestion HA
class RouteConflictService {
  /// Vérifie s'il y a un conflit entre utilisateurs pour une route donnée
  /// 
  /// Retourne true si la route est déjà utilisée par un autre utilisateur
  /// [route] - La route à vérifier (ex: "192.168.1.0/24")
  /// [currentUser] - L'utilisateur qui demande la route
  /// [allNodes] - Liste de tous les nœuds du système
  static bool hasConflictBetweenUsers(String route, String currentUser, List<Node> allNodes) {
    for (var node in allNodes) {
      // Vérifier si un autre utilisateur partage déjà cette route
      if (node.user != currentUser && node.sharedRoutes.contains(route)) {
        return true;
      }
    }
    return false;
  }

  /// Vérifie si une route est déjà active chez le même utilisateur
  /// 
  /// Retourne true si la route est déjà partagée par un autre nœud du même utilisateur
  /// [route] - La route à vérifier
  /// [user] - L'utilisateur concerné
  /// [excludeNodeId] - ID du nœud à exclure de la vérification (pour éviter l'auto-conflit)
  /// [allNodes] - Liste de tous les nœuds du système
  static bool isRouteActiveInUser(String route, String user, String excludeNodeId, List<Node> allNodes) {
    for (var node in allNodes) {
      // Vérifier si un autre nœud du même utilisateur partage déjà cette route
      if (node.user == user && 
          node.id != excludeNodeId && 
          node.sharedRoutes.contains(route)) {
        return true;
      }
    }
    return false;
  }

  /// Obtient le nœud actif pour une route donnée chez un utilisateur
  /// 
  /// Retourne le nœud qui partage actuellement cette route, ou null si aucun
  /// [route] - La route à rechercher
  /// [user] - L'utilisateur concerné
  /// [allNodes] - Liste de tous les nœuds du système
  static Node? getActiveNodeForRoute(String route, String user, List<Node> allNodes) {
    for (var node in allNodes) {
      if (node.user == user && node.sharedRoutes.contains(route)) {
        return node;
      }
    }
    return null;
  }

  /// Valide une demande d'approbation de route
  /// 
  /// Retourne un objet [RouteValidationResult] avec le résultat de la validation
  /// [route] - La route à valider
  /// [requestingNodeId] - ID du nœud qui demande la route
  /// [allNodes] - Liste de tous les nœuds du système
  static RouteValidationResult validateRouteApproval(String route, String requestingNodeId, List<Node> allNodes) {
    final requestingNode = allNodes.firstWhere(
      (node) => node.id == requestingNodeId,
      orElse: () => throw ArgumentError('Nœud demandeur non trouvé: $requestingNodeId'),
    );

    // Vérifier conflit inter-utilisateurs (INTERDIT)
    if (hasConflictBetweenUsers(route, requestingNode.user, allNodes)) {
      final conflictingNode = allNodes.firstWhere(
        (node) => node.user != requestingNode.user && node.sharedRoutes.contains(route),
      );
      return RouteValidationResult.conflict(
        'Route déjà partagée par ${conflictingNode.name} (utilisateur: ${conflictingNode.user})',
        conflictingNode,
      );
    }

    // Vérifier conflit intra-utilisateur (MODE HA)
    if (isRouteActiveInUser(route, requestingNode.user, requestingNodeId, allNodes)) {
      final activeNode = getActiveNodeForRoute(route, requestingNode.user, allNodes)!;
      return RouteValidationResult.haMode(
        'Route déjà active sur ${activeNode.name}. Sera placée en backup HA.',
        activeNode,
      );
    }

    // Aucun conflit - approbation normale
    return RouteValidationResult.approved('Route peut être approuvée normalement.');
  }

  /// Obtient toutes les routes en conflit HA pour un utilisateur
  /// 
  /// Retourne une map avec les routes comme clés et les nœuds actifs comme valeurs
  /// [user] - L'utilisateur concerné
  /// [allNodes] - Liste de tous les nœuds du système
  static Map<String, Node> getHaConflictsForUser(String user, List<Node> allNodes) {
    final conflicts = <String, Node>{};
    final userNodes = allNodes.where((node) => node.user == user).toList();
    
    for (var node in userNodes) {
      for (var route in node.sharedRoutes) {
        // Ignorer les routes exit node
        if (route == '0.0.0.0/0' || route == '::/0') continue;
        
        // Compter combien de nœuds partagent cette route
        final nodesWithRoute = userNodes.where((n) => n.sharedRoutes.contains(route)).toList();
        if (nodesWithRoute.length > 1) {
          // Prendre le premier nœud en ligne, ou le premier si tous hors ligne
          final activeNode = nodesWithRoute.firstWhere(
            (n) => n.online,
            orElse: () => nodesWithRoute.first,
          );
          conflicts[route] = activeNode;
        }
      }
    }
    
    return conflicts;
  }

  /// Obtient les routes pour lesquelles un nœud est le maître HA
  ///
  /// Un nœud est "maître" pour une route s'il la partage activement
  /// et qu'au moins un autre nœud du même utilisateur est configuré en backup.
  static List<String> getHaMasteredRoutes(Node masterNode, List<Node> allNodes) {
    final masteredRoutes = <String>[];
    if (masterNode.sharedRoutes.isEmpty) {
      return masteredRoutes;
    }

    final userNodes = allNodes.where((n) => n.user == masterNode.user).toList();

    for (var route in masterNode.sharedRoutes) {
      // Ignorer les routes exit-node
      if (route == '0.0.0.0/0' || route == '::/0') continue;

      // Vérifier si un autre nœud est en backup pour cette route
      final hasBackup = userNodes.any((backupNode) =>
          backupNode.id != masterNode.id &&
          backupNode.availableRoutes.contains(route) &&
          !backupNode.sharedRoutes.contains(route));

      if (hasBackup) {
        masteredRoutes.add(route);
      }
    }
    return masteredRoutes;
  }

  /// Obtient la liste des nœuds de backup disponibles pour une route et un utilisateur
  static List<Node> getBackupNodesForRoute(
      String route, String user, List<Node> allNodes) {
    return allNodes
        .where((node) =>
            node.user == user &&
            node.availableRoutes.contains(route) &&
            !node.sharedRoutes.contains(route))
        .toList();
  }
}

/// Résultat de la validation d'une route
class RouteValidationResult {
  final RouteValidationType type;
  final String message;
  final Node? conflictingNode;

  const RouteValidationResult._(this.type, this.message, this.conflictingNode);

  /// Route approuvée normalement
  factory RouteValidationResult.approved(String message) {
    return RouteValidationResult._(RouteValidationType.approved, message, null);
  }

  /// Conflit inter-utilisateurs (INTERDIT)
  factory RouteValidationResult.conflict(String message, Node conflictingNode) {
    return RouteValidationResult._(RouteValidationType.conflict, message, conflictingNode);
  }

  /// Mode HA (backup)
  factory RouteValidationResult.haMode(String message, Node activeNode) {
    return RouteValidationResult._(RouteValidationType.haMode, message, activeNode);
  }

  bool get isApproved => type == RouteValidationType.approved;
  bool get isConflict => type == RouteValidationType.conflict;
  bool get isHaMode => type == RouteValidationType.haMode;
}

/// Types de validation de route
enum RouteValidationType {
  approved,  // Route peut être approuvée normalement
  conflict,  // Conflit inter-utilisateurs (INTERDIT)
  haMode,    // Mode HA (backup)
}
