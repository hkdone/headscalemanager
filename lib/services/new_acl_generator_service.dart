import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Service dédié à la génération des politiques ACL (Access Control List) Headscale
/// avec la logique d'isolation des exit-nodes corrigée.
class NewAclGeneratorService {
  /// Génère une politique ACL Headscale optimisée.
  ///
  /// [users] : Liste des utilisateurs Headscale.
  /// [nodes] : Liste des nœuds Headscale.
  /// [temporaryRules] : Liste des règles d'exception manuelles (tag-à-tag).
  ///
  /// Retourne un [Map<String, dynamic>] représentant la politique ACL générée.
  Map<String, dynamic> generatePolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
  }) {
    // --- Étape 1: Création des groupes et pré-déclaration des tagOwners de base ---
    final groups = <String, List<String>>{};
    final tagOwners = <String, List<String>>{};

    for (var user in users) {
      final groupName = 'group:${user.name}';
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
      'exitNodes': <String>[],
    };

    for (var node in nodes) {
      final groupName = 'group:${node.user}';

      for (var tag in node.tags) {
        if (!tagOwners.containsKey(tag)) {
          tagOwners[tag] = [];
        }
        if (!tagOwners[tag]!.contains(groupName)) {
          tagOwners[tag]!.add(groupName);
        }

        if (tag.contains(';lan-sharer')) {
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

        if (tag.contains(';exit-node')) {
          final exitNodesList = autoApprovers['exitNodes'] as List<String>;
          if (!exitNodesList.contains(tag)) {
            exitNodesList.add(tag);
          }
        }
      }
    }

    // --- Étape 3: Construction des règles ACL ---
    final acls = <Map<String, dynamic>>[];

    // 3.1: Ajouter les règles d'exception manuelles (tag-à-tag)
    for (var rule in temporaryRules) {
      final src = rule['src'] as String?;
      final dst = rule['dst'] as String?;
      final port = rule['port'] as String?;

      if (src != null && dst != null) {
        final dstPort = (port != null && port.isNotEmpty) ? ':$port' : ':*';
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
      }
    }

    // 3.2: Construire les règles de base et de service pour chaque utilisateur
    final tagsByUser = <String, Set<String>>{};
    for (var node in nodes) {
      tagsByUser.putIfAbsent(node.user, () => <String>{}).addAll(node.tags);
    }

    for (var user in users) {
      final groupName = 'group:${user.name}';
      final userNodes = nodes.where((node) => node.user == user.name).toList();
      final userTags = userNodes.expand((node) => node.tags).toSet(); // Tous les tags des nœuds de l'utilisateur

      if (userTags.isEmpty) continue;

      final destinations = <String>{};
      destinations.add('autogroup:internet:*'); // Accès Internet explicite

      // Ajouter les tags des nœuds de l'utilisateur comme destinations
      for (var tag in userTags) {
        destinations.add('$tag:*');
      }

      // Ajouter les destinations spécifiques aux routes LAN via les nœuds de sortie/LAN sharer
      for (var node in userNodes) {
        final nodeTags = node.tags.where((tag) => tag.contains(';exit-node') || tag.contains(';lan-sharer')).toSet();
        if (nodeTags.isNotEmpty) {
          for (var route in node.sharedRoutes) {
            if (route != '0.0.0.0/0' && route != '::/0') { // Routes LAN
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
          .where((tag) => tag.contains(';exit-node') || tag.contains(';lan-sharer'))
          .toSet();

      if (userExitNodeLanSharerTags.isNotEmpty) {
        // Ajouter les destinations spécifiques aux routes LAN via les nœuds de sortie/LAN sharer pour le groupe
        final groupDestinations = userExitNodeLanSharerTags.map((tag) => '$tag:*').toSet();
        for (var node in userNodes) {
          final nodeTags = node.tags.where((tag) => tag.contains(';exit-node') || tag.contains(';lan-sharer')).toSet();
          if (nodeTags.isNotEmpty) {
            for (var route in node.sharedRoutes) {
              if (route != '0.0.0.0/0' && route != '::/0') { // Routes LAN
                groupDestinations.add('$route:*'); // Ajout de la route LAN simple
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

    // --- Étape 4: Assemblage final ---
    return {
      'groups': groups,
      'tagOwners': tagOwners,
      'autoApprovers': autoApprovers,
      'acls': acls,
      'hosts': <String, dynamic>{},
      'tests': <Map<String, dynamic>>[],
    };
  }
}
