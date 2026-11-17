import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/utils/string_utils.dart';

class TaglessTransitionReport {
  final Node? matchedNode;
  final bool found;
  final bool isOnline;
  final bool isUntagged;
  final bool belongsToTargetUser;
  final List<String> missingRoutes;
  final int verifiedPeerCount;
  final bool exitNodeVerified;
  final List<String> messages;

  const TaglessTransitionReport({
    required this.matchedNode,
    required this.found,
    required this.isOnline,
    required this.isUntagged,
    required this.belongsToTargetUser,
    required this.missingRoutes,
    required this.verifiedPeerCount,
    required this.exitNodeVerified,
    required this.messages,
  });

  bool get isFullyValidated =>
      found &&
      isUntagged &&
      belongsToTargetUser &&
      missingRoutes.isEmpty &&
      (verifiedPeerCount > 0 || messages.isEmpty);
}

class ServerSimulationCheck {
  final User user;
  final int nodeCount;
  final int passedFlows;
  final int totalFlows;

  const ServerSimulationCheck({
    required this.user,
    required this.nodeCount,
    required this.passedFlows,
    required this.totalFlows,
  });

  bool get allPassed => passedFlows == totalFlows;
}

/// Service métier du Centre d'Assistance à la Bascule (Sous-Plan 09-B).
class AclMigrationAssistantService {
  /// Génère la commande `tailscale up` exacte pour ré-enregistrer un nœud sans tag.
  static String buildTailscaleReauthCommand({
    required Node node,
    required String serverUrl,
  }) {
    final cleanUrl = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final buffer = StringBuffer(
      'tailscale up --login-server=$cleanUrl --advertise-tags= --force-reauth',
    );
    if (node.isExitNode ||
        node.sharedRoutes.contains('0.0.0.0/0') ||
        node.sharedRoutes.contains('::/0')) {
      buffer.write(' --advertise-exit-node');
    }
    final lanRoutes = node.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();
    if (lanRoutes.isNotEmpty) {
      buffer.write(' --advertise-routes=${lanRoutes.join(',')}');
    }
    return buffer.toString();
  }

