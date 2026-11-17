import 'package:flutter/foundation.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Générateur ACL Headscale 0.29+ basé sur les grants avec routage `via`.
///
/// Requiert le format de tags Standard (séparés). Isolation par utilisateur
/// avec routage explicite pour exit nodes et sous-réseaux LAN partagés,
/// et union hybride automatique avec `group:<user>` dès qu'un nœud sans tag
/// appartient à la flotte.
class GrantsV29GeneratorService {
  Map<String, dynamic> generatePolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
    bool includeUntaggedNodes = true,
  }) {
    final infra = PolicyInfrastructureBuilder.buildStandard(
      users: users,
      nodes: nodes,
      includeUntaggedNodes: includeUntaggedNodes,
    );
    final managedHosts = PolicyInfrastructureBuilder.buildManagedHosts(
      users: users,
      nodes: nodes,
      includeUntaggedNodes: includeUntaggedNodes,
    );

    final tagOwners = infra.tagOwners;
    final acls = PolicyPreserver.compileTemporaryRulesToAcls(temporaryRules);
    final grants = <Map<String, dynamic>>[];

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      final normalizedUser = normalizeUserName(user.name);
      final candidateNorms =
          PolicyInfrastructureBuilder.candidateNormalizedNames(user);

      final userNodes = nodes
          .where((node) =>
              PolicyInfrastructureBuilder.nodeBelongsToUser(node, user))
          .toList();
      if (userNodes.isEmpty) continue;

      final activeUserTags = <String>{};
      var hasActiveExitNodes = false;
      var hasUntaggedExitNode = false;
      String? activeExitTag;
      String? activeLanTag;

      for (var n in userNodes) {
        if (n.tags.isEmpty && n.isExitNode) {
          hasUntaggedExitNode = true;
          hasActiveExitNodes = true;
        }
        for (final norm in candidateNorms) {
          final stdClientTag = 'tag:$norm-client';
          final stdExitTag = 'tag:$norm-exit-node';
          final stdLanTag = 'tag:$norm-lan-sharer';

          if (n.tags.contains(stdClientTag)) activeUserTags.add(stdClientTag);
          if (n.tags.contains(stdExitTag)) {
            activeUserTags.add(stdExitTag);
            hasActiveExitNodes = true;
            activeExitTag ??= stdExitTag;
          } else if (n.tags.isNotEmpty && n.isExitNode) {
            hasActiveExitNodes = true;
          }
          if (n.tags.contains(stdLanTag)) {
            activeUserTags.add(stdLanTag);
            activeLanTag ??= stdLanTag;
          }

          for (var t in n.tags) {
            if (t.startsWith(stdClientTag)) {
              activeUserTags.add(t);
              PolicyInfrastructureBuilder.registerLegacyTagOwners(
                tagOwners: tagOwners,
                groupName: groupName,
                tags: [t],
                stdClientTag: stdClientTag,
              );
              if (t.contains(';exit-node')) {
                hasActiveExitNodes = true;
                activeExitTag ??= t;
              }
              if (t.contains(';lan-sharer')) {
                activeLanTag ??= t;
              }
            } else if (t.contains(';exit-node')) {
              activeUserTags.add(t);
              PolicyInfrastructureBuilder.registerLegacyTagOwners(
                tagOwners: tagOwners,
                groupName: groupName,
                tags: [t],
                stdClientTag: stdClientTag,
              );
              hasActiveExitNodes = true;
              activeExitTag ??= t;
            } else if (t.contains(';lan-sharer')) {
              activeUserTags.add(t);
              activeLanTag ??= t;
            }
          }
        }
      }

      final sortedTags = activeUserTags.toList()..sort();
      final hasUntaggedNodes = userNodes.any((n) => n.tags.isEmpty);
      final includeGroupInFleet = includeUntaggedNodes && hasUntaggedNodes;
      final fleetSubjects = <String>{
        ...sortedTags,
        if (includeGroupInFleet) groupName,
      }.toList();

      // Si l'utilisateur n'a que des nœuds sans tags et que la quarantaine est active
      if (fleetSubjects.isEmpty) continue;

      // Communication intra-flotte (hybride : tags + group si nœuds sans tag)
      grants.add({
        'src': fleetSubjects,
        'dst': fleetSubjects,
        'ip': ['*'],
      });

      // Internet via exit node tagué (avec via)
      if (hasActiveExitNodes && activeExitTag != null) {
        grants.add({
          'src': fleetSubjects,
          'dst': ['autogroup:internet'],
          'via': [activeExitTag],
          'ip': ['*'],
        });
      }

      // Internet via exit node sans tag (direct sans via : 0.29 interdit les groupes dans via)
      if (hasUntaggedExitNode && includeUntaggedNodes) {
        grants.add({
          'src': fleetSubjects,
          'dst': ['autogroup:internet'],
          'ip': ['*'],
        });
      }

      // Routes LAN partagées : avec `via` pour les routeurs tagués, direct pour ceux sans tag
      final taggedLanRoutes = <String>{};
      final untaggedLanRoutes = <String>{};
      for (var node in userNodes) {
        for (var route in node.sharedRoutes) {
          if (route != '0.0.0.0/0' && route != '::/0') {
            if (node.tags.isEmpty) {
              untaggedLanRoutes.add(route);
            } else {
              taggedLanRoutes.add(route);
            }
          }
        }
      }

      if (activeLanTag != null) {
        for (var route in taggedLanRoutes) {
          grants.add({
            'src': fleetSubjects,
            'dst': [route],
            'via': [activeLanTag],
            'ip': ['*'],
          });
        }
      }
      if (includeUntaggedNodes) {
        for (var route in untaggedLanRoutes) {
          grants.add({
            'src': fleetSubjects,
            'dst': [route],
            'ip': ['*'],
          });
        }
      }

      // Accès groupe → flotte (SSH / gestion) pour parc 100 % tagué
      if (sortedTags.isNotEmpty && !includeGroupInFleet) {
        grants.add({
          'src': [groupName],
          'dst': sortedTags,
          'ip': ['*'],
        });
      }

      debugPrint(
          'DEBUG GrantsV29: user $normalizedUser subjects=$fleetSubjects exit=$activeExitTag untaggedExit=$hasUntaggedExitNode lan=$activeLanTag taggedRoutes=$taggedLanRoutes untaggedRoutes=$untaggedLanRoutes');
    }

    // Fusion grants réseau + Taildrive
    final taildriveConfig = TaildriveBuilder.build(
      shares: taildriveShares,
      nodes: nodes,
      users: users,
      serverVersion: serverVersion,
    );
    if (taildriveConfig != null) {
      final taildriveGrants =
          taildriveConfig['grants'] as List<Map<String, dynamic>>? ?? [];
      grants.addAll(taildriveGrants);
    }

    final policy = {
      'groups': infra.groups,
      'tagOwners': tagOwners,
      'autoApprovers': infra.autoApprovers,
      'acls': acls,
      'grants': grants,
      'hosts': managedHosts,
    };

    final nodeAttrs =
        taildriveConfig?['nodeAttrs'] as List<Map<String, dynamic>>?;
    if (nodeAttrs != null && nodeAttrs.isNotEmpty) {
      policy['nodeAttrs'] = nodeAttrs;
    }

    return policy;
  }
}
