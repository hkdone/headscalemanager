import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart';

enum GrantComposerTemplate {
  lanAccess,
  internetExit,
  intraFleet,
  targetedIp,
  exceptionAcl,
}

class GrantComposerOption {
  final String value;
  final String label;
  final String? subtitle;

  const GrantComposerOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

class RouterNodeOption {
  final Node node;
  final String viaTag;
  final String roleLabel;

  const RouterNodeOption({
    required this.node,
    required this.viaTag,
    required this.roleLabel,
  });
}

/// Construit et fusionne des grants réseau pour le composeur v2.1.
class GrantComposerService {
  static String clientTagForUser(String userName) =>
      'tag:${normalizeUserName(userName)}-client';

  static String lanSharerTagForUser(String userName) =>
      'tag:${normalizeUserName(userName)}-lan-sharer';

  static String exitNodeTagForUser(String userName) =>
      'tag:${normalizeUserName(userName)}-exit-node';

  static List<GrantComposerOption> sourceTagOptions({
    required List<User> users,
    required List<Node> nodes,
  }) {
    final options = <GrantComposerOption>[];
    for (var user in users) {
      final norm = normalizeUserName(user.name);
      final clientTag = clientTagForUser(user.name);
      final hasTag = nodes.any((n) =>
          (n.user == user.name || n.getNormalizedOwner() == norm) &&
          n.tags.contains(clientTag));
      if (hasTag) {
        options.add(GrantComposerOption(
          value: clientTag,
          label: clientTag,
          subtitle: user.name,
        ));
      }
    }
    return options;
  }

  static List<RouterNodeOption> routerOptions({
    required List<Node> nodes,
    required bool forExit,
  }) {
    final result = <RouterNodeOption>[];
    for (var node in nodes) {
      final norm = node.getNormalizedOwner();
      final stdLan = lanSharerTagForUser(norm);
      final stdExit = exitNodeTagForUser(norm);

      if (forExit) {
        String? viaTag;
        if (node.tags.contains(stdExit)) {
          viaTag = stdExit;
        } else {
          for (var t in node.tags) {
            if (t.contains(';exit-node')) {
              viaTag = t;
              break;
            }
          }
        }
        if (viaTag != null && node.isExitNode) {
          result.add(RouterNodeOption(
            node: node,
            viaTag: viaTag,
            roleLabel: 'Exit',
          ));
        }
      } else {
        String? viaTag;
        if (node.tags.contains(stdLan)) {
          viaTag = stdLan;
        } else {
          for (var t in node.tags) {
            if (t.contains(';lan-sharer')) {
              viaTag = t;
              break;
            }
          }
        }
        final hasLanRoute = node.sharedRoutes.any(
          (r) => r != '0.0.0.0/0' && r != '::/0',
        );
        if (viaTag != null && hasLanRoute) {
          result.add(RouterNodeOption(
            node: node,
            viaTag: viaTag,
            roleLabel: 'LAN',
          ));
        }
      }
    }
    return result;
  }

  static List<GrantComposerOption> destinationOptions({
    required List<Node> nodes,
    required GrantComposerTemplate template,
    String? restrictToOwnerNorm,
  }) {
    final options = <GrantComposerOption>[];

    if (template == GrantComposerTemplate.internetExit) {
      options.add(const GrantComposerOption(
        value: 'autogroup:internet',
        label: 'autogroup:internet',
        subtitle: 'Internet',
      ));
      return options;
    }

    if (template == GrantComposerTemplate.intraFleet) {
      for (var node in nodes) {
        final norm = node.getNormalizedOwner();
        if (restrictToOwnerNorm != null && norm != restrictToOwnerNorm) {
          continue;
        }
        final clientTag = 'tag:$norm-client';
        if (node.tags.contains(clientTag)) {
          options.add(GrantComposerOption(
            value: clientTag,
            label: clientTag,
            subtitle: node.name,
          ));
        }
      }
      return options;
    }

    if (template == GrantComposerTemplate.targetedIp) {
      for (var node in nodes) {
        for (var ip in node.ipAddresses) {
          options.add(GrantComposerOption(
            value: ip,
            label: ip,
            subtitle: node.name,
          ));
        }
      }
      return options;
    }

    // LAN — subnets from nodes (optionally filtered by router owner)
    final routes = <String>{};
    for (var node in nodes) {
      if (restrictToOwnerNorm != null &&
          node.getNormalizedOwner() != restrictToOwnerNorm) {
        continue;
      }
      for (var route in node.sharedRoutes) {
        if (route != '0.0.0.0/0' && route != '::/0') {
          routes.add(route);
        }
      }
    }
    for (var route in routes) {
      options.add(GrantComposerOption(
        value: route,
        label: route,
        subtitle: 'Subnet',
      ));
    }
    return options;
  }

