import 'dart:collection';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';

// Models to represent parsed permissions
class AllowedGrantRoute {
  final String destination;
  final List<String> ip;
  final String? viaTag;
  final Node? viaNode;
  final List<String> sourceAliases;

  AllowedGrantRoute({
    required this.destination,
    this.ip = const ['*'],
    this.viaTag,
    this.viaNode,
    this.sourceAliases = const [],
  });

  bool get isInternet => destination == 'autogroup:internet';

  @override
  String toString() =>
      '$destination via ${viaTag ?? "direct"} (${viaNode?.name ?? "?"})';
}

class NodePermission {
  final List<AllowedPeer> allowedPeers;
  final List<AllowedSubnet> allowedSubnets;
  final List<AllowedExitNode> allowedExitNodes;
  final List<TaildriveGrant> allowedTaildriveShares;
  final List<AllowedGrantRoute> allowedGrantRoutes;

  NodePermission({
    required this.allowedPeers,
    required this.allowedSubnets,
    required this.allowedExitNodes,
    this.allowedTaildriveShares = const [],
    this.allowedGrantRoutes = const [],
  });

  @override
  String toString() {
    return 'Permissions:\n  Peers: ${allowedPeers.join(', ')}\n  Subnets: ${allowedSubnets.join(', ')}\n  Exit Nodes: ${allowedExitNodes.join(', ')}\n  Taildrive: ${allowedTaildriveShares.join(', ')}';
  }
}

class AllowedPeer {
  final Node node;
  final List<String> ports;

  AllowedPeer({required this.node, required this.ports});

  @override
  String toString() => '${node.name} (${ports.join(',')})';
}

class AllowedSubnet {
  final String subnet; // Le sous-réseau parent (ex: 192.168.1.0/24)
  final String specificRule; // La règle spécifique (ex: 192.168.1.22)
  final List<String> ports;
  final Node? sourceNode;

  AllowedSubnet({
    required this.subnet,
    required this.specificRule,
    required this.ports,
    this.sourceNode,
  });

  @override
  String toString() =>
      '$specificRule (dans $subnet via ${sourceNode?.name ?? "unknown"}) (${ports.join(',')})';
}

class AllowedExitNode {
  final Node node;
  final Node? sourceNode; // Le nœud qui accorde l'accès à cet exit node

  AllowedExitNode({required this.node, this.sourceNode});

  @override
  String toString() => '${node.name} (via ${sourceNode?.name ?? "direct"})';
}

class TaildriveGrant {
  final String shareName;
  final String access; // 'ro' or 'rw'
  final List<Node> sourceNodes; // The nodes providing the share

  TaildriveGrant({
    required this.shareName,
    required this.access,
    required this.sourceNodes,
  });

  @override
  String toString() =>
      '$shareName ($access) via ${sourceNodes.map((n) => n.name).join(', ')}';
}

class AclParserService {
  final Map<String, dynamic> aclPolicy;
  final List<Node> allNodes;
  final List<User> allUsers;
  final Map<String, List<String>> _aliases = {};
  final Map<String, Node> _nodeIpMap = {};
  final Map<String, Node> _routeSourceMap = {};

  AclParserService({
    required this.aclPolicy,
    required this.allNodes,
    required this.allUsers,
  }) {
    _buildIpMap();
    _buildRouteSourceMap();
    _parseAliases();
  }

  void _buildIpMap() {
    for (var node in allNodes) {
      for (var ip in node.ipAddresses) {
        _nodeIpMap[ip] = node;
      }
    }
  }

  void _buildRouteSourceMap() {
    for (var node in allNodes) {
      for (var route in node.sharedRoutes) {
        _routeSourceMap[route.trim()] = node;
      }
    }
  }

  void _parseAliases() {
    if (aclPolicy.containsKey('tagOwners')) {
      final tagOwnersRaw = aclPolicy['tagOwners'];
      if (tagOwnersRaw is Map) {
        tagOwnersRaw.forEach((tag, ownersRaw) {
          final ownerAliases = _coerceStringList(ownersRaw);
          for (var ownerAlias in ownerAliases) {
            final user = allUsers.firstWhere((u) => u.name == ownerAlias,
                orElse: () =>
                    User(id: '', name: '', createdAt: DateTime.now()));
            if (user.id.isNotEmpty) {
              final userNodes = allNodes.where((n) =>
                  n.user == user.name ||
                  n.getNormalizedOwner() == normalizeUserName(user.name));
              _aliases[tag.toString()] =
                  userNodes.expand((n) => n.ipAddresses).toList();
            }
          }
        });
      }
    }
    if (aclPolicy.containsKey('groups')) {
      final groupsRaw = aclPolicy['groups'];
      if (groupsRaw is Map) {
        groupsRaw.forEach((group, aliasesRaw) {
          _aliases[group.toString()] = _coerceStringList(aliasesRaw);
        });
      }
    }
  }

