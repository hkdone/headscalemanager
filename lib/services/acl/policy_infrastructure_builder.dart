import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Construit groups, tagOwners et autoApprovers (format Standard).
class PolicyInfrastructureBuilder {
  /// Tous les identifiants normalisés possibles pour un utilisateur (nom, email OIDC, displayName).
  static Set<String> candidateNormalizedNames(User user) {
    final names = <String>{normalizeUserName(user.name)};
    if (user.email != null && user.email!.trim().isNotEmpty) {
      names.add(normalizeUserName(user.email!.trim()));
    }
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      names.add(normalizeUserName(user.displayName!.trim()));
    }
    return names;
  }

  /// Indique si [node] appartient à [user] (y compris comptes OIDC avec
  /// nom/email/displayName distincts ou machines taguées sous `tagged-devices`).
  static bool nodeBelongsToUser(Node node, User user) {
    if (node.userId.isNotEmpty &&
        user.id.isNotEmpty &&
        node.userId == user.id) {
      return true;
    }
    if (node.user == user.name) return true;
    if (user.email != null &&
        user.email!.isNotEmpty &&
        node.user == user.email) {
      return true;
    }
    if (user.displayName != null &&
        user.displayName!.isNotEmpty &&
        node.user == user.displayName) {
      return true;
    }
    final candidates = candidateNormalizedNames(user);
    if (candidates.contains(node.getNormalizedOwner())) return true;
    for (final norm in candidates) {
      for (final t in node.tags) {
        if (t == 'tag:$norm-client' ||
            t == 'tag:$norm-exit-node' ||
            t == 'tag:$norm-lan-sharer' ||
            t.startsWith('tag:$norm-client;')) {
          return true;
        }
      }
    }
    return false;
  }

  static ({
    Map<String, List<String>> groups,
    Map<String, List<String>> tagOwners,
    Map<String, dynamic> autoApprovers,
  }) buildStandard({
    required List<User> users,
    required List<Node> nodes,
  }) {
    final groups = <String, List<String>>{};
    final tagOwners = <String, List<String>>{};
    final autoApprovers = {
      'routes': <String, List<String>>{},
    };

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

    for (var node in nodes) {
      final normalizedUser = node.getNormalizedOwner();
      final stdExit = 'tag:$normalizedUser-exit-node';
      final stdLan = 'tag:$normalizedUser-lan-sharer';

      String? actualExitTag;
      if (node.tags.contains(stdExit)) {
        actualExitTag = stdExit;
      } else {
        final legacy = node.tags
            .firstWhere((t) => t.contains(';exit-node'), orElse: () => '');
        if (legacy.isNotEmpty) actualExitTag = legacy;
      }

      String? actualLanTag;
      if (node.tags.contains(stdLan)) {
        actualLanTag = stdLan;
      } else {
        final legacy = node.tags
            .firstWhere((t) => t.contains(';lan-sharer'), orElse: () => '');
        if (legacy.isNotEmpty) actualLanTag = legacy;
      }

      if (actualExitTag != null || actualLanTag != null) {
        for (var route in node.sharedRoutes) {
          final routesMap =
              autoApprovers['routes'] as Map<String, List<String>>;
          routesMap.putIfAbsent(route, () => []);

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

    return (
      groups: groups,
      tagOwners: tagOwners,
      autoApprovers: autoApprovers,
    );
  }

  static void registerLegacyTagOwners({
    required Map<String, List<String>> tagOwners,
    required String groupName,
    required Iterable<String> tags,
    required String stdClientTag,
  }) {
    for (var tag in tags) {
      if (tag.startsWith(stdClientTag) || tag.contains(';exit-node')) {
        _addTagOwner(tagOwners, tag, groupName);
      }
    }
  }

  static void _addTagOwner(
      Map<String, List<String>> tagOwners, String tag, String owner) {
    if (!owner.startsWith('group:') &&
        !owner.startsWith('autogroup:') &&
        !owner.contains('@')) {
      return;
    }
    tagOwners.putIfAbsent(tag, () => []);
    if (!tagOwners[tag]!.contains(owner)) {
      tagOwners[tag]!.add(owner);
    }
  }
}
