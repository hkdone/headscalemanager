import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Détecte et nettoie les groupes, tags et règles orphelins laissés dans une
/// politique JSON après la suppression d'utilisateurs ou de nœuds Headscale,
/// sans toucher aux groupes personnalisés contenant des membres actifs.
class PolicyOrphanCleaner {
  static ({
    Set<String> orphanGroups,
    Set<String> orphanTags,
    Set<String> orphanHosts,
    bool hasOrphanReferences,
  }) inspectOrphans(
    Map<String, dynamic> policy, {
    required List<User> users,
    required List<Node> nodes,
  }) {
    final activeUserNorms = _collectActiveUserNorms(users, nodes);
    final activeNodeTags = nodes.expand((n) => n.tags).toSet();
    final activeMemberEmails = _collectActiveMemberEmails(users);

    final orphanGroups = <String>{};
    final groups = policy['groups'];
    if (groups is Map) {
      for (final entry in groups.entries) {
        final groupName = entry.key.toString();
        if (!groupName.startsWith('group:')) continue;
        final slug = groupName.substring('group:'.length);
        if (activeUserNorms.contains(slug)) continue;

        final members = (entry.value is List)
            ? (entry.value as List).map((e) => e.toString().toLowerCase()).toList()
            : const <String>[];

        final hasActiveMember = members.any((m) {
          if (activeMemberEmails.contains(m)) return true;
          final localPart = m.contains('@') ? m.split('@').first : m;
          return activeUserNorms.contains(normalizeUserName(localPart)) ||
              activeUserNorms.contains(normalizeUserName(m));
        });

        if (!hasActiveMember) {
          orphanGroups.add(groupName);
        }
      }
    }

    final orphanTags = <String>{};
    void inspectTagCandidate(String rawTag) {
      if (!rawTag.startsWith('tag:')) return;
      if (activeNodeTags.contains(rawTag)) return;
      final slug = _extractManagedUserSlugFromTag(rawTag);
      if (slug != null && !activeUserNorms.contains(slug)) {
        orphanTags.add(rawTag);
      }
    }

    final tagOwners = policy['tagOwners'];
    if (tagOwners is Map) {
      for (final key in tagOwners.keys) {
        inspectTagCandidate(key.toString());
      }
    }

    final autoApprovers = policy['autoApprovers'];
    if (autoApprovers is Map && autoApprovers['routes'] is Map) {
      for (final approvers in (autoApprovers['routes'] as Map).values) {
        if (approvers is List) {
          for (final a in approvers) {
            inspectTagCandidate(a.toString());
          }
        }
      }
    }

    final orphanHosts = <String>{};
    final expectedManagedHosts = PolicyInfrastructureBuilder.buildManagedHosts(
      users: users,
      nodes: nodes,
    );
    final hostsMap = policy['hosts'];
    if (hostsMap is Map) {
      for (final rawKey in hostsMap.keys) {
        final key = rawKey.toString();
        if (key.startsWith('host-') &&
            !expectedManagedHosts.containsKey(key)) {
          orphanHosts.add(key);
        }
      }
    }

    bool checkList(dynamic rawList) {
      if (rawList is! List) return false;
      for (final item in rawList) {
        final str = item.toString();
        final base = _stripPortSuffix(str);
        inspectTagCandidate(base);
        if (orphanGroups.contains(base) ||
            orphanTags.contains(base) ||
            orphanHosts.contains(base)) {
          return true;
        }
      }
      return false;
    }

    var hasOrphanReferences = false;
    final acls = policy['acls'];
    if (acls is List) {
      for (final rule in acls) {
        if (rule is Map) {
          if (checkList(rule['src']) || checkList(rule['dst'])) {
            hasOrphanReferences = true;
          }
        }
      }
    }
    final grants = policy['grants'];
    if (grants is List) {
      for (final grant in grants) {
        if (grant is Map) {
          if (checkList(grant['src']) ||
              checkList(grant['dst']) ||
              checkList(grant['via'])) {
            hasOrphanReferences = true;
          }
        }
      }
    }

    if (orphanGroups.isNotEmpty ||
        orphanTags.isNotEmpty ||
        orphanHosts.isNotEmpty) {
      hasOrphanReferences = true;
    }

    return (
      orphanGroups: orphanGroups,
      orphanTags: orphanTags,
      orphanHosts: orphanHosts,
      hasOrphanReferences: hasOrphanReferences,
    );
  }

