import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Construit groups, tagOwners et autoApprovers (format Standard).
class PolicyInfrastructureBuilder {
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

    for (var user in users) {
      final groupName = 'group:${normalizeUserName(user.name)}';
      groups[groupName] = [user.name];

      final normalizedUser = normalizeUserName(user.name);
      _addTagOwner(tagOwners, 'tag:$normalizedUser-client', groupName);
      _addTagOwner(tagOwners, 'tag:$normalizedUser-exit-node', groupName);
      _addTagOwner(tagOwners, 'tag:$normalizedUser-lan-sharer', groupName);
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
    tagOwners.putIfAbsent(tag, () => []);
    if (!tagOwners[tag]!.contains(owner)) {
      tagOwners[tag]!.add(owner);
    }
  }
}
