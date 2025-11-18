import 'dart:collection';

import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/ip_utils.dart';

// Models to represent parsed permissions
class NodePermission {
  final List<AllowedPeer> allowedPeers;
  final List<AllowedSubnet> allowedSubnets;
  final List<AllowedExitNode> allowedExitNodes;

  NodePermission({
    required this.allowedPeers,
    required this.allowedSubnets,
    required this.allowedExitNodes,
  });

  @override
  String toString() {
    return 'Permissions:\n  Peers: ${allowedPeers.join(', ')}\n  Subnets: ${allowedSubnets.join(', ')}\n  Exit Nodes: ${allowedExitNodes.join(', ')}';
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
  final String subnet;
  final List<String> ports;
  final Node? sourceNode;

  AllowedSubnet({required this.subnet, required this.ports, this.sourceNode});

  @override
  String toString() => '$subnet (from ${sourceNode?.name ?? "unknown"}) (${ports.join(',')})';
}

class AllowedExitNode {
  final Node node;

  AllowedExitNode({required this.node});

  @override
  String toString() => node.name;
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
      final Map<String, dynamic> tagOwners = aclPolicy['tagOwners'];
      tagOwners.forEach((tag, owners) {
        final List<String> ownerAliases = (owners as List).cast<String>();
        for (var ownerAlias in ownerAliases) {
          final user = allUsers.firstWhere((u) => u.name == ownerAlias, orElse: () => User(id: '', name: '', createdAt: DateTime.now()));
          if (user.id.isNotEmpty) {
            final userNodes = allNodes.where((n) => n.user == user.name);
            _aliases[tag] = userNodes.expand((n) => n.ipAddresses).toList();
          }
        }
      });
    }
    if (aclPolicy.containsKey('groups')) {
      final Map<String, dynamic> groups = aclPolicy['groups'];
      groups.forEach((group, aliases) {
        _aliases[group] = (aliases as List).cast<String>();
      });
    }
  }

  List<String> _resolveAlias(String alias, Node sourceNode) {
    if (alias == '*') {
      return allNodes.expand((n) => n.ipAddresses).toList();
    }
    if (alias == 'autogroup:self') {
      return sourceNode.ipAddresses;
    }
    if (_aliases.containsKey(alias)) {
      return _aliases[alias]!.expand((a) => _resolveAlias(a, sourceNode)).toList();
    }
    if (IpUtils.isCIDR(alias)) {
      return [alias];
    }
    // It might be a tag or a user
    final user = allUsers.firstWhere((u) => u.name == alias, orElse: () => User(id: '', name: '', createdAt: DateTime.now()));
    if (user.id.isNotEmpty) {
      return allNodes.where((n) => n.user == user.name).expand((n) => n.ipAddresses).toList();
    }
    final nodesWithTag = allNodes.where((n) => n.tags.contains(alias));
    if (nodesWithTag.isNotEmpty) {
      return nodesWithTag.expand((n) => n.ipAddresses).toList();
    }
    return [alias]; // Could be a raw IP
  }

  NodePermission getPermissionsForNode(Node node) {
    final allowedPeers = <AllowedPeer>[];
    final allowedSubnets = <AllowedSubnet>[];
    final allowedExitNodes = <AllowedExitNode>[];
    final Set<String> processedRules = HashSet();

    if (!aclPolicy.containsKey('acls')) {
      return NodePermission(allowedPeers: [], allowedSubnets: [], allowedExitNodes: []);
    }

    final List<dynamic> acls = aclPolicy['acls'];

    for (var rule in acls) {
      if (rule['action'] != 'accept') continue;

      final List<String> sources = (rule['src'] as List).cast<String>();
      final sourceIps = sources.expand((s) => _resolveAlias(s, node)).toSet();
      if (!sourceIps.any((ip) => node.ipAddresses.contains(ip))) {
        continue;
      }

      final List<String> destinations = (rule['dst'] as List).cast<String>();
      final List<String> defaultPorts = (rule['ports'] as List?)?.cast<String>() ?? ['*'];

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

        final List<String> resolvedDestIpsOrCidrs = _resolveAlias(destAddr, node).toList();

        for (var destIpOrCidr in resolvedDestIpsOrCidrs) {
          final trimmedDest = destIpOrCidr.trim();
          if (IpUtils.isCIDR(trimmedDest)) {
            final sourceNode = _routeSourceMap[trimmedDest];
            allowedSubnets.add(AllowedSubnet(subnet: trimmedDest, ports: ports, sourceNode: sourceNode));
          } else if (_nodeIpMap.containsKey(trimmedDest)) {
            final destNode = _nodeIpMap[trimmedDest]!;
            if (destNode.id == node.id) continue;

            if (destNode.isExitNode) {
              allowedExitNodes.add(AllowedExitNode(node: destNode));
            } else {
              allowedPeers.add(AllowedPeer(node: destNode, ports: ports));
            }

            for (var route in destNode.sharedRoutes) {
              allowedSubnets.add(AllowedSubnet(subnet: route.trim(), ports: ports, sourceNode: destNode));
            }
          }
        }
      }
    }

    // Deduplicate and merge permissions
    final uniquePeers = <String, AllowedPeer>{};
    for (var peer in allowedPeers) {
      if (uniquePeers.containsKey(peer.node.id)) {
        final existingPorts = uniquePeers[peer.node.id]!.ports;
        final newPorts = {...existingPorts, ...peer.ports}.toSet().toList();
        if (newPorts.length > 1) newPorts.remove('*');
        uniquePeers[peer.node.id] = AllowedPeer(node: peer.node, ports: newPorts);
      } else {
        uniquePeers[peer.node.id] = peer;
      }
    }

    final subnetMap = <String, AllowedSubnet>{};
    for (var subnet in allowedSubnets) {
      final key = subnet.subnet.trim();
      if (subnetMap.containsKey(key)) {
        final existing = subnetMap[key]!;
        final newPorts = {...existing.ports, ...subnet.ports}.toSet().toList();
        if (newPorts.length > 1) newPorts.remove('*');

        // Prefer the entry that has a source node.
        final sourceNode = subnet.sourceNode ?? existing.sourceNode;

        subnetMap[key] = AllowedSubnet(
          subnet: key,
          ports: newPorts,
          sourceNode: sourceNode,
        );
      } else {
        subnetMap[key] = AllowedSubnet(
          subnet: key,
          ports: subnet.ports,
          sourceNode: subnet.sourceNode,
        );
      }
    }

    final uniqueExitNodes = LinkedHashMap<String, AllowedExitNode>.fromEntries(
            allowedExitNodes.map((e) => MapEntry(e.node.id, e)))
        .values
        .toList();

    return NodePermission(
      allowedPeers: uniquePeers.values.toList(),
      allowedSubnets: subnetMap.values.toList(),
      allowedExitNodes: uniqueExitNodes,
    );
  }
}
