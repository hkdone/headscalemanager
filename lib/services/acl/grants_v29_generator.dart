import 'package:flutter/foundation.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Générateur ACL Headscale 0.29+ basé sur les grants avec routage `via`.
///
/// Requiert le format de tags Standard (séparés). Isolation par utilisateur
/// avec routage explicite pour exit nodes et sous-réseaux LAN partagés.
class GrantsV29GeneratorService {
  Map<String, dynamic> generatePolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
  }) {
    final infra = PolicyInfrastructureBuilder.buildStandard(
      users: users,
      nodes: nodes,
    );

    final tagOwners = infra.tagOwners;
    final acls = _buildTemporaryRuleAcls(temporaryRules);
    final grants = <Map<String, dynamic>>[];

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      final normalizedUser = normalizeUserName(user.name);

      final stdClientTag = 'tag:$normalizedUser-client';
      final stdExitTag = 'tag:$normalizedUser-exit-node';
      final stdLanTag = 'tag:$normalizedUser-lan-sharer';

      final userNodes = nodes
          .where((node) =>
              node.user == user.name ||
              node.getNormalizedOwner() == normalizedUser)
          .toList();

      final activeUserTags = <String>{};
      var hasActiveExitNodes = false;
      String? activeExitTag;
      String? activeLanTag;

      for (var n in userNodes) {
        if (n.tags.contains(stdClientTag)) activeUserTags.add(stdClientTag);
        if (n.tags.contains(stdExitTag)) {
          activeUserTags.add(stdExitTag);
          hasActiveExitNodes = true;
          activeExitTag ??= stdExitTag;
        } else if (n.isExitNode) {
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

      if (activeUserTags.isEmpty) continue;

      final sortedTags = activeUserTags.toList()..sort();

      // Communication intra-flotte (directe, sans via)
      grants.add({
        'src': sortedTags,
        'dst': sortedTags,
        'ip': ['*'],
      });

      // Internet via exit node dédié
      if (hasActiveExitNodes && activeExitTag != null) {
        grants.add({
          'src': sortedTags,
          'dst': ['autogroup:internet'],
          'via': [activeExitTag],
          'ip': ['*'],
        });
      }

      // Routes LAN via subnet router dédié (isolation multi-utilisateurs même CIDR)
      final lanRoutes = <String>{};
      for (var node in userNodes) {
        for (var route in node.sharedRoutes) {
          if (route != '0.0.0.0/0' && route != '::/0') {
            lanRoutes.add(route);
          }
        }
      }

      if (activeLanTag != null) {
        for (var route in lanRoutes) {
          grants.add({
            'src': sortedTags,
            'dst': [route],
            'via': [activeLanTag],
            'ip': ['*'],
          });
        }
      }

      // Accès groupe → flotte (SSH / gestion)
      grants.add({
        'src': [groupName],
        'dst': sortedTags,
        'ip': ['*'],
      });

      debugPrint(
          'DEBUG GrantsV29: user $normalizedUser tags=$sortedTags exit=$activeExitTag lan=$activeLanTag routes=$lanRoutes');
    }

    // Fusion grants réseau + Taildrive
    final taildriveConfig = TaildriveBuilder.build(
      shares: taildriveShares,
      nodes: nodes,
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
      'hosts': <String, dynamic>{},
    };

    final nodeAttrs =
        taildriveConfig?['nodeAttrs'] as List<Map<String, dynamic>>?;
    if (nodeAttrs != null && nodeAttrs.isNotEmpty) {
      policy['nodeAttrs'] = nodeAttrs;
    }

    return policy;
  }

  List<Map<String, dynamic>> _buildTemporaryRuleAcls(
      List<Map<String, dynamic>> temporaryRules) {
    final acls = <Map<String, dynamic>>[];

    for (var rule in temporaryRules) {
      final src = rule['src'] as String?;
      final dst = rule['dst'] as String?;
      final port = rule['port'] as String?;
      final proto = rule['proto'] as String? ?? 'any';

      if (src == null || dst == null) continue;
      final dstPort = (port != null && port.isNotEmpty) ? ':$port' : ':*';

      final ruleMap = <String, dynamic>{
        'action': 'accept',
        'src': [src],
      };

      if (proto != 'any') {
        ruleMap['proto'] = proto;
      }

      if (dst.startsWith('tag:')) {
        acls.add({...ruleMap, 'dst': ['$dst$dstPort']});
        final reverseRuleMap = <String, dynamic>{
          'action': 'accept',
          'src': [dst],
          'dst': ['$src$dstPort'],
        };
        if (proto != 'any') reverseRuleMap['proto'] = proto;
        acls.add(reverseRuleMap);
      } else {
        final destinations = dst
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .map((d) => '$d$dstPort')
            .toList();
        if (destinations.isNotEmpty) {
          acls.add({...ruleMap, 'dst': destinations});
        }
      }
    }

    return acls;
  }
}