  List<String> _coerceStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) return [value];
    return const [];
  }

  List<String> _resolveAlias(String alias, Node sourceNode,
      [Set<String>? visited]) {
    visited ??= <String>{};
    if (!visited.add(alias)) return const [];
    if (alias == '*') {
      return allNodes.expand((n) => n.ipAddresses).toList();
    }
    if (alias == 'autogroup:self') {
      return sourceNode.ipAddresses;
    }
    if (_aliases.containsKey(alias)) {
      return _aliases[alias]!
          .expand((a) => _resolveAlias(a, sourceNode, visited))
          .toList();
    }
    if (IpUtils.isCIDR(alias)) {
      return [alias];
    }
    // Handle complex tags like "tag:a;b;c"
    if (alias.startsWith('tag:')) {
      final requiredTags = alias
          .split(';')
          .where((t) => t.isNotEmpty)
          .map((t) => t.startsWith('tag:') ? t : 'tag:$t')
          .toSet();

      if (requiredTags.isNotEmpty) {
        final matchingNodes = allNodes.where((node) {
          // Check if the node's tags contain ALL of the required tags.
          return requiredTags.every((reqTag) => node.tags.contains(reqTag));
        });
        if (matchingNodes.isNotEmpty) {
          return matchingNodes.expand((n) => n.ipAddresses).toList();
        }
      }
    }
    // Check if it's a user name
    final user = allUsers.firstWhere((u) => u.name == alias,
        orElse: () => User(id: '', name: '', createdAt: DateTime.now()));
    if (user.id.isNotEmpty) {
      return allNodes
          .where((n) =>
              n.user == user.name ||
              n.getNormalizedOwner() == normalizeUserName(user.name))
          .expand((n) => n.ipAddresses)
          .toList();
    }
    // If none of the above, treat it as a raw IP or an unresolved alias
    return [alias];
  }

  Node? _findNodeByTag(String tag) {
    for (var node in allNodes) {
      if (node.tags.contains(tag)) return node;
    }
    return null;
  }

  bool _grantAppliesToNode(List<String> sources, Node node) {
    for (var source in sources) {
      if (source.startsWith('tag:')) {
        final requiredTags = source
            .split(';')
            .where((t) => t.isNotEmpty)
            .map((t) => t.startsWith('tag:') ? t : 'tag:$t')
            .toSet();
        if (requiredTags.isNotEmpty &&
            requiredTags.every((t) => node.tags.contains(t))) {
          return true;
        }
      }
    }

    final sourceIps = sources.expand((s) => _resolveAlias(s, node)).toSet();
    return sourceIps.any((ip) => node.ipAddresses.contains(ip)) ||
        sources.contains('*');
  }

  NodePermission getPermissionsForNode(Node node) {
    final allowedPeers = <AllowedPeer>[];
    final allowedSubnets = <AllowedSubnet>[];
    final allowedExitNodes = <AllowedExitNode>[];
    final allowedGrantRoutes = <AllowedGrantRoute>[];
    final Set<String> processedRules = HashSet();

    if (aclPolicy.containsKey('acls')) {
      final acls = aclPolicy['acls'];
      if (acls is List) {
        for (var rule in acls) {
          if (rule is! Map) continue;
          if (rule['action'] != 'accept') continue;

          final srcRaw = rule['src'];
          final dstRaw = rule['dst'];
          if (srcRaw is! List || dstRaw is! List) continue;

          final List<String> sources = srcRaw.map((e) => e.toString()).toList();
          final sourceIps =
              sources.expand((s) => _resolveAlias(s, node)).toSet();

          bool isSource =
              sourceIps.any((ip) => node.ipAddresses.contains(ip));
          if (!isSource && !sources.contains('*')) {
            continue;
          }

          final List<String> destinations =
              dstRaw.map((e) => e.toString()).toList();
          final List<String> defaultPorts =
              (rule['ports'] is List) ? (rule['ports'] as List).map((e) => e.toString()).toList() : ['*'];

          for (var dest in destinations) {
            final ruleSignature = '${rule.hashCode}-$dest';
            if (processedRules.contains(ruleSignature)) continue;
            processedRules.add(ruleSignature);

            String destAddr = dest;
            List<String> ports = defaultPorts;

            int lastColon = dest.lastIndexOf(':');
            if (lastColon != -1) {
              String potentialAddr = dest.substring(0, lastColon);
              String potentialPort = dest.substring(lastColon + 1);

              if (potentialAddr.startsWith('[') && potentialAddr.endsWith(']')) {
                destAddr = potentialAddr;
                ports = potentialPort.split(',');
              } else if (!potentialAddr.contains(':')) {
                destAddr = potentialAddr;
                ports = potentialPort.split(',');
              }
            }

            final List<String> resolvedDestIpsOrCidrs =
                _resolveAlias(destAddr, node).toList();

            for (var destIpOrCidr in resolvedDestIpsOrCidrs) {
              final trimmedDest = destIpOrCidr.trim();

              if (_routeSourceMap.containsKey(trimmedDest)) {
                final advertiserNode = _routeSourceMap[trimmedDest];
                if (trimmedDest == '0.0.0.0/0' || trimmedDest == '::/0') {
                  if (advertiserNode != null) {
                    allowedExitNodes.add(AllowedExitNode(
                        node: advertiserNode, sourceNode: advertiserNode));
                  }
                } else {
                  allowedSubnets.add(AllowedSubnet(
                      subnet: trimmedDest,
                      specificRule: trimmedDest,
                      ports: ports,
                      sourceNode: advertiserNode));
                }
              } else {
                bool foundParentRoute = false;

                for (var knownRoute in _routeSourceMap.keys) {
                  if (knownRoute == '0.0.0.0/0' || knownRoute == '::/0') {
                    continue;
                  }

                  if (_isIpInSubnet(trimmedDest, knownRoute)) {
                    final advertiserNode = _routeSourceMap[knownRoute];
                    allowedSubnets.add(AllowedSubnet(
                        subnet: knownRoute,
                        specificRule: trimmedDest,
                        ports: ports,
                        sourceNode: advertiserNode));
                    foundParentRoute = true;
                    break;
                  }
                }

                if (!foundParentRoute && _nodeIpMap.containsKey(trimmedDest)) {
                  final destNode = _nodeIpMap[trimmedDest]!;
                  if (destNode.id != node.id) {
                    allowedPeers.add(AllowedPeer(node: destNode, ports: ports));
                  }
                }
              }
            }
          }
        }
      }
    }

    // --- Parsing network Grants (Headscale 0.29+) ---
    final allowedTaildriveShares = <TaildriveGrant>[];
    final grants = aclPolicy['grants'];
    if (grants is List) {
      for (var grant in grants) {
        if (grant is! Map) continue;
        final grantMap = Map<String, dynamic>.from(grant);

        final List<String> sources =
            (grantMap['src'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (sources.isEmpty) continue;

        if (!_grantAppliesToNode(sources, node)) continue;

        final Map<String, dynamic>? app =
            grantMap['app'] is Map ? Map<String, dynamic>.from(grantMap['app']) : null;
        final hasTaildriveApp = app != null &&
            (app.containsKey('tailscale.com/cap/drive') ||
                app.containsKey('tailscale.com/cap/taildrive'));

        if (hasTaildriveApp) {
          final List<String> destinations =
              (grantMap['dst'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final List<dynamic> taildriveCaps = [
            ...(app['tailscale.com/cap/drive'] as List? ?? []),
            ...(app['tailscale.com/cap/taildrive'] as List? ?? []),
          ];

          if (taildriveCaps.isNotEmpty) {
            final List<Node> targetNodes = [];
            for (var dest in destinations) {
              final destIps = _resolveAlias(dest, node);
              for (var dip in destIps) {
                if (_nodeIpMap.containsKey(dip)) {
                  targetNodes.add(_nodeIpMap[dip]!);
                }
              }
            }

            if (targetNodes.isNotEmpty) {
              for (var cap in taildriveCaps) {
                if (cap is! Map) continue;
                final capMap = Map<String, dynamic>.from(cap);
                final shares = capMap['shares'] as List?;
                final shareName = shares != null && shares.isNotEmpty
                    ? shares.first.toString()
                    : capMap['share']?.toString() ?? 'unknown';
                allowedTaildriveShares.add(TaildriveGrant(
                  shareName: shareName,
                  access: capMap['access']?.toString() ?? 'ro',
                  sourceNodes: targetNodes,
                ));
              }
            }
          }
          continue;
        }

        if (!grantMap.containsKey('ip')) continue;

        final viaList = (grantMap['via'] as List?)?.map((e) => e.toString()).toList();
        final viaTag = viaList != null && viaList.isNotEmpty ? viaList.first : null;
        final viaNode = viaTag != null ? _findNodeByTag(viaTag) : null;
        final ipList =
            (grantMap['ip'] as List?)?.map((e) => e.toString()).toList() ?? ['*'];
        final destinations =
            (grantMap['dst'] as List?)?.map((e) => e.toString()).toList() ?? [];

        for (var dest in destinations) {
          allowedGrantRoutes.add(AllowedGrantRoute(
            destination: dest,
            ip: ipList,
            viaTag: viaTag,
            viaNode: viaNode,
            sourceAliases: sources,
          ));

          if (dest == 'autogroup:internet' && viaNode != null) {
            allowedExitNodes.add(
                AllowedExitNode(node: viaNode, sourceNode: viaNode));
          } else if (dest.contains('/')) {
            allowedSubnets.add(AllowedSubnet(
              subnet: dest,
              specificRule: dest,
              ports: ipList.contains('*') ? ['*'] : ipList,
              sourceNode: viaNode ?? _routeSourceMap[dest.trim()],
            ));
          } else if (dest.startsWith('tag:') ||
              dest.startsWith('group:') ||
              (dest.startsWith('autogroup:') && dest != 'autogroup:internet')) {
            continue;
          } else {
            final destIps = _resolveAlias(dest, node);
            for (var dip in destIps) {
              if (_nodeIpMap.containsKey(dip)) {
                final destNode = _nodeIpMap[dip]!;
                if (destNode.id != node.id) {
                  allowedPeers.add(
                      AllowedPeer(node: destNode, ports: ['*']));
                }
              }
            }
          }
        }
      }
    }

    final uniquePeers = <String, AllowedPeer>{};
    for (var peer in allowedPeers) {
      if (uniquePeers.containsKey(peer.node.id)) {
        final existingPorts = uniquePeers[peer.node.id]!.ports;
        final newPorts = {...existingPorts, ...peer.ports}.toSet().toList();
        if (newPorts.length > 1) newPorts.remove('*');
        uniquePeers[peer.node.id] =
            AllowedPeer(node: peer.node, ports: newPorts);
      } else {
        uniquePeers[peer.node.id] = peer;
      }
    }

    final uniqueExitNodes = <String, AllowedExitNode>{};
    for (var exitNode in allowedExitNodes) {
      if (!uniqueExitNodes.containsKey(exitNode.node.id)) {
        uniqueExitNodes[exitNode.node.id] = exitNode;
      }
    }

    // --- Dedup peers ---
    return NodePermission(
      allowedPeers: uniquePeers.values.toList(),
      allowedSubnets: allowedSubnets,
      allowedExitNodes: uniqueExitNodes.values.toList(),
      allowedTaildriveShares: allowedTaildriveShares,
      allowedGrantRoutes: allowedGrantRoutes,
    );
  }

  // --- NOUVEAUX HELPERS ---

  bool _isIpInSubnet(String ipStr, String cidrStr) {
    try {
      if (!cidrStr.contains('/')) return ipStr == cidrStr;

      final parts = cidrStr.split('/');
      final subnetIpStr = parts[0];
      final prefixLength = int.parse(parts[1]);

      if (ipStr.contains('.') && subnetIpStr.contains('.')) {
        return _isIPv4InSubnet(ipStr, subnetIpStr, prefixLength);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool _isIPv4InSubnet(String ip, String subnetIp, int prefixLength) {
    try {
      int ipInt = _ipToInt(ip);
      int subnetInt = _ipToInt(subnetIp);
      int mask = (0xffffffff << (32 - prefixLength)) & 0xffffffff;
      return (ipInt & mask) == (subnetInt & mask);
    } catch (e) {
      return false;
    }
  }

  int _ipToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) throw FormatException('Invalid IPv4');
    return (int.parse(parts[0]) << 24) |
        (int.parse(parts[1]) << 16) |
        (int.parse(parts[2]) << 8) |
        int.parse(parts[3]);
  }
}
