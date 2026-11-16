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

  /// Simule une connexion entre [sourceNode] et [destination] selon les
  /// règles `grants` puis `acls` de la politique locale.
  SimulationResult simulateConnection({
    required Node sourceNode,
    required String destination,
    String? port,
    String protocol = 'tcp',
  }) {
    final normalizedDest = destination.trim();
    final normalizedPort =
        (port == null || port.trim().isEmpty) ? '*' : port.trim();
    final normalizedProto =
        protocol.trim().isEmpty ? 'tcp' : protocol.trim().toLowerCase();

    final targetNode = _findTargetNode(normalizedDest);
    final hostsMap = _extractHostsMap();
    final destIps = _resolveDestinationIps(
      normalizedDest,
      targetNode: targetNode,
      hostsMap: hostsMap,
    );

    // 1. Évaluation des Grants réseau (Headscale 0.29+)
    final grants = aclPolicy['grants'];
    if (grants is List) {
      for (final rawGrant in grants) {
        if (rawGrant is! Map) continue;
        final grantMap = Map<String, dynamic>.from(rawGrant);
        if (!grantMap.containsKey('ip')) continue;

        final sources = _coerceStringList(grantMap['src']);
        if (sources.isEmpty ||
            !_selectorListMatchesNode(sources, sourceNode, sourceNode)) {
          continue;
        }

        final destinations = _coerceStringList(grantMap['dst']);
        if (destinations.isEmpty) continue;

        final ipSpecs = _coerceStringList(grantMap['ip']);
        if (!_grantIpListMatches(
          ipSpecs.isEmpty ? const ['*'] : ipSpecs,
          port: normalizedPort,
          protocol: normalizedProto,
        )) {
          continue;
        }

        for (final dstExpr in destinations) {
          if (_destinationMatches(
            dstExpr: dstExpr,
            targetExpr: normalizedDest,
            targetNode: targetNode,
            targetIps: destIps,
            sourceNode: sourceNode,
            hostsMap: hostsMap,
          )) {
            final viaList = _coerceStringList(grantMap['via']);
            final viaTag = viaList.isNotEmpty ? viaList.first : null;
            final viaNode = viaTag != null
                ? _findNodeByTag(viaTag)
                : _inferViaNode(normalizedDest, destIps);

            return SimulationResult(
              allowed: true,
              matchedRuleType: 'grant',
              matchedRule: grantMap,
              viaTag: viaTag,
              viaNode: viaNode,
              normalizedDestination: normalizedDest,
              requestedPort: normalizedPort,
              requestedProtocol: normalizedProto,
              matchedRuleSummary:
                  'grant: ${sources.join(', ')} -> $dstExpr [ip: ${ipSpecs.join(', ')}]'
                  '${viaTag != null ? ' via $viaTag' : ''}',
            );
          }
        }
      }
    }

    // 2. Évaluation des ACL classiques
    final acls = aclPolicy['acls'];
    if (acls is List) {
      for (final rawRule in acls) {
        if (rawRule is! Map) continue;
        final ruleMap = Map<String, dynamic>.from(rawRule);
        if (ruleMap['action'] != 'accept') continue;

        final ruleProto = ruleMap['proto']?.toString().trim().toLowerCase();
        if (ruleProto != null &&
            ruleProto.isNotEmpty &&
            ruleProto != '*' &&
            ruleProto != 'all' &&
            normalizedProto != '*' &&
            ruleProto != normalizedProto) {
          continue;
        }

        final sources = _coerceStringList(ruleMap['src']);
        if (sources.isEmpty ||
            !_selectorListMatchesNode(sources, sourceNode, sourceNode)) {
          continue;
        }

        final destinations = _coerceStringList(ruleMap['dst']);
        final defaultPorts = ruleMap['ports'] is List
            ? _coerceStringList(ruleMap['ports'])
            : const ['*'];

        for (final destSpec in destinations) {
          final parsed = _splitHostAndPorts(
            destSpec,
            defaultPorts: defaultPorts,
          );
          if (!_portsMatch(parsed.ports, normalizedPort)) continue;

          if (_destinationMatches(
            dstExpr: parsed.host,
            targetExpr: normalizedDest,
            targetNode: targetNode,
            targetIps: destIps,
            sourceNode: sourceNode,
            hostsMap: hostsMap,
          )) {
            final viaNode = _inferViaNode(normalizedDest, destIps);
            return SimulationResult(
              allowed: true,
              matchedRuleType: 'acl',
              matchedRule: ruleMap,
              viaNode: viaNode,
              normalizedDestination: normalizedDest,
              requestedPort: normalizedPort,
              requestedProtocol: normalizedProto,
              matchedRuleSummary:
                  'acl: ${sources.join(', ')} -> $destSpec'
                  '${viaNode != null ? ' (via ${viaNode.name})' : ''}',
            );
          }
        }
      }
    }

    return SimulationResult(
      allowed: false,
      normalizedDestination: normalizedDest,
      requestedPort: normalizedPort,
      requestedProtocol: normalizedProto,
    );
  }

  /// Valide les entrées `policy['tests']` (Headscale >= 0.29) afin d'éviter un
  /// rejet serveur lorsqu'une machine ou un tag référencé n'existe plus.
  static AclTestValidationResult validatePolicyTests(
    Map<String, dynamic> policy, {
    required List<Node> allNodes,
    required List<User> allUsers,
  }) {
    final testsRaw = policy['tests'];
    if (testsRaw is! List || testsRaw.isEmpty) {
      return const AclTestValidationResult(issues: []);
    }

    final validNodeIps = <String>{
      for (final node in allNodes) ...node.ipAddresses.map((ip) => ip.trim()),
    };
    final validTags = <String>{
      for (final node in allNodes) ...node.tags,
      if (policy['tagOwners'] is Map)
        ...(policy['tagOwners'] as Map).keys.map((k) => k.toString()),
    };
    final validGroups = <String>{
      if (policy['groups'] is Map)
        ...(policy['groups'] as Map).keys.map((k) => k.toString()),
    };
    final validHosts = <String>{
      if (policy['hosts'] is Map)
        ...(policy['hosts'] as Map).keys.map((k) => k.toString()),
    };
    final validUsers = <String>{
      for (final user in allUsers) ...[
        user.name,
        normalizeUserName(user.name),
      ],
    };

    bool isValidEndpoint(String rawToken, {required bool stripPort}) {
      var token = rawToken.trim();
      if (token.isEmpty || token == '*' || token.startsWith('autogroup:')) {
        return true;
      }
      if (stripPort) {
        token = _splitHostAndPorts(token, defaultPorts: const ['*']).host;
      }
      if (token == '*' || token.startsWith('autogroup:')) return true;
      if (token.startsWith('tag:')) {
        return token
            .split(';')
            .where((t) => t.isNotEmpty)
            .map((t) => t.startsWith('tag:') ? t : 'tag:$t')
            .every(validTags.contains);
      }
      if (token.startsWith('group:')) {
        return validGroups.contains(token);
      }
      if (validHosts.contains(token) || validUsers.contains(token)) {
        return true;
      }
      if (IpUtils.isCIDR(token)) return true;
      if (_isTailscaleMeshIp(token)) {
        return validNodeIps.contains(token);
      }
      if (IpUtils.isIPv4(token) || IpUtils.isIPv6(token)) {
        return true;
      }
      // Nom de machine direct ou alias inconnu
      return allNodes.any((n) => n.name == token) ||
          validNodeIps.contains(token);
    }

    final issues = <PolicyTestIssue>[];
    for (var i = 0; i < testsRaw.length; i++) {
      final entry = testsRaw[i];
      if (entry is! Map) continue;

      final src = entry['src']?.toString().trim() ?? '';
      if (src.isEmpty || !isValidEndpoint(src, stripPort: false)) {
        issues.add(PolicyTestIssue(
          testIndex: i,
          field: 'src',
          value: src,
          reasonFr: 'Source introuvable ou nœud supprimé : "$src"',
          reasonEn: 'Unknown source or deleted node: "$src"',
        ));
      }

      for (final field in const ['accept', 'deny']) {
        final targets = entry[field];
        if (targets is! List) continue;
        for (final t in targets) {
          final value = t.toString().trim();
          if (!isValidEndpoint(value, stripPort: true)) {
            issues.add(PolicyTestIssue(
              testIndex: i,
              field: field,
              value: value,
              reasonFr: 'Cible introuvable dans "$field" : "$value"',
              reasonEn: 'Unknown target in "$field": "$value"',
            ));
            continue;
          }
          final portError = _validateSingleTestPort(value);
          if (portError != null) {
            issues.add(PolicyTestIssue(
              testIndex: i,
              field: field,
              value: value,
              reasonFr:
                  'Port invalide dans "$field" ("$value") : Headscale exige un port numérique unique (ex: :443), pas "*" ou de plage.',
              reasonEn:
                  'Invalid port in "$field" ("$value"): Headscale requires a single numeric port (e.g. :443), not "*" or ranges.',
            ));
          }
        }
      }
    }

    return AclTestValidationResult(issues: issues);
  }

  /// Retourne une copie de [policy] dont les références invalides dans `tests`
  /// ont été nettoyées.
  static Map<String, dynamic> pruneObsoletePolicyTests(
    Map<String, dynamic> policy, {
    required List<Node> allNodes,
    required List<User> allUsers,
  }) {
    final copy = Map<String, dynamic>.from(policy);
    final testsRaw = copy['tests'];
    if (testsRaw is! List || testsRaw.isEmpty) return copy;

    final validation = validatePolicyTests(
      copy,
      allNodes: allNodes,
      allUsers: allUsers,
    );
    if (validation.isValid) return copy;

    final deadIndices = <int>{};
    final deadTargetsByTest = <int, Set<String>>{};
    for (final issue in validation.issues) {
      if (issue.field == 'src') {
        deadIndices.add(issue.testIndex);
      } else {
        deadTargetsByTest
            .putIfAbsent(issue.testIndex, () => <String>{})
            .add('${issue.field}:${issue.value}');
      }
    }

    final cleanedTests = <Map<String, dynamic>>[];
    for (var i = 0; i < testsRaw.length; i++) {
      if (deadIndices.contains(i)) continue;
      final raw = testsRaw[i];
      if (raw is! Map) continue;
      final testMap = Map<String, dynamic>.from(raw);
      final deadTargets = deadTargetsByTest[i] ?? const <String>{};

      for (final field in const ['accept', 'deny']) {
        if (testMap[field] is List) {
          final filtered = (testMap[field] as List)
              .map((e) => e.toString())
              .where((v) => !deadTargets.contains('$field:${v.trim()}'))
              .toList();
          if (filtered.isEmpty) {
            testMap.remove(field);
          } else {
            testMap[field] = filtered;
          }
        }
      }

      final hasAccept =
          testMap['accept'] is List && (testMap['accept'] as List).isNotEmpty;
      final hasDeny =
          testMap['deny'] is List && (testMap['deny'] as List).isNotEmpty;
      if (hasAccept || hasDeny) {
        cleanedTests.add(testMap);
      }
    }

    if (cleanedTests.isEmpty) {
      copy.remove('tests');
    } else {
      copy['tests'] = cleanedTests;
    }
    return copy;
  }

  Map<String, String> _extractHostsMap() {
    final hostsRaw = aclPolicy['hosts'];
    if (hostsRaw is! Map) return const {};
    return {
      for (final entry in hostsRaw.entries)
        entry.key.toString().trim(): entry.value.toString().trim(),
    };
  }

  Node? _findTargetNode(String destination) {
    final clean = destination.trim();
    for (final node in allNodes) {
      if (node.name == clean ||
          node.id == clean ||
          node.ipAddresses.contains(clean)) {
        return node;
      }
    }
    final hostIp = _extractHostsMap()[clean];
    if (hostIp != null && _nodeIpMap.containsKey(hostIp)) {
      return _nodeIpMap[hostIp];
    }
    return null;
  }

  List<String> _resolveDestinationIps(
    String destination, {
    Node? targetNode,
    required Map<String, String> hostsMap,
  }) {
    if (targetNode != null && targetNode.ipAddresses.isNotEmpty) {
      return targetNode.ipAddresses;
    }
    if (hostsMap.containsKey(destination)) {
      return [hostsMap[destination]!];
    }
    if (IpUtils.isIPv4(destination) ||
        IpUtils.isIPv6(destination) ||
        IpUtils.isCIDR(destination)) {
      return [destination];
    }
    return const [];
  }

  bool _selectorListMatchesNode(
    List<String> selectors,
    Node candidateNode,
    Node sourceContextNode, [
    Set<String>? visited,
  ]) {
    visited ??= <String>{};
    for (final raw in selectors) {
      final expr = raw.trim();
      if (expr.isEmpty) continue;
      if (_selectorMatchesNode(expr, candidateNode, sourceContextNode, visited)) {
        return true;
      }
    }
    return false;
  }

  bool _selectorMatchesNode(
    String expr,
    Node candidateNode,
    Node sourceContextNode,
    Set<String> visited,
  ) {
    if (expr == '*') return true;
    if (expr == 'autogroup:member') {
      return candidateNode.user.isNotEmpty || candidateNode.tags.isEmpty;
    }
    if (expr == 'autogroup:tagged') {
      return candidateNode.tags.isNotEmpty;
    }
    if (expr == 'autogroup:self') {
      return _isSameUser(candidateNode, sourceContextNode);
    }

    if (expr.startsWith('group:')) {
      if (!visited.add(expr)) return false;
      final groups = aclPolicy['groups'];
      if (groups is Map && groups[expr] != null) {
        final members = _coerceStringList(groups[expr]);
        return _selectorListMatchesNode(
            members, candidateNode, sourceContextNode, visited);
      }
      return false;
    }

    if (expr.startsWith('tag:')) {
      final requiredTags = expr
          .split(';')
          .where((t) => t.isNotEmpty)
          .map((t) => t.startsWith('tag:') ? t : 'tag:$t')
          .toSet();
      return requiredTags.isNotEmpty &&
          requiredTags.every(candidateNode.tags.contains);
    }

    final hostsMap = _extractHostsMap();
    if (hostsMap.containsKey(expr)) {
      return candidateNode.ipAddresses.contains(hostsMap[expr]);
    }

    if (candidateNode.ipAddresses.contains(expr) ||
        candidateNode.name == expr) {
      return true;
    }

    if (IpUtils.isCIDR(expr)) {
      return candidateNode.ipAddresses.any((ip) => _isIpInSubnet(ip, expr));
    }

    return candidateNode.user == expr ||
        candidateNode.getNormalizedOwner() == normalizeUserName(expr);
  }

  bool _destinationMatches({
    required String dstExpr,
    required String targetExpr,
    required Node? targetNode,
    required List<String> targetIps,
    required Node sourceNode,
    required Map<String, String> hostsMap,
    Set<String>? visited,
  }) {
    visited ??= <String>{};
    final expr = dstExpr.trim();
    if (expr.isEmpty) return false;
    if (expr == '*') return true;

    final targetIsInternet = targetExpr == 'autogroup:internet' ||
        targetExpr == '0.0.0.0/0' ||
        targetExpr == '::/0';
    if (targetIsInternet) {
      return expr == 'autogroup:internet' ||
          expr == '0.0.0.0/0' ||
          expr == '::/0';
    }
    if (expr == 'autogroup:internet') return false;

    if (targetNode != null) {
      return _selectorMatchesNode(expr, targetNode, sourceNode, visited);
    }

    // Cible IP / CIDR / alias hosts (sans nœud Tailscale correspondant)
    if (expr == targetExpr) return true;
    if (hostsMap.containsKey(expr) &&
        (targetIps.contains(hostsMap[expr]) || hostsMap[expr] == targetExpr)) {
      return true;
    }
    if (expr.startsWith('group:') && visited.add(expr)) {
      final groups = aclPolicy['groups'];
      if (groups is Map && groups[expr] != null) {
        final members = _coerceStringList(groups[expr]);
        return members.any((m) => _destinationMatches(
              dstExpr: m,
              targetExpr: targetExpr,
              targetNode: targetNode,
              targetIps: targetIps,
              sourceNode: sourceNode,
              hostsMap: hostsMap,
              visited: visited,
            ));
      }
    }

    for (final ip in targetIps) {
      if (ip == expr) return true;
      if (IpUtils.isCIDR(expr) && _isIpInSubnet(ip, expr)) {
        return true;
      }
      if (IpUtils.isCIDR(targetExpr) &&
          IpUtils.isCIDR(expr) &&
          expr == targetExpr) {
        return true;
      }
    }

    return false;
  }

  Node? _inferViaNode(String destination, List<String> destIps) {
    if (destination == 'autogroup:internet' ||
        destination == '0.0.0.0/0' ||
        destination == '::/0') {
      return _routeSourceMap['0.0.0.0/0'] ?? _routeSourceMap['::/0'];
    }
    if (_routeSourceMap.containsKey(destination)) {
      return _routeSourceMap[destination];
    }
    for (final entry in _routeSourceMap.entries) {
      if (entry.key == '0.0.0.0/0' || entry.key == '::/0') continue;
      for (final ip in destIps) {
        if (_isIpInSubnet(ip, entry.key)) return entry.value;
      }
    }
    return null;
  }

  bool _isSameUser(Node a, Node b) {
    if (a.user.isNotEmpty && a.user == b.user) return true;
    return a.getNormalizedOwner() == b.getNormalizedOwner();
  }

  static bool _grantIpListMatches(
    List<String> ipSpecs, {
    required String port,
    required String protocol,
  }) {
    for (final rawSpec in ipSpecs) {
      final spec = rawSpec.trim().toLowerCase();
      if (spec.isEmpty) continue;
      if (spec == '*') return true;

      if (spec == 'icmp') {
        if (protocol == 'icmp' || protocol == '*') return true;
        continue;
      }

      if (spec.contains(':')) {
        final parts = spec.split(':');
        final specProto = parts.first.trim();
        final specPort = parts.sublist(1).join(':').trim();
        final protoMatch =
            protocol == '*' || specProto == '*' || specProto == protocol;
        if (protoMatch && _singlePortSpecMatches(specPort, port)) {
          return true;
        }
      } else {
        if (_singlePortSpecMatches(spec, port)) return true;
      }
    }
    return false;
  }

  static _HostPortsPair _splitHostAndPorts(
    String dest, {
    required List<String> defaultPorts,
  }) {
    final lastColon = dest.lastIndexOf(':');
    if (lastColon != -1) {
      final potentialAddr = dest.substring(0, lastColon);
      final potentialPort = dest.substring(lastColon + 1);
      if ((potentialAddr.startsWith('[') && potentialAddr.endsWith(']')) ||
          !potentialAddr.contains(':')) {
        final cleanAddr =
            potentialAddr.startsWith('[') && potentialAddr.endsWith(']')
                ? potentialAddr.substring(1, potentialAddr.length - 1)
                : potentialAddr;
        return _HostPortsPair(cleanAddr, potentialPort.split(','));
      }
    }
    return _HostPortsPair(dest, defaultPorts);
  }

  static String? _validateSingleTestPort(String value) {
    final lastColon = value.lastIndexOf(':');
    if (lastColon == -1) return 'missing port';
    final beforeColon = value.substring(0, lastColon);
    if (beforeColon.contains(':') &&
        !(beforeColon.startsWith('[') && beforeColon.endsWith(']'))) {
      return 'missing port';
    }
    final portStr = value.substring(lastColon + 1).trim();
    final portNum = int.tryParse(portStr);
    if (portNum == null || portNum < 1 || portNum > 65535) {
      return 'not a single numeric port';
    }
    return null;
  }

  static bool _portsMatch(List<String> allowedPorts, String requestedPort) {
    for (final p in allowedPorts) {
      if (_singlePortSpecMatches(p.trim(), requestedPort)) return true;
    }
    return false;
  }

  static bool _singlePortSpecMatches(String allowedSpec, String requestedPort) {
    if (allowedSpec == '*' || requestedPort == '*') return true;
    if (allowedSpec == requestedPort) return true;
    if (allowedSpec.contains('-')) {
      final parts = allowedSpec.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        final req = int.tryParse(requestedPort.trim());
        if (start != null && end != null && req != null) {
          return req >= start && req <= end;
        }
      }
    }
    return false;
  }

  static bool _isTailscaleMeshIp(String ip) {
    // 100.64.0.0/10 (CGNAT Tailscale) ou préfixe IPv6 ULA Tailscale fd7a:115c:a1e0::
    final lower = ip.toLowerCase();
    if (lower.startsWith('fd7a:115c:a1e0:')) return true;
    if (!IpUtils.isIPv4(ip)) return false;
    final octets = ip.split('.');
    if (octets.length != 4) return false;
    final first = int.tryParse(octets[0]) ?? -1;
    final second = int.tryParse(octets[1]) ?? -1;
    return first == 100 && second >= 64 && second <= 127;
  }
}