  /// Supprime les groupes, tags, alias `host-*` gérés, `autoApprovers`,
  /// `acls` et `grants` référençant des utilisateurs/nœuds supprimés.
  static Map<String, dynamic> cleanOrphans(
    Map<String, dynamic> policy, {
    required List<User> users,
    required List<Node> nodes,
  }) {
    final result = PolicyPreserver.deepCopyMap(policy);
    final info = inspectOrphans(result, users: users, nodes: nodes);
    if (info.orphanGroups.isEmpty &&
        info.orphanTags.isEmpty &&
        info.orphanHosts.isEmpty) {
      return result;
    }

    bool isOrphanRef(String value) {
      final base = _stripPortSuffix(value);
      return info.orphanGroups.contains(base) ||
          info.orphanTags.contains(base) ||
          info.orphanHosts.contains(base);
    }

    // 1. groups
    final groups = result['groups'];
    if (groups is Map) {
      for (final g in info.orphanGroups) {
        groups.remove(g);
      }
    }

    // 1b. hosts (uniquement les alias gérés host-*)
    final hosts = result['hosts'];
    if (hosts is Map) {
      for (final h in info.orphanHosts) {
        hosts.remove(h);
      }
    }

    // 2. tagOwners
    final tagOwners = result['tagOwners'];
    if (tagOwners is Map) {
      for (final t in info.orphanTags) {
        tagOwners.remove(t);
      }
      for (final key in tagOwners.keys.toList()) {
        final owners = tagOwners[key];
        if (owners is List) {
          owners.removeWhere((o) => info.orphanGroups.contains(o.toString()));
        }
      }
    }

    // 3. autoApprovers.routes
    final autoApprovers = result['autoApprovers'];
    if (autoApprovers is Map && autoApprovers['routes'] is Map) {
      final routes = autoApprovers['routes'] as Map;
      for (final cidr in routes.keys.toList()) {
        final list = routes[cidr];
        if (list is List) {
          list.removeWhere((item) => isOrphanRef(item.toString()));
          if (list.isEmpty) {
            routes.remove(cidr);
          }
        }
      }
    }

    // 4. acls
    final acls = result['acls'];
    if (acls is List) {
      acls.removeWhere((rule) {
        if (rule is! Map) return false;
        final src = rule['src'];
        final dst = rule['dst'];
        if (src is List) {
          src.removeWhere((item) => isOrphanRef(item.toString()));
        }
        if (dst is List) {
          dst.removeWhere((item) => isOrphanRef(item.toString()));
        }
        return (src is List && src.isEmpty) || (dst is List && dst.isEmpty);
      });
    }

    // 5. grants
    final grants = result['grants'];
    if (grants is List) {
      grants.removeWhere((grant) {
        if (grant is! Map) return false;
        final src = grant['src'];
        final dst = grant['dst'];
        final via = grant['via'];
        if (src is List) {
          src.removeWhere((item) => isOrphanRef(item.toString()));
        }
        if (dst is List) {
          dst.removeWhere((item) => isOrphanRef(item.toString()));
        }
        if (via is List) {
          via.removeWhere((item) => isOrphanRef(item.toString()));
          if (via.isEmpty) {
            grant.remove('via');
          }
        }
        return (src is List && src.isEmpty) || (dst is List && dst.isEmpty);
      });
    }

    return result;
  }

  static Set<String> _collectActiveUserNorms(
      List<User> users, List<Node> nodes) {
    final norms = <String>{};
    for (final u in users) {
      norms.add(normalizeUserName(u.name));
      if (u.email != null && u.email!.isNotEmpty) {
        norms.add(normalizeUserName(u.email!));
      }
      if (u.displayName != null && u.displayName!.isNotEmpty) {
        norms.add(normalizeUserName(u.displayName!));
      }
    }
    for (final n in nodes) {
      norms.add(n.getNormalizedOwner());
    }
    return norms;
  }

  static Set<String> _collectActiveMemberEmails(List<User> users) {
    final emails = <String>{};
    for (final u in users) {
      emails.add(u.name.toLowerCase());
      if (u.email != null && u.email!.isNotEmpty) {
        emails.add(u.email!.toLowerCase());
      }
    }
    return emails;
  }

  static String? _extractManagedUserSlugFromTag(String rawTag) {
    if (!rawTag.startsWith('tag:')) return null;
    final clean = rawTag.substring('tag:'.length).split(';').first;
    for (final suffix in const ['-client', '-exit-node', '-lan-sharer']) {
      if (clean.endsWith(suffix) && clean.length > suffix.length) {
        return clean.substring(0, clean.length - suffix.length);
      }
    }
    return null;
  }

  static String _stripPortSuffix(String value) {
    // Ex: tag:foo-client:* , group:foo:443 ou host-foo-pc:443
    if (value.startsWith('tag:') || value.startsWith('group:')) {
      final colonIdx = value.indexOf(':', 4);
      if (colonIdx != -1) {
        return value.substring(0, colonIdx);
      }
    } else if (value.startsWith('host-')) {
      final colonIdx = value.indexOf(':');
      if (colonIdx != -1) {
        return value.substring(0, colonIdx);
      }
    }
    return value;
  }
}
