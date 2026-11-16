import 'package:flutter/foundation.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// STANDARD ACL GENERATOR (New Engine)
///
/// This service generates Headscale ACL policies using standard, separate tags for each capability.
/// Unlike the legacy engine, it does NOT support merged tags (e.g., 'tag:user;exit-node').
///
/// Expected Tag Format:
/// - Identity: 'tag:username-client'
/// - Capabilities: 'tag:username-exit-node', 'tag:username-lan-sharer'
class StandardAclGeneratorService {
  /// Generates an optimized Headscale ACL policy using standard tags.
  Map<String, dynamic> generatePolicy({
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
  }) {
    // --- Step 1: Groups & Tag Owners ---
    final groups = <String, List<String>>{};
    final tagOwners = <String, List<String>>{};

    final fallbackDomain =
        nodes.isNotEmpty ? nodes.first.baseDomain : 'headscale.local';

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      groups[groupName] = resolveAclGroupMembers(
        user.name,
        email: user.email,
        fallbackDomain: fallbackDomain,
      );

      final normalizedNames = <String>{normalizeUserName(user.name)};
      if (user.email != null && user.email!.isNotEmpty) {
        normalizedNames.add(normalizeUserName(user.email!));
      }
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        normalizedNames.add(normalizeUserName(user.displayName!));
      }

      final owners = <String>{groupName};
      if (user.email != null && user.email!.contains('@')) {
        owners.add(user.email!);
      } else if (user.name.contains('@')) {
        owners.add(user.name);
      }

