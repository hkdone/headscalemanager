import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/version_info.dart';

/// Service de validation des conflits de routes LAN.
class RouteConflictService {
  /// Vérifie si une route est déjà partagée par un autre nœud dans le réseau.
  ///
  /// Retourne le nœud qui partage déjà la route, ou null si la route est disponible.
  static Node? getConflictingNode(
      String route, String excludeNodeId, List<Node> allNodes) {
    // Les routes d'exit node (0.0.0.0/0 et ::/0) sont exemptées.
    if (route == '0.0.0.0/0' || route == '::/0') {
      return null;
    }

    for (final node in allNodes) {
      if (node.id != excludeNodeId && node.sharedRoutes.contains(route)) {
        return node;
      }
    }
    return null;
  }

  /// Valide une demande d'approbation de route selon le moteur ACL et la
  /// version serveur :
  /// - En `grantsV29` (>= 0.29.0) : un CIDR dupliqué sur un autre utilisateur
  ///   est autorisé avec un avertissement `via` (`warningSharedVia`), et sur le
  ///   même utilisateur avec un avertissement HA/Failover (`warningHaFailover`).
  /// - Dans les autres modes/versions : blocage strict (`conflict`).
  static RouteValidationResult validateRouteApproval(
    String route,
    String requestingNodeId,
    List<Node> allNodes, {
    AclEngineMode engineMode = AclEngineMode.standard,
    String? serverVersion,
    bool isFr = true,
  }) {
    final conflictingNode =
        getConflictingNode(route, requestingNodeId, allNodes);

    if (conflictingNode != null) {
      final supportsVia = engineMode == AclEngineMode.grantsV29 &&
          VersionInfo.checkVersionAtLeast(serverVersion ?? '', '0.29.0');

      if (supportsVia) {
        Node? requestingNode;
        for (final node in allNodes) {
          if (node.id == requestingNodeId) {
            requestingNode = node;
            break;
          }
        }

        if (requestingNode != null &&
            requestingNode.user == conflictingNode.user) {
          return RouteValidationResult.warningHaFailover(
            isFr
                ? 'CIDR "$route" déjà partagé par "${conflictingNode.name}" (même utilisateur) : mode Haute Disponibilité / Failover.'
                : 'CIDR "$route" already shared by "${conflictingNode.name}" (same user): High Availability / Failover mode.',
            conflictingNode,
          );
        }

        return RouteValidationResult.warningSharedVia(
          isFr
              ? 'CIDR "$route" également partagé par "${conflictingNode.name}" (${conflictingNode.user}) : autorisé en Grants V29 grâce à l\'isolation par "via".'
              : 'CIDR "$route" also shared by "${conflictingNode.name}" (${conflictingNode.user}): allowed in Grants V29 with "via" isolation.',
          conflictingNode,
        );
      }

      return RouteValidationResult.conflict(
        isFr
            ? 'Ce réseau local est déjà partagé par ${conflictingNode.name} (utilisateur : ${conflictingNode.user}). Il n\'est pas possible d\'ajouter un deuxième partage identique dans ce mode.'
            : 'This local network is already shared by ${conflictingNode.name} (user: ${conflictingNode.user}). Duplicate subnets are blocked in this mode.',
        conflictingNode,
      );
    }

    return RouteValidationResult.approved(
      isFr ? 'La route peut être approuvée.' : 'Route can be approved.',
    );
  }

  /// Retourne les CIDR (hors exit node) partagés simultanément par plusieurs
  /// utilisateurs distincts — utile avant un rollback `Grants V29 -> Standard`.
  static Map<String, List<Node>> findCrossUserDuplicateCidrs(
      List<Node> allNodes) {
    final Map<String, List<Node>> byRoute = {};
    for (final node in allNodes) {
      for (final route in node.sharedRoutes) {
        if (route == '0.0.0.0/0' || route == '::/0') continue;
        byRoute.putIfAbsent(route, () => []).add(node);
      }
    }

    final Map<String, List<Node>> duplicates = {};
    byRoute.forEach((route, nodes) {
      final distinctUsers = nodes.map((n) => n.user).toSet();
      if (distinctUsers.length > 1) {
        duplicates[route] = nodes;
      }
    });
    return duplicates;
  }
}

/// Résultat de la validation d'une route.
class RouteValidationResult {
  final RouteValidationType type;
  final String message;
  final Node? conflictingNode;

  const RouteValidationResult._(this.type, this.message, this.conflictingNode);

  factory RouteValidationResult.approved(String message) {
    return RouteValidationResult._(RouteValidationType.approved, message, null);
  }

  factory RouteValidationResult.warningSharedVia(
      String message, Node conflictingNode) {
    return RouteValidationResult._(
        RouteValidationType.warningSharedVia, message, conflictingNode);
  }

  factory RouteValidationResult.warningHaFailover(
      String message, Node conflictingNode) {
    return RouteValidationResult._(
        RouteValidationType.warningHaFailover, message, conflictingNode);
  }

  factory RouteValidationResult.conflict(String message, Node conflictingNode) {
    return RouteValidationResult._(
        RouteValidationType.conflict, message, conflictingNode);
  }

  bool get isApproved => type != RouteValidationType.conflict;
  bool get isConflict => type == RouteValidationType.conflict;
  bool get hasWarning =>
      type == RouteValidationType.warningSharedVia ||
      type == RouteValidationType.warningHaFailover;
}

/// Types de validation de route.
enum RouteValidationType {
  approved,
  warningSharedVia,
  warningHaFailover,
  conflict,
}
