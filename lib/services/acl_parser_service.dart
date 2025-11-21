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
          final user = allUsers.firstWhere((u) => u.name == ownerAlias,
              orElse: () => User(id: '', name: '', createdAt: DateTime.now()));
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
      return _aliases[alias]!
          .expand((a) => _resolveAlias(a, sourceNode))
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
          .where((n) => n.user == user.name)
          .expand((n) => n.ipAddresses)
          .toList();
    }
    // If none of the above, treat it as a raw IP or an unresolved alias
    return [alias];
  }

  NodePermission getPermissionsForNode(Node node) {
    final allowedPeers = <AllowedPeer>[];
    final allowedSubnets = <AllowedSubnet>[];
    final allowedExitNodes = <AllowedExitNode>[];
    final Set<String> processedRules = HashSet();

    if (!aclPolicy.containsKey('acls')) {
      return NodePermission(
          allowedPeers: [], allowedSubnets: [], allowedExitNodes: []);
    }

    final List<dynamic> acls = aclPolicy['acls'];

    for (var rule in acls) {
      if (rule['action'] != 'accept') continue;

      final List<String> sources = (rule['src'] as List).cast<String>();
      final sourceIps = sources.expand((s) => _resolveAlias(s, node)).toSet();

      // Vérifie si le nœud actuel est concerné par la source
      bool isSource = sourceIps.any((ip) => node.ipAddresses.contains(ip));
      if (!isSource && !sources.contains('*')) {
        continue;
      }

      final List<String> destinations = (rule['dst'] as List).cast<String>();
      final List<String> defaultPorts =
          (rule['ports'] as List?)?.cast<String>() ?? ['*'];

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

          // CAS 1 : Correspondance exacte
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
          }
          // CAS 2 : Inclusion (Calcul mathématique)
          else {
            bool foundParentRoute = false;

            for (var knownRoute in _routeSourceMap.keys) {
              if (knownRoute == '0.0.0.0/0' || knownRoute == '::/0') continue;

              // Utilisation du nouveau helper
              if (_isIpInSubnet(trimmedDest, knownRoute)) {
                final advertiserNode = _routeSourceMap[knownRoute];
                allowedSubnets.add(AllowedSubnet(
                    subnet: knownRoute, // Parent
                    specificRule: trimmedDest, // Règle spécifique
                    ports: ports,
                    sourceNode: advertiserNode));
                foundParentRoute = true;
                break;
              }
            }

            // CAS 3 : Peer direct
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

    return NodePermission(
      allowedPeers: uniquePeers.values.toList(),
      allowedSubnets: allowedSubnets,
      allowedExitNodes: uniqueExitNodes.values.toList(),
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