      for (final norm in normalizedNames) {
        for (final owner in owners) {
          _addTagOwner(tagOwners, 'tag:$norm-client', owner);
          _addTagOwner(tagOwners, 'tag:$norm-exit-node', owner);
          _addTagOwner(tagOwners, 'tag:$norm-lan-sharer', owner);
        }
      }
    }

    // --- Step 2: AutoApprovers (Routes) ---
    final autoApprovers = {
      'routes': <String, List<String>>{},
    };

    for (var node in nodes) {
      final normalizedUser = node.getNormalizedOwner();
      final stdExit = 'tag:$normalizedUser-exit-node';
      final stdLan = 'tag:$normalizedUser-lan-sharer';

      String? actualExitTag;
      if (node.tags.contains(stdExit)) {
        actualExitTag = stdExit;
      } else {
        // Find legacy exit node tag
        final legacy = node.tags
            .firstWhere((t) => t.contains(';exit-node'), orElse: () => '');
        if (legacy.isNotEmpty) actualExitTag = legacy;
      }

      String? actualLanTag;
      if (node.tags.contains(stdLan)) {
        actualLanTag = stdLan;
      } else {
        // Find legacy lan sharer tag
        final legacy = node.tags
            .firstWhere((t) => t.contains(';lan-sharer'), orElse: () => '');
        if (legacy.isNotEmpty) actualLanTag = legacy;
      }

      if (actualExitTag != null || actualLanTag != null) {
        for (var route in node.sharedRoutes) {
          final routesMap =
              autoApprovers['routes'] as Map<String, List<String>>;
          if (!routesMap.containsKey(route)) {
            routesMap[route] = [];
          }

          if (actualExitTag != null &&
              (route == '0.0.0.0/0' || route == '::/0')) {
            if (!routesMap[route]!.contains(actualExitTag)) {
              routesMap[route]!.add(actualExitTag);
            }
          } else if (actualLanTag != null &&
              route != '0.0.0.0/0' &&
              route != '::/0') {
            if (!routesMap[route]!.contains(actualLanTag)) {
              routesMap[route]!.add(actualLanTag);
            }
          }
        }
      }
    }

    // --- Step 3: ACL Rules construction ---
    final acls = <Map<String, dynamic>>[];

    // 3.1: Temporary Rules (Manual Puzzles)
    // Same logic as before, just passed through
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
        acls.add({
          ...ruleMap,
          'dst': ['$dst$dstPort']
        });

        final reverseRuleMap = <String, dynamic>{
          'action': 'accept',
          'src': [dst],
          'dst': ['$src$dstPort']
        };
        if (proto != 'any') {
          reverseRuleMap['proto'] = proto;
        }

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

    // 3.2: Base User Rules
    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      final normalizedUser = normalizeUserName(user.name);
      final candidateNorms =
          PolicyInfrastructureBuilder.candidateNormalizedNames(user);
      debugPrint('DEBUG: Processing user $normalizedUser');

      final userNodes = nodes
          .where((node) =>
              PolicyInfrastructureBuilder.nodeBelongsToUser(node, user))
          .toList();

      final activeUserTags = <String>{};
      bool hasActiveExitNodes = false;

      // Collect ALL valid tags from user nodes across OIDC candidate slugs
      for (var n in userNodes) {
        for (final norm in candidateNorms) {
          final stdClientTag = 'tag:$norm-client';
          final stdExitTag = 'tag:$norm-exit-node';
          final stdLanTag = 'tag:$norm-lan-sharer';

          if (n.tags.contains(stdClientTag)) activeUserTags.add(stdClientTag);
          if (n.tags.contains(stdExitTag)) {
            activeUserTags.add(stdExitTag);
            hasActiveExitNodes = true;
          } else if (n.isExitNode) {
            hasActiveExitNodes = true;
          }

          if (n.tags.contains(stdLanTag)) activeUserTags.add(stdLanTag);

          for (var t in n.tags) {
            if (t.startsWith(stdClientTag)) {
              activeUserTags.add(t);
              _addTagOwner(tagOwners, t, groupName);

              if (t.contains(';exit-node')) hasActiveExitNodes = true;
            } else if (t.contains(';exit-node')) {
              activeUserTags.add(t);
              _addTagOwner(tagOwners, t, groupName);

              hasActiveExitNodes = true;
            }
          }
        }
      }

      if (activeUserTags.isEmpty) {
        if (userNodes.isEmpty) continue;
        final destinations = <String>{'$groupName:*'};
        if (hasActiveExitNodes) destinations.add('autogroup:internet:*');
        for (var node in userNodes) {
          for (var route in node.sharedRoutes) {
            if (route != '0.0.0.0/0' && route != '::/0') {
              destinations.add('$route:*');
            }
          }
        }
        acls.add({
          'action': 'accept',
          'src': [groupName],
          'dst': destinations.toList()..sort(),
        });
        continue;
      }

      // Define Destinations
      final destinations = <String>{};

      // Allow access to own fleet matches
      for (var tag in activeUserTags) {
        destinations.add('$tag:*');
      }

      // If user has exit nodes, allow internet access for his fleet
      if (hasActiveExitNodes) {
        destinations.add('autogroup:internet:*');
      }

      // Add specific LAN routes shared by own nodes
      for (var node in userNodes) {
        // Fix: Check routes irrespective of tags
        // If the node shares routes, we should add them.
        for (var route in node.sharedRoutes) {
          if (route != '0.0.0.0/0' && route != '::/0') {
            destinations.add('$route:*');
          }
        }
      }

      // Main Intra-User Rule
      acls.add({
        'action': 'accept',
        'src': activeUserTags.toList()..sort(),
        'dst': destinations.toList()..sort(),
      });

      debugPrint(
          'DEBUG: Done user $normalizedUser. ActiveTags: $activeUserTags. ExitNode: $hasActiveExitNodes. Dest: $destinations');

      // Allow User (Group) to access his own devices (SSH/Management)
      // Access to ALL currently active tags
      acls.add({
        'action': 'accept',
        'src': [groupName],
        'dst': activeUserTags.map((t) => '$t:*').toList()..sort()
      });
    }

    // --- Step 4 & 5: Final Assembly (+ Taildrive if >= 0.29) ---
    final policy = {
      'groups': groups,
      'tagOwners': tagOwners,
      'autoApprovers': autoApprovers,
      'acls': acls,
      'hosts': <String, dynamic>{},
    };

    TaildriveBuilder.mergeIntoPolicy(
      policy,
      shares: taildriveShares,
      nodes: nodes,
      serverVersion: serverVersion,
    );

    return policy;
  }

  void _addTagOwner(
      Map<String, List<String>> tagOwners, String tag, String owner) {
    if (!owner.startsWith('group:') &&
        !owner.startsWith('autogroup:') &&
        !owner.contains('@')) {
      return;
    }
    if (!tagOwners.containsKey(tag)) {
      tagOwners[tag] = [];
    }
    if (!tagOwners[tag]!.contains(owner)) {
      tagOwners[tag]!.add(owner);
    }
  }
}