  /// Indique si la politique serveur contient déjà `group:<user>` et les règles
  /// hybrides permettant d'accueillir [targetUser] sans tag.
  static bool isHybridNetReadyForUser({
    required Map<String, dynamic>? serverPolicy,
    required User targetUser,
  }) {
    if (serverPolicy == null || serverPolicy.isEmpty) return false;
    final groupName = 'group:${normalizeUserName(targetUser.name)}';
    final groups = serverPolicy['groups'];
    if (groups is! Map || !groups.containsKey(groupName)) return false;

    bool listMentionsGroup(dynamic rawList) {
      if (rawList is! List) return false;
      return rawList.any((e) {
        final s = e.toString();
        return s == groupName || s.startsWith('$groupName:');
      });
    }

    final grants = serverPolicy['grants'];
    if (grants is List) {
      for (final g in grants) {
        if (g is Map && listMentionsGroup(g['src'])) {
          return true;
        }
      }
    }
    final acls = serverPolicy['acls'];
    if (acls is List) {
      for (final a in acls) {
        if (a is Map && listMentionsGroup(a['src'])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Construit la politique préparée d'accueil (Parcours A, Étape 1) incluant
  /// `group:<user>` et l'hybridation sans perte des règles personnalisées.
  static Map<String, dynamic> buildPreparedWelcomePolicy({
    required AclEngineMode engineMode,
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic>? serverPolicy,
    required User targetUser,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
    bool includeUntaggedNodes = true,
  }) {
    final orchestrator = AclPolicyOrchestrator();
    final generated = orchestrator.generatePolicy(
      engineMode: engineMode,
      users: users,
      nodes: nodes,
      temporaryRules: temporaryRules,
      taildriveShares: taildriveShares,
      serverVersion: serverVersion,
      includeUntaggedNodes: includeUntaggedNodes,
    );

    final merged = PolicyPreserver.merge(
      generated,
      serverPolicy,
      preserveCustomRules: true,
      users: users,
      nodes: nodes,
      includeUntaggedNodes: includeUntaggedNodes,
    );

    // S'assurer que le groupe de l'utilisateur cible est autorisé même si
    // aucun nœud sans tag n'est encore apparu avant sa reconnexion.
    final groupName = 'group:${normalizeUserName(targetUser.name)}';
    if (includeUntaggedNodes) {
      if (merged['grants'] is List) {
        final grants = List<dynamic>.from(merged['grants'] as List);
        final hasSelfGroupGrant = grants.any((g) =>
            g is Map &&
            (g['src'] as List?)?.contains(groupName) == true &&
            (g['dst'] as List?)?.contains(groupName) == true);
        if (!hasSelfGroupGrant) {
          grants.add({
            'src': [groupName],
            'dst': [groupName],
            'ip': ['*'],
          });
          merged['grants'] = grants;
        }
      } else if (merged['acls'] is List) {
        final acls = List<dynamic>.from(merged['acls'] as List);
        final hasSelfGroupAcl = acls.any((a) =>
            a is Map &&
            (a['src'] as List?)?.contains(groupName) == true &&
            (a['dst'] as List?)?.contains('$groupName:*') == true);
        if (!hasSelfGroupAcl) {
          acls.add({
            'action': 'accept',
            'src': [groupName],
            'dst': ['$groupName:*'],
          });
          merged['acls'] = acls;
        }
      }
    }

    return merged;
  }

  /// Retrouve le nœud après reconnexion sans tag et valide son état API + ses flux ACL.
  static TaglessTransitionReport verifyTaglessTransition({
    required Node originalTaggedNode,
    required User targetUser,
    required List<Node> latestNodes,
    required List<User> latestUsers,
    required Map<String, dynamic> serverPolicy,
    required bool isFr,
  }) {
    final messages = <String>[];

    // 1. Retrouver le nœud (priorité : nœud sans tag au même nom/hostname/id)
    Node? matched;
    final untaggedCandidates = latestNodes.where((n) => n.tags.isEmpty).toList();
    for (final n in untaggedCandidates) {
      if (n.id == originalTaggedNode.id ||
          (n.machineKey.isNotEmpty &&
              n.machineKey == originalTaggedNode.machineKey) ||
          n.hostname.toLowerCase() ==
              originalTaggedNode.hostname.toLowerCase() ||
          n.name.toLowerCase() == originalTaggedNode.name.toLowerCase()) {
        matched = n;
        break;
      }
    }
    matched ??= latestNodes.cast<Node?>().firstWhere(
          (n) =>
              n!.id == originalTaggedNode.id ||
              n.hostname.toLowerCase() ==
                  originalTaggedNode.hostname.toLowerCase() ||
              n.name.toLowerCase() == originalTaggedNode.name.toLowerCase(),
          orElse: () => null,
        );

    if (matched == null) {
      return TaglessTransitionReport(
        matchedNode: null,
        found: false,
        isOnline: false,
        isUntagged: false,
        belongsToTargetUser: false,
        missingRoutes: originalTaggedNode.sharedRoutes,
        verifiedPeerCount: 0,
        exitNodeVerified: false,
        messages: [
          isFr
              ? 'Nœud introuvable sur le serveur. Vérifiez qu\'il s\'est bien ré-enregistré.'
              : 'Node not found on server. Check that it has re-registered.',
        ],
      );
    }

    final isUntagged = matched.tags.isEmpty;
    final belongsToTargetUser =
        PolicyInfrastructureBuilder.nodeBelongsToUser(matched, targetUser);

    if (!isUntagged) {
      messages.add(
        isFr
            ? 'Le nœud porte encore des tags (${matched.tags.join(', ')}).'
            : 'Node still has tags (${matched.tags.join(', ')}).',
      );
    }
    if (!belongsToTargetUser) {
      messages.add(
        isFr
            ? 'Le nœud est rattaché à "${matched.user}" au lieu de "${targetUser.name}".'
            : 'Node belongs to "${matched.user}" instead of "${targetUser.name}".',
      );
    }

    final missingRoutes = originalTaggedNode.sharedRoutes
        .where((r) => !matched!.sharedRoutes.contains(r))
        .toList();
    if (missingRoutes.isNotEmpty) {
      messages.add(
        isFr
            ? 'Routes à ré-approuver : ${missingRoutes.join(', ')}.'
            : 'Routes pending re-approval: ${missingRoutes.join(', ')}.',
      );
    }

    // 2. Simulation ACL contre les pairs du même utilisateur et Exit Node éventuel
    final parser = AclParserService(
      aclPolicy: serverPolicy,
      allNodes: latestNodes,
      allUsers: latestUsers,
    );

    final userPeers = latestNodes
        .where((n) =>
            n.id != matched!.id &&
            PolicyInfrastructureBuilder.nodeBelongsToUser(n, targetUser) &&
            n.ipAddresses.isNotEmpty)
        .toList();

    var verifiedPeers = 0;
    for (final peer in userPeers) {
      final forward = parser.simulateConnection(
        sourceNode: matched,
        destination: peer.ipAddresses.first,
      );
      if (forward.allowed) {
        verifiedPeers++;
      } else {
        messages.add(
          isFr
              ? 'Flux bloqué vers ${peer.name} (${peer.ipAddresses.first}).'
              : 'Flow blocked to ${peer.name} (${peer.ipAddresses.first}).',
        );
      }
    }

    var exitVerified = false;
    final hasExitNode =
        latestNodes.any((n) => n.isExitNode && n.tags.any((t) => t.contains('exit-node')) || (n.isExitNode && PolicyInfrastructureBuilder.nodeBelongsToUser(n, targetUser)));
    if (hasExitNode) {
      final exitSim = parser.simulateConnection(
        sourceNode: matched,
        destination: 'autogroup:internet',
      );
      exitVerified = exitSim.allowed;
    }

    return TaglessTransitionReport(
      matchedNode: matched,
      found: true,
      isOnline: matched.online,
      isUntagged: isUntagged,
      belongsToTargetUser: belongsToTargetUser,
      missingRoutes: missingRoutes,
      verifiedPeerCount: verifiedPeers,
      exitNodeVerified: exitVerified,
      messages: messages,
    );
  }

  /// Exécute une validation par simulation sur chaque utilisateur après une
  /// bascule serveur (Parcours C).
  static List<ServerSimulationCheck> evaluateServerSimulation({
    required Map<String, dynamic> policy,
    required List<User> users,
    required List<Node> nodes,
  }) {
    final parser = AclParserService(
      aclPolicy: policy,
      allNodes: nodes,
      allUsers: users,
    );
    final results = <ServerSimulationCheck>[];

    for (final user in users) {
      final userNodes = nodes
          .where((n) =>
              PolicyInfrastructureBuilder.nodeBelongsToUser(n, user) &&
              n.ipAddresses.isNotEmpty)
          .toList();
      if (userNodes.isEmpty) continue;

      var passed = 0;
      var total = 0;

      if (userNodes.length >= 2) {
        total++;
        final sim = parser.simulateConnection(
          sourceNode: userNodes.first,
          destination: userNodes[1].ipAddresses.first,
        );
        if (sim.allowed) passed++;
      }

      if (userNodes.any((n) => n.isExitNode)) {
        total++;
        final sim = parser.simulateConnection(
          sourceNode: userNodes.first,
          destination: 'autogroup:internet',
        );
        if (sim.allowed) passed++;
      }

      results.add(
        ServerSimulationCheck(
          user: user,
          nodeCount: userNodes.length,
          passedFlows: passed,
          totalFlows: total,
        ),
      );
    }

    return results;
  }
}