class _HostPortsPair {
  final String host;
  final List<String> ports;
  const _HostPortsPair(this.host, this.ports);
}

/// Résultat détaillé d'une simulation de connectivité ACL / Grants.
class SimulationResult {
  final bool allowed;
  final String? matchedRuleType; // 'grant', 'acl', ou null
  final Map<String, dynamic>? matchedRule;
  final String? matchedRuleSummary;
  final String? viaTag;
  final Node? viaNode;
  final String normalizedDestination;
  final String requestedPort;
  final String requestedProtocol;

  const SimulationResult({
    required this.allowed,
    this.matchedRuleType,
    this.matchedRule,
    this.matchedRuleSummary,
    this.viaTag,
    this.viaNode,
    required this.normalizedDestination,
    this.requestedPort = '*',
    this.requestedProtocol = 'tcp',
  });
}

/// Anomalie détectée dans `policy['tests']` avant export vers Headscale.
class PolicyTestIssue {
  final int testIndex;
  final String field; // 'src', 'accept', 'deny'
  final String value;
  final String reasonFr;
  final String reasonEn;

  const PolicyTestIssue({
    required this.testIndex,
    required this.field,
    required this.value,
    required this.reasonFr,
    required this.reasonEn,
  });
}

/// Résultat de validation du bloc `"tests"` d'une politique ACL.
class AclTestValidationResult {
  final List<PolicyTestIssue> issues;

  const AclTestValidationResult({required this.issues});

  bool get isValid => issues.isEmpty;
}

