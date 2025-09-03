import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Service dédié à la génération des politiques ACL (Access Control List) Headscale
/// selon la nouvelle nomenclature optimisée.
///
/// Cette classe implémente la logique décrite dans `Exemple_ACL_Optimisee`.
class AdvancedAclGeneratorService {
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
    List<Map<String, String>> temporaryRules = const [],
  }) {
    // --- Étape 1: Création des groupes et pré-déclaration des tagOwners de base ---
    final groups = <String, List<String>>{};
    final tagOwners = <String, List<String>>{};

    for (var user in users) {
      final groupName = 'group:${user.name}';
      groups[groupName] = [user.name];

      // Pré-déclare le tag de base pour chaque utilisateur pour éviter les erreurs de validation
      // si un utilisateur n'a pas encore de nœuds.
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
        // Assurez-vous que l'utilisateur est propriétaire de ses tags composites
        if (!tagOwners.containsKey(tag)) {
          tagOwners[tag] = [];
        }
        if (!tagOwners[tag]!.contains(groupName)) {
          tagOwners[tag]!.add(groupName);
        }

        // Si le tag indique un partage de sous-réseau
        if (tag.contains(';lan-sharer')) {
          for (var route in node.sharedRoutes) {
            final routesMap = autoApprovers['routes'] as Map<String, List<String>>;
            if (!routesMap.containsKey(route)) {
              routesMap[route] = [];
            }
            if (!routesMap[route]!.contains(tag)) {
              routesMap[route]!.add(tag);
            }
          }
        }

        // Si le tag indique un exit node
        if (tag.contains(';exit-node')) {
          final exitNodesList = autoApprovers['exitNodes'] as List<String>;
          if (!exitNodesList.contains(tag)) {
            exitNodesList.add(tag);
          }
        }
      }
    }

    // --- Étape 3: Construction des règles ACL (Logique Complète et Corrigée) ---
    final acls = <Map<String, dynamic>>[];

    // 3.1: Ajouter les règles d'exception manuelles (tag-à-tag)
    for (var rule in temporaryRules) {
      final src = rule['src'];
      final dst = rule['dst'];
      if (src != null && dst != null) {
        acls.add({'action': 'accept', 'src': [src], 'dst': ['$dst:*']});
        acls.add({'action': 'accept', 'src': [dst], 'dst': ['$src:*']});
      }
    }

    // 3.2: Construire les règles de base et de service pour chaque utilisateur
    final tagsByUser = <String, Set<String>>{};
    for (var node in nodes) {
      tagsByUser.putIfAbsent(node.user, () => <String>{}).addAll(node.tags);
    }

    for (var user in users) {
      final groupName = 'group:${user.name}';
      final userTags = tagsByUser[user.name] ?? {};
      if (userTags.isEmpty) continue; // Skip users with no tagged nodes

      // Règle FONDAMENTALE: Gère la communication intra-utilisateur et l'accès aux services (Internet/subnets).
      final allExitNodeTags = (autoApprovers['exitNodes'] as List<String>).toSet();
      final destinations = userTags.map((tag) => '$tag:*').toSet();
      final userHasExitNode = userTags.any((tag) => allExitNodeTags.contains(tag));

      // Si l'utilisateur possède un exit node, ses nœuds peuvent accéder à internet.
      if (userHasExitNode) {
        destinations.add('autogroup:internet:*');
      }

      // Ajoute les subnets partagés par l'utilisateur aux destinations
      final userOwnedNodes = nodes.where((node) => node.user == user.name);
      for (var node in userOwnedNodes) {
        for (var route in node.sharedRoutes) {
          // Exclure les routes de sortie qui sont déjà gérées par autogroup:internet
          if (route != '0.0.0.0/0' && route != '::/0') {
            destinations.add('$route:*');
          }
        }
      }

      acls.add({
        'action': 'accept',
        'src': userTags.toList(),
        'dst': destinations.toList()..sort(), // sort() pour un ordre déterministe
      });

      // --- Les règles suivantes, basées sur le 'group', restent utiles pour ---
      // --- l'accès depuis l'extérieur du tailnet (ex: client mobile, web UI) ---

      final userName = normalizeUserName(user.name);
      final baseTag = 'tag:$userName-client';

      // Règle 1: Chaque utilisateur a accès à tous ses propres nœuds.
      // Note: Cette règle est maintenant partiellement redondante avec la règle fondamentale,
      // mais nous la gardons pour la cohérence avec l'exemple et l'accès "user-based".
      acls.add({
        'action': 'accept',
        'src': [groupName],
        'dst': ['$baseTag:*'],
      });

      final userNodes = nodes.where((node) => node.user == user.name).toList();

      // Règle 2: Chaque utilisateur peut utiliser son propre nœud de sortie.
      final userExitNodeTags = userNodes
          .expand((node) => node.tags)
          .where((tag) => tag.contains(';exit-node'))
          .toSet()
          .toList();

      if (userExitNodeTags.isNotEmpty) {
        acls.add({
          'action': 'accept',
          'src': [groupName],
          'dst': userExitNodeTags.map((tag) => '$tag:*').toList(),
        });
      }

      // Règle 3: Chaque utilisateur a accès à son propre réseau local partagé.
      final userLanSharerNodes = userNodes
          .where((node) => node.tags.any((tag) => tag.contains(';lan-sharer')))
          .toList();

      for (var node in userLanSharerNodes) {
        final lanSharerTag = node.tags.firstWhere(
          (t) => t.contains(';lan-sharer'),
          orElse: () => '',
        );

        if (lanSharerTag.isNotEmpty) {
          // Filtrer les routes pour exclure les routes de sortie (exit-node)
          final nonExitRoutes = node.sharedRoutes
              .where((r) => r != '0.0.0.0/0' && r != '::/0');

          for (var route in nonExitRoutes) {
            // Créer le tag composite spécifique à la route
            final routeSpecificTag = '$lanSharerTag:$route';

            // ÉTAPE CRUCIALE MANQUANTE: Déclarer ce nouveau tag dans tagOwners
            if (!tagOwners.containsKey(routeSpecificTag)) {
              tagOwners[routeSpecificTag] = [];
            }
            if (!tagOwners[routeSpecificTag]!.contains(groupName)) {
              tagOwners[routeSpecificTag]!.add(groupName);
            }

            // Utiliser le tag composite dans la règle ACL
            acls.add({
              'action': 'accept',
              'src': [groupName],
              'dst': ['$routeSpecificTag:*'],
            });
          }
        }
      }
    }

    // Règle 4: (Supprimée) L'accès à Internet est maintenant géré par la règle fondamentale
    // pour chaque utilisateur possédant un exit-node.


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
