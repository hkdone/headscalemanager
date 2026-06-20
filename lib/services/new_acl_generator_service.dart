import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Service dédié à la génération des politiques ACL (Access Control List) Headscale
/// avec la logique d'isolation des exit-nodes corrigée.
class NewAclGeneratorService {
  static const _taildriveMinVersion = '0.29.0';

  /// Génère la configuration Taildrive UNIQUEMENT si version >= 0.29.0
  /// Retourne null si version incompatible ou pas de partages
  static Map<String, dynamic>? _buildTaildriveConfig({
    required List<TaildriveShare> shares,
    required List<Node> nodes,
    String? serverVersion,
  }) {
    // Si version < 0.29.0, on retourne null (rien n'est ajouté)
    if (serverVersion == null ||
        !VersionInfo.checkVersionAtLeast(serverVersion, _taildriveMinVersion)) {
      return null;
    }

    if (shares.isEmpty) return null;

    final nodeAttrs = <Map<String, dynamic>>[];
    final grants = <Map<String, dynamic>>[];

    // 1. nodeAttrs: drive:share pour les nœuds sources
    final sourceNodeIds = shares.map((s) => s.sourceNodeId).toSet();
    for (var nodeId in sourceNodeIds) {
      final matchingNodes = nodes.where((n) => n.id == nodeId);
      final node = matchingNodes.isNotEmpty ? matchingNodes.first : null;
      if (node != null) {
        final targets = node.tags.isNotEmpty
            ? node.tags
            : ['group:${node.getNormalizedOwner()}'];
        nodeAttrs.add({
          'target': targets,
          'attr': ['drive:share'],
        });
      }
    }

    // 2. nodeAttrs: drive:access pour les bénéficiaires
    final recipientGroups = shares.map((s) => 
      s.recipient.startsWith('group:') 
        ? s.recipient 
        : 'group:${normalizeUserName(s.recipient)}'
    ).toSet();
    
    for (var group in recipientGroups) {
      nodeAttrs.add({
        'target': [group],
        'attr': ['drive:access'],
      });
    }

    // 3. grants: pour chaque partage
    for (var share in shares) {
      final matchingNodes = nodes.where((n) => n.id == share.sourceNodeId);
      final sourceNode = matchingNodes.isNotEmpty ? matchingNodes.first : null;
      if (sourceNode == null) continue;

      final dstTargets = sourceNode.tags.isNotEmpty
          ? sourceNode.tags
          : ['group:${sourceNode.getNormalizedOwner()}'];

      final src = share.recipient.startsWith('group:')
          ? share.recipient
          : 'group:${normalizeUserName(share.recipient)}';

      grants.add({
        'src': [src],
        'dst': dstTargets,
        'app': {
          'tailscale.com/cap/drive': [{
            'shares': [share.shareName],
            'access': share.accessMode == TaildriveAccessMode.rw ? 'rw' : 'ro',
          }]
        }
      });
    }

    return {'nodeAttrs': nodeAttrs, 'grants': grants};
  }
  /// Génère une politique ACL Headscale optimisée.
  ///
  /// [users] : Liste des utilisateurs Headscale.
  /// [nodes] : Liste des nœuds Headscale.
  /// [temporaryRules] : Liste des règles d'exception manuelles (tag-à-tag).
  /// [taildriveShares] : Liste des partages Taildrive.
  /// [serverVersion] : Version du serveur Headscale pour la compatibilité.
  ///
  /// Retourne un [Map<String, dynamic>] représentant la politique ACL générée.
  Map<String, dynamic> generatePolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
  }) {
    // --- Étape 1: Création des groupes et pré-déclaration des tagOwners de base ---
    final groups = <String, List<String>>{};
    final tagOwners = <String, List<String>>{};

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      groups[groupName] = [user.name];

      final baseTag = 'tag:${normalizeUserName(user.name)}-client';
      if (!tagOwners.containsKey(baseTag)) {
        tagOwners[baseTag] = [];
      }
      if (!tagOwners[baseTag]!.contains(groupName)) {
        tagOwners[baseTag]!.add(groupName);
      }
    }

    // --- Étape 2: Définition des propriétaires de tags SPÉCIFIQUES et des approbateurs automatiques ---
    final autoApprovers = {
      'routes': <String, List<String>>{},
    };

    for (var node in nodes) {
      final groupName = 'group:${node.getNormalizedOwner()}';

      for (var tag in node.tags) {
        if (!tagOwners.containsKey(tag)) {
          tagOwners[tag] = [];
        }
        if (!tagOwners[tag]!.contains(groupName)) {
          tagOwners[tag]!.add(groupName);
        }

        // Pour Headscale > 0.26, le champ 'exitNodes' n'est plus supporté.
        // L'approbation d'un exit node se fait en approuvant ses routes (0.0.0.0/0 et/ou ::/0).
        if (tag.contains(';lan-sharer') || tag.contains(';exit-node')) {
          for (var route in node.sharedRoutes) {
            final routesMap =
                autoApprovers['routes'] as Map<String, List<String>>;
            if (!routesMap.containsKey(route)) {
              routesMap[route] = [];
            }
            if (!routesMap[route]!.contains(tag)) {
              routesMap[route]!.add(tag);
            }
          }
        }
      }
    }

    // --- Étape 3: Construction des règles ACL ---
    final acls = <Map<String, dynamic>>[];

    // 3.1: Ajouter les règles d'exception manuelles
    for (var rule in temporaryRules) {
      final src = rule['src'] as String?;
      final dst = rule['dst'] as String?;
      final port = rule['port'] as String?;

      if (src == null || dst == null) continue;

      final dstPort = (port != null && port.isNotEmpty) ? ':$port' : ':*';

      // Si la destination est un tag, la règle est bidirectionnelle
      if (dst.startsWith('tag:')) {
        acls.add({
          'action': 'accept',
          'src': [src],
          'dst': ['$dst$dstPort']
        });
        acls.add({
          'action': 'accept',
          'src': [dst],
          'dst': ['$src$dstPort']
        });
      } else {
        // Si la destination est une IP/subnet/range, la règle est unidirectionnelle
        final destinations = dst
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .map((d) => '$d$dstPort')
            .toList();

        if (destinations.isNotEmpty) {
          acls.add({
            'action': 'accept',
            'src': [src],
            'dst': destinations,
          });
        }
      }
    }

    // 3.2: Construire les règles de base et de service pour chaque utilisateur
    final tagsByUser = <String, Set<String>>{};
    for (var node in nodes) {
      tagsByUser.putIfAbsent(node.getNormalizedOwner(), () => <String>{}).addAll(node.tags);
    }

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      final userNodes = nodes
          .where((node) =>
              node.user == user.name ||
              node.getNormalizedOwner() == normalizeUserName(user.name))
          .toList();
      final userTags = userNodes
          .expand((node) => node.tags)
          .toSet(); // Tous les tags des nœuds de l'utilisateur

      if (userTags.isEmpty) continue;

      final destinations = <String>{};

      // Check if the user has any node with the 'exit-node' tag
      final hasExitNode = userNodes
          .any((node) => node.tags.any((tag) => tag.contains(';exit-node')));

      if (hasExitNode) {
        destinations.add('autogroup:internet:*'); // Accès Internet explicite
      }

      // Ajouter les tags des nœuds de l'utilisateur comme destinations
      for (var tag in userTags) {
        destinations.add('$tag:*');
      }

      // Ajouter les destinations spécifiques aux routes LAN via les nœuds de sortie/LAN sharer
      for (var node in userNodes) {
        final nodeTags = node.tags
            .where((tag) =>
                tag.contains(';exit-node') || tag.contains(';lan-sharer'))
            .toSet();
        if (nodeTags.isNotEmpty) {
          for (var route in node.sharedRoutes) {
            if (route != '0.0.0.0/0' && route != '::/0') {
              // Routes LAN
              destinations.add('$route:*'); // Ajout de la route LAN simple
            }
          }
        }
      }

      // Règle principale pour la communication intra-utilisateur, Internet et LAN via nœuds de sortie
      acls.add({
        'action': 'accept',
        'src': userTags.toList()..sort(),
        'dst': destinations.toList()..sort(),
      });

      // Règles basées sur le 'group' pour l'accès depuis l'extérieur du tailnet
      // Ces règles sont importantes pour que les utilisateurs puissent se connecter à leurs propres nœuds
      // et utiliser leurs nœuds de sortie.
      final userName = normalizeUserName(user.name);
      final baseTag = 'tag:$userName-client';

      acls.add({
        'action': 'accept',
        'src': [groupName],
        'dst': ['$baseTag:*']
      });

      // Règle pour l'accès aux nœuds de sortie et LAN sharer par le groupe de l'utilisateur
      final userExitNodeLanSharerTags = userNodes
          .expand((node) => node.tags)
          .where((tag) =>
              tag.contains(';exit-node') || tag.contains(';lan-sharer'))
          .toSet();

      if (userExitNodeLanSharerTags.isNotEmpty) {
        // Ajouter les destinations spécifiques aux routes LAN via les nœuds de sortie/LAN sharer pour le groupe
        final groupDestinations =
            userExitNodeLanSharerTags.map((tag) => '$tag:*').toSet();
        for (var node in userNodes) {
          final nodeTags = node.tags
              .where((tag) =>
                  tag.contains(';exit-node') || tag.contains(';lan-sharer'))
              .toSet();
          if (nodeTags.isNotEmpty) {
            for (var route in node.sharedRoutes) {
              if (route != '0.0.0.0/0' && route != '::/0') {
                // Routes LAN
                groupDestinations
                    .add('$route:*'); // Ajout de la route LAN simple
              }
            }
          }
        }

        acls.add({
          'action': 'accept',
          'src': [groupName],
          'dst': groupDestinations.toList()..sort(),
        });
      }
    }

    // --- Étape 4: Taildrive (nodeAttrs & grants) ---
    // Utilise la fonction helper qui gère la compatibilité version
    final taildriveConfig = _buildTaildriveConfig(
      shares: taildriveShares,
      nodes: nodes,
      serverVersion: serverVersion,
    );
    
    final nodeAttrs = taildriveConfig?['nodeAttrs'] as List<Map<String, dynamic>>? ?? [];
    final grants = taildriveConfig?['grants'] as List<Map<String, dynamic>>? ?? [];

    // --- Étape 5: Assemblage final ---
    final policy = {
      'groups': groups,
      'tagOwners': tagOwners,
      'autoApprovers': autoApprovers,
      'acls': acls,
      'hosts': <String, dynamic>{},
    };

    if (nodeAttrs.isNotEmpty) {
      policy['nodeAttrs'] = nodeAttrs;
    }
    if (grants.isNotEmpty) {
      policy['grants'] = grants;
    }

    return policy;
  }
}
