import 'package:headscalemanager/models/node.dart';

/// Service de validation des conflits de routes LAN.
class RouteConflictService {
  /// Vérifie si une route est déjà partagée par un autre nœud dans le réseau.
  ///
  /// Retourne le nœud qui partage déjà la route, ou null si la route est disponible.
  /// [route] - La route à vérifier (ex: "192.168.1.0/24").
  /// [excludeNodeId] - L'ID du nœud qui fait la demande, à exclure de la recherche.
  /// [allNodes] - La liste de tous les nœuds du système.
  static Node? getConflictingNode(
      String route, String excludeNodeId, List<Node> allNodes) {
    // MODIFICATION: Les routes d'exit node (0.0.0.0/0 et ::/0) sont exemptées
    // de la règle de non-duplication et ne déclenchent pas de conflit strict.
    if (route == '0.0.0.0/0' || route == '::/0') {
      return null; // Les routes d'exit node ne sont pas sujettes aux conflits de duplication.
    }

    try {
      return allNodes.firstWhere((node) =>
          node.id != excludeNodeId && node.sharedRoutes.contains(route));
    } catch (e) {
      return null;
    }
  }

  /// Valide une demande d'approbation de route avec une règle stricte : une route ne peut être partagée que par un seul nœud.
  ///
  /// Retourne un objet [RouteValidationResult] avec le résultat de la validation.
  /// [route] - La route à valider.
  /// [requestingNodeId] - L'ID du nœud qui demande la route.
  /// [allNodes] - La liste de tous les nœuds du système.
  static RouteValidationResult validateRouteApproval(
      String route, String requestingNodeId, List<Node> allNodes) {
    final conflictingNode =
        getConflictingNode(route, requestingNodeId, allNodes);

    if (conflictingNode != null) {
      return RouteValidationResult.conflict(
        "Ce réseau local est déja partagé par ${conflictingNode.name} (utilisateur: ${conflictingNode.user}). Il n'est pas possible d'ajouter une deuxiéme partage de réseau IPV4 identique.",
        conflictingNode,
      );
    }

    // Aucun conflit - approbation normale
    return RouteValidationResult.approved('La route peut être approuvée.');
  }
}

/// Résultat de la validation d'une route.
class RouteValidationResult {
  final RouteValidationType type;
  final String message;
  final Node? conflictingNode;

  const RouteValidationResult._(this.type, this.message, this.conflictingNode);

  /// Route approuvée normalement.
  factory RouteValidationResult.approved(String message) {
    return RouteValidationResult._(RouteValidationType.approved, message, null);
  }

  /// Conflit : la route est déjà utilisée.
  factory RouteValidationResult.conflict(String message, Node conflictingNode) {
    return RouteValidationResult._(
        RouteValidationType.conflict, message, conflictingNode);
  }

  bool get isApproved => type == RouteValidationType.approved;
  bool get isConflict => type == RouteValidationType.conflict;
}

/// Types de validation de route.
enum RouteValidationType {
  approved, // La route peut être approuvée normalement.
  conflict, // Conflit : la route est déjà utilisée.
}