  static Map<String, dynamic> buildNetworkGrant({
    required List<String> src,
    required List<String> dst,
    List<String> via = const [],
    List<String> ip = const ['*'],
  }) {
    final grant = <String, dynamic>{
      'src': src,
      'dst': dst,
      'ip': ip,
    };
    if (via.isNotEmpty) grant['via'] = via;
    return grant;
  }

  static Map<String, dynamic> buildExceptionAcl({
    required String src,
    required String dst,
    String port = '*',
    String proto = 'any',
  }) {
    final rule = <String, dynamic>{
      'action': 'accept',
      'src': [src],
      'dst': ['${dst.endsWith(':*') ? dst.replaceAll(':*', '') : dst}:$port'],
    };
    if (proto != 'any') rule['proto'] = proto;
    return rule;
  }

  static String grantSignature(Map<String, dynamic> grant) {
    final src = ((grant['src'] as List?)?.map((e) => e.toString()).toList()
          ?? [])
      ..sort();
    final dst = ((grant['dst'] as List?)?.map((e) => e.toString()).toList()
          ?? [])
      ..sort();
    final via = ((grant['via'] as List?)?.map((e) => e.toString()).toList()
          ?? [])
      ..sort();
    return 'src:${src.join(",")}|via:${via.join(",")}|dst:${dst.join(",")}';
  }

  static Map<String, dynamic> appendNetworkGrant(
    Map<String, dynamic> policy,
    Map<String, dynamic> grant,
  ) {
    final updated = Map<String, dynamic>.from(policy);
    final grants = List<dynamic>.from(updated['grants'] as List? ?? []);
    final sig = grantSignature(grant);
    final exists = grants.whereType<Map>().any(
          (g) => grantSignature(Map<String, dynamic>.from(g)) == sig,
        );
    if (!exists) grants.add(grant);
    updated['grants'] = grants;
    return updated;
  }

  static Map<String, dynamic> appendExceptionAcl(
    Map<String, dynamic> policy,
    Map<String, dynamic> aclRule,
  ) {
    final updated = Map<String, dynamic>.from(policy);
    final acls = List<dynamic>.from(updated['acls'] as List? ?? []);
    acls.add(aclRule);
    updated['acls'] = acls;
    return updated;
  }

  static Map<String, dynamic> updateNetworkGrantAt(
    Map<String, dynamic> policy,
    int networkGrantIndex,
    Map<String, dynamic> grant,
  ) {
    final updated = Map<String, dynamic>.from(policy);
    final grants = List<dynamic>.from(updated['grants'] as List? ?? []);
    var idx = 0;
    for (var i = 0; i < grants.length; i++) {
      final g = grants[i];
      if (g is! Map) continue;
      if (!_isNetworkGrant(Map<String, dynamic>.from(g))) continue;
      if (idx == networkGrantIndex) {
        grants[i] = grant;
        break;
      }
      idx++;
    }
    updated['grants'] = grants;
    return updated;
  }

  static Map<String, dynamic> removeNetworkGrantAt(
    Map<String, dynamic> policy,
    int networkGrantIndex,
  ) {
    final updated = Map<String, dynamic>.from(policy);
    final grants = List<dynamic>.from(updated['grants'] as List? ?? []);
    var idx = 0;
    for (var i = 0; i < grants.length; i++) {
      final g = grants[i];
      if (g is! Map) continue;
      if (!_isNetworkGrant(Map<String, dynamic>.from(g))) continue;
      if (idx == networkGrantIndex) {
        grants.removeAt(i);
        break;
      }
      idx++;
    }
    updated['grants'] = grants;
    return updated;
  }

  static bool _isNetworkGrant(Map<String, dynamic> grant) {
    if (!grant.containsKey('ip')) return false;
    final app = grant['app'];
    if (app is Map &&
        (app.containsKey('tailscale.com/cap/drive') ||
            app.containsKey('tailscale.com/cap/taildrive'))) {
      return false;
    }
    return true;
  }

  static int countNetworkGrants(Map<String, dynamic> policy) {
    final grants = policy['grants'] as List? ?? [];
    return grants.whereType<Map>().where((g) {
      return _isNetworkGrant(Map<String, dynamic>.from(g));
    }).length;
  }
}
