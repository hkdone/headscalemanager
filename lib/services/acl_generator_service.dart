import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';

/// Service dédié à la génération des politiques ACL (Access Control List) Headscale.
///
/// Cette classe encapsule la logique complexe de traitement des utilisateurs et des nœuds
/// pour construire une politique ACL basée sur les tags et les routes.
class AclGeneratorService {
  /// Génère une politique ACL Headscale complète basée sur les utilisateurs et les nœuds fournis.
  ///
  /// Cette méthode traite les données des utilisateurs et des nœuds pour construire
  /// les sections 'groups', 'tagOwners', 'autoApprovers' et 'acls' de la politique ACL.
  ///
  /// [users] : Liste des utilisateurs Headscale.
  /// [nodes] : Liste des nœuds Headscale.
  ///
  /// Retourne un [Map<String, dynamic>] représentant la politique ACL générée.
  Map<String, dynamic> generateAclPolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, String>> temporaryRules = const [],
  }) {
    // --- Étape 1: Extraire toutes les informations des nœuds et utilisateurs ---
    final groups = <String, List<String>>{};
    users.forEach((user) => groups['group:${user.name}'] = [user.name]);

    final tagOwners = <String, List<String>>{};
    final autoApprovers = {'routes': <String, List<String>>{}, 'exitNodes': <String>[]};

    final tagsByUser = <String, Set<String>>{};
    final routesByUser = <String, Set<String>>{};

    for (var node in nodes) {
      final groupName = 'group:${node.user}';
      final userName = node.user;

      if (node.tags.isNotEmpty) {
        if (!tagsByUser.containsKey(userName)) tagsByUser[userName] = <String>{};
        tagsByUser[userName]!.addAll(node.tags);

        for (var tag in node.tags) {
          if (!tagOwners.containsKey(tag)) tagOwners[tag] = [];
          if (!tagOwners[tag]!.contains(groupName)) tagOwners[tag]!.add(groupName);
        }
      }

      final subnetRoutes = node.sharedRoutes;
      if (subnetRoutes.isNotEmpty) {
        if (!routesByUser.containsKey(userName)) routesByUser[userName] = <String>{};
        routesByUser[userName]!.addAll(subnetRoutes);

        if (node.tags.isNotEmpty) {
          final routesMap = autoApprovers['routes'] as Map<String, List<String>>;
          for (var tag in node.tags) {
            for (var route in subnetRoutes) {
              if (!routesMap.containsKey(route)) routesMap[route] = [];
              if (!routesMap[route]!.contains(tag)) routesMap[route]!.add(tag);
            }
          }
        }
      }

      if (node.isExitNode && node.tags.isNotEmpty) {
        final exitNodesList = autoApprovers['exitNodes'] as List<String>;
        final routesMap = autoApprovers['routes'] as Map<String, List<String>>;
        const exitRoutes = ['0.0.0.0/0', '::/0'];

        for (var tag in node.tags) {
          if (!exitNodesList.contains(tag)) {
            exitNodesList.add(tag);
          }

          // Enregistrer également les routes de sortie pour ce tag
          for (var route in exitRoutes) {
            final routeOwners = routesMap.putIfAbsent(route, () => []);
            if (!routeOwners.contains(tag)) {
              routeOwners.add(tag);
            }
          }
        }
      }
    }

    // --- Étape 2: Construire les règles ACL en priorisant les règles temporaires ---
    final acls = <Map<String, dynamic>>[];

    // 2.1: Ajouter les règles d'autorisation temporaires EN PREMIER
    for (var rule in temporaryRules) {
      final src = rule['src'];
      final dst = rule['dst'];

      if (src != null && dst != null) {
        // Règle pour la communication aller
        acls.add({
          'action': 'accept',
          'src': [src],
          'dst': ['$dst:*'],
        });
        // Règle pour la communication retour (essentiel)
        acls.add({
          'action': 'accept',
          'src': [dst],
          'dst': ['$src:*'],
        });
      }
    }

    // 2.2: Ajouter les règles de base avec isolation 100% stricte APRÈS
    final allExitNodeTags = (autoApprovers['exitNodes'] as List<String>).toSet();

    tagsByUser.forEach((userName, userTags) {
      if (userTags.isEmpty) return;

      final userTagList = userTags.toList();
      final destinations = <String>{};

      // Accès à ses propres tags
      destinations.addAll(userTagList.map((t) => '$t:*'));

      // Accès aux routes que CET utilisateur annonce, en excluant les routes de sortie
      if (routesByUser.containsKey(userName)) {
        final nonExitRoutes = routesByUser[userName]!.where((route) => route != '0.0.0.0/0' && route != '::/0');
        destinations.addAll(nonExitRoutes.map((r) => '$r:*'));
      }

      // Accès à SES PROPRES exit nodes uniquement
      final ownedExitNodes = allExitNodeTags.where((exitTag) {
        final owners = tagOwners[exitTag] ?? [];
        return owners.contains('group:$userName');
      });
      destinations.addAll(ownedExitNodes.map((t) => '$t:*'));

      // Si l'utilisateur possède un exit node, lui donner accès à internet via celui-ci
      if (ownedExitNodes.isNotEmpty) {
        destinations.add('autogroup:internet:*');
      }

      acls.add({
        'action': 'accept',
        'src': userTagList,
        'dst': destinations.toList()..sort(),
      });
    });

    // --- Étape 3: Assemblage final ---
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