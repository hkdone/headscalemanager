import 'package:flutter/foundation.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// STANDARD ACL GENERATOR (New Engine)
///
/// This service generates Headscale ACL policies using standard, separate tags for each capability.
/// Unlike the legacy engine, it does NOT support merged tags (e.g., 'tag:user;exit-node').
///
/// Supports hybrid fleets (tagged devices + untagged devices via `group:<user>`).
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
    bool includeUntaggedNodes = true,
  }) {
    // --- Step 1 & 2: Groups, Tag Owners, Hybrid AutoApprovers & Managed Hosts ---
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
    final groups = infra.groups;
    final tagOwners = infra.tagOwners;
    final autoApprovers = infra.autoApprovers;

    // --- Step 3: ACL Rules construction ---
    // 3.1: Temporary Rules (Manual Puzzles)
    final acls = PolicyPreserver.compileTemporaryRulesToAcls(temporaryRules);

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
      if (userNodes.isEmpty) continue;

      final activeUserTags = <String>{};
      bool hasActiveExitNodes = false;

      // Collect ALL valid tags from user nodes across OIDC candidate slugs
      for (var n in userNodes) {
        if (n.tags.isEmpty && n.isExitNode) {
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
          } else if (n.isExitNode) {
            hasActiveExitNodes = true;
          }

          if (n.tags.contains(stdLanTag)) activeUserTags.add(stdLanTag);

          for (var t in n.tags) {
            if (t.startsWith(stdClientTag)) {
              activeUserTags.add(t);
              PolicyInfrastructureBuilder.registerLegacyTagOwners(
                tagOwners: tagOwners,
                groupName: groupName,
                tags: [t],
                stdClientTag: stdClientTag,
              );

              if (t.contains(';exit-node')) hasActiveExitNodes = true;
            } else if (t.contains(';exit-node')) {
              activeUserTags.add(t);
              PolicyInfrastructureBuilder.registerLegacyTagOwners(
                tagOwners: tagOwners,
                groupName: groupName,
                tags: [t],
                stdClientTag: stdClientTag,
              );

              hasActiveExitNodes = true;
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
      }.toList()
        ..sort();

      if (fleetSubjects.isEmpty) continue;

      // Define Destinations
      final destinations = <String>{};
      for (final subject in fleetSubjects) {
        destinations.add('$subject:*');
      }

      // If user has exit nodes, allow internet access for his fleet
      if (hasActiveExitNodes) {
        destinations.add('autogroup:internet:*');
      }

      // Add specific LAN routes shared by own nodes
      for (var node in userNodes) {
        for (var route in node.sharedRoutes) {
          if (route != '0.0.0.0/0' && route != '::/0') {
            destinations.add('$route:*');
          }
        }
      }

      // Main Intra-User Rule (Hybride : tags + group:<user> si nœuds sans tag)
      acls.add({
        'action': 'accept',
        'src': fleetSubjects,
        'dst': destinations.toList()..sort(),
      });

      debugPrint(
          'DEBUG: Done user $normalizedUser. Subjects: $fleetSubjects. ExitNode: $hasActiveExitNodes. Dest: $destinations');

      // Allow User (Group) to access his own tagged devices (SSH/Management)
      // when all nodes are tagged (100 % non-regression).
      if (sortedTags.isNotEmpty && !includeGroupInFleet) {
        acls.add({
          'action': 'accept',
          'src': [groupName],
          'dst': sortedTags.map((t) => '$t:*').toList()..sort(),
        });
      }
    }

    // --- Step 4 & 5: Final Assembly (+ Taildrive if >= 0.29) ---
    final policy = {
      'groups': groups,
      'tagOwners': tagOwners,
      'autoApprovers': autoApprovers,
      'acls': acls,
      'hosts': managedHosts,
    };

    TaildriveBuilder.mergeIntoPolicy(
      policy,
      shares: taildriveShares,
      nodes: nodes,
      users: users,
      serverVersion: serverVersion,
    );

    return policy;
  }
}
