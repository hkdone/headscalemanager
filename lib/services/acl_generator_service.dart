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
  }) {
    // --- Étape 1: Extraire toutes les informations des nœuds et utilisateurs ---
    final groups = <String, List<String>>{};
    users.forEach((user) => groups['group:${user.name}'] = [user.name]);

    final tagOwners = <String, List<String>>{};
    final autoApprovers = {'routes': <String, List<String>>{}, 'exitNodes': <String>[]};

    final tagsByUser = <String, Set<String>>{};
    final routesByUser = <String, Set<String>>{};
    final userOwnsExitNode = <String, bool>{};

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

      final isExitNode = node.advertisedRoutes.contains('0.0.0.0/0') || node.advertisedRoutes.contains('::/0');
      if (isExitNode) userOwnsExitNode[userName] = true;

      final subnetRoutes = node.advertisedRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
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

      if (isExitNode && node.tags.isNotEmpty) {
        final exitNodesList = autoApprovers['exitNodes'] as List<String>;
        for (var tag in node.tags) {
          if (!exitNodesList.contains(tag)) exitNodesList.add(tag);
        }
      }
    }

    // --- Étape 2: Construire les règles ACL "Tout-Tag" ---
    final acls = <Map<String, dynamic>>[];

    // Règle pour chaque utilisateur, basée sur l'ensemble de ses tags
    tagsByUser.forEach((userName, userTags) {
      if (userTags.isEmpty) return; // Ne rien faire pour les utilisateurs sans tags

      final userTagList = userTags.toList();
      final destinations = <String>{};
      // Les tags d'un utilisateur peuvent communiquer entre eux
      destinations.addAll(userTagList.map((t) => '$t:*'));

      // Ajouter l'accès aux routes possédées par l'utilisateur
      if (routesByUser.containsKey(userName)) {
        destinations.addAll(routesByUser[userName]!.map((r) => '$r:*'));
      }
      // Ajouter l'accès à internet si l'utilisateur possède un exit node
      if (userOwnsExitNode[userName] == true) {
        destinations.add('autogroup:internet:*');
      }

      acls.add({
        'action': 'accept',
        'src': userTagList,
        'dst': destinations.toList(),
      });
    });

    // Règle pour les tags "routeurs" eux-mêmes
    final allRouterTags = <String>{};
    (autoApprovers['routes'] as Map<String, List<String>>).values.forEach(allRouterTags.addAll);
    allRouterTags.addAll(autoApprovers['exitNodes'] as List<String>);

    allRouterTags.forEach((tag) {
      final destinations = <String>{};
      // Le routeur peut parler aux autres tags de son propriétaire
      tagOwners[tag]?.forEach((ownerGroup) {
        final ownerName = ownerGroup.replaceFirst('group:', '');
        if (tagsByUser.containsKey(ownerName)) {
          destinations.addAll(tagsByUser[ownerName]!.map((t) => '$t:*'));
        }
      });

      // Le routeur peut parler aux routes qu'il annonce
      (autoApprovers['routes'] as Map<String, List<String>>).forEach((route, tags) {
        if (tags.contains(tag)) destinations.add('$route:*');
      });

      // Le routeur peut parler à internet s'il est un exit node
      if ((autoApprovers['exitNodes'] as List<String>).contains(tag)) {
        destinations.add('autogroup:internet:*');
      }

      if (destinations.isNotEmpty) {
        acls.add({
          'action': 'accept',
          'src': [tag],
          'dst': destinations.toList(),
        });
      }
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