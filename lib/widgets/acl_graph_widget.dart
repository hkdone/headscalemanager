import 'dart:math' as math;
import 'dart:ui'; // Pour PathMetric et l'animation
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:headscalemanager/models/node.dart' as headscale_node;
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/widgets/diamond_painter.dart';
import 'package:headscalemanager/utils/string_utils.dart';

// Renderer vide car on gère l'affichage des nœuds via le builder de GraphView
class _NoOpEdgeRenderer extends EdgeRenderer {
  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {}
}

class AclGraphWidget extends StatefulWidget {
  final List<User> users;
  final List<headscale_node.Node> nodes;
  final Map<String, dynamic> aclPolicy;
  final String serverUrl;

  const AclGraphWidget({
    super.key,
    required this.users,
    required this.nodes,
    required this.aclPolicy,
    required this.serverUrl,
  });

  @override
  State<AclGraphWidget> createState() => _AclGraphWidgetState();
}

class _AclGraphWidgetState extends State<AclGraphWidget>
    with SingleTickerProviderStateMixin {
  final Graph graph = Graph();
  late AclParserService _parser;
  final Map<String, headscale_node.Node> _idToNodeMap = {};
  final Map<Node, Widget> _nodeWidgetCache = {};
  bool _graphBuilt = false;
  String? _graphError;
  final TransformationController _transformationController =
      TransformationController();
  late final BuchheimWalkerConfiguration _configuration;
  late final TidierTreeLayoutAlgorithm _algorithm;
  late final TidierTreeLayoutAlgorithm _nodeAlgorithm;
  late final AnimationController _animationController;

  // Padding interne pour éviter que le graphe ne touche les bords (règle l'overflow du canvas)
  final double _graphPadding = 150.0;

  // Empilement stable des symboles sous chaque machine (LAN, Exit, Taildrive)
  static const double _symbolHeight = 90.0;
  static const double _ownerSymbolBaseOffset = 120.0;
  static const double _ownerSymbolStackGap = 28.0;
  static const double _crossUserGap = 40.0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat();

    _configuration = BuchheimWalkerConfiguration()
      ..siblingSeparation = (25) // Rapproché pour compacter les utilisateurs
      ..levelSeparation = (180) // Espace vertical
      ..subtreeSeparation = (30) // Rapproché pour compacter les groupes
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);

    // Utilisation du Painter "Fibre Optique" personnalisé
    _algorithm = TidierTreeLayoutAlgorithm(
      _configuration,
      FiberCurvedEdgePainter(
          _configuration, _animationController, _idToNodeMap),
    );

    _nodeAlgorithm = TidierTreeLayoutAlgorithm(
      _configuration,
      _NoOpEdgeRenderer(),
    );

    _parser = AclParserService(
      aclPolicy: widget.aclPolicy,
      allNodes: widget.nodes,
      allUsers: widget.users,
    );

    for (var node in widget.nodes) {
      _idToNodeMap[node.id] = node;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_graphBuilt) {
      try {
        _buildGraph();
        _algorithm.run(graph, 0, 0);
        _adjustNodePositions();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          try {
            _centerAndZoomGraph();
          } catch (e, stack) {
            debugPrint('ACL graph zoom error: $e\n$stack');
          }
        });
      } catch (e, stack) {
        debugPrint('ACL graph build error: $e\n$stack');
        _graphError = e.toString();
      }
      _graphBuilt = true;
    }
  }

  void _centerAndZoomGraph() {
    if (graph.nodes.isEmpty) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var node in graph.nodes) {
      minX = math.min(minX, node.x);
      minY = math.min(minY, node.y);
      maxX = math.max(maxX, node.x + node.width);
      maxY = math.max(maxY, node.y + node.height);
    }

    final graphWidth = maxX - minX;
    final graphHeight = maxY - minY;

    if (graphWidth <= 0 || graphHeight <= 0) return;

    final scaleX = screenWidth / graphWidth;
    final scaleY = screenHeight / graphHeight;
    final scale = math.min(scaleX, scaleY) * 0.6; // 60% pour avoir une marge

    final scaledGraphWidth = graphWidth * scale;
    final scaledGraphHeight = graphHeight * scale;

    // Centrer le graphe à l'écran
    final dx = (screenWidth - scaledGraphWidth) / 2 - (minX * scale);
    final dy = (screenHeight - scaledGraphHeight) / 2 - (minY * scale);

    final matrix = Matrix4.identity()
      ..setTranslationRaw(dx, dy, 0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    _transformationController.value = matrix;
  }

  void _adjustNodePositions() {
    final ownerSymbolBottoms = <String, double>{};

    // 1. Symboles rattachés à une machine : colonne verticale stable sous le propriétaire
    final ownerSymbolNodes = graph.nodes.where((n) {
      final id = n.key?.value;
      if (id is! String) return false;
      return id.startsWith('lan_symbol_') ||
          id.startsWith('internet_symbol_') ||
          id.startsWith('taildrive_symbol_');
    }).toList()
      ..sort((a, b) {
        final aId = a.key?.value?.toString() ?? '';
        final bId = b.key?.value?.toString() ?? '';
        final ownerA = _resolveSymbolOwnerId(aId) ?? '';
        final ownerB = _resolveSymbolOwnerId(bId) ?? '';
        final ownerCmp = ownerA.compareTo(ownerB);
        if (ownerCmp != 0) return ownerCmp;
        return _symbolStackOrder(aId).compareTo(_symbolStackOrder(bId));
      });

    final ownerSymbolStacks = <String, int>{};

    for (var symbolNode in ownerSymbolNodes) {
      final symbolId = symbolNode.key?.value;
      if (symbolId is! String) continue;

      final ownerId = _resolveSymbolOwnerId(symbolId);
      if (ownerId == null) continue;

      final ownerGraphNode = _graphNodeForMachine(ownerId);
      if (ownerGraphNode == null) continue;

      final stackIndex = ownerSymbolStacks[ownerId] ?? 0;
      ownerSymbolStacks[ownerId] = stackIndex + 1;

      symbolNode.x = ownerGraphNode.x;
      symbolNode.y = ownerGraphNode.y +
          _ownerSymbolBaseOffset +
          stackIndex * (_symbolHeight + _ownerSymbolStackGap);

      ownerSymbolBottoms[ownerId] = symbolNode.y + _symbolHeight;
    }

    // 2. Partages inter-utilisateurs : centrés entre les deux machines, sous leurs symboles
    final sharedPeerNodes = graph.nodes.where((n) {
      final id = n.key?.value;
      return id is String && id.startsWith('shared_peer_');
    }).toList()
      ..sort((a, b) =>
          (a.key?.value?.toString() ?? '').compareTo(b.key?.value?.toString() ?? ''));

    final crossUserStacks = <int, int>{};

    for (var sharedNode in sharedPeerNodes) {
      final parentEdges =
          graph.edges.where((e) => e.destination == sharedNode).toList();
      if (parentEdges.isEmpty) continue;

      final parents = parentEdges.map((e) => e.source).toList();
      final anchorParents = parents.length >= 2 ? parents.sublist(0, 2) : parents;

      double maxBottom = 0;
      for (var parent in anchorParents) {
        final machineId = _machineIdFromGraphNode(parent);
        final bottom = machineId != null && ownerSymbolBottoms.containsKey(machineId)
            ? ownerSymbolBottoms[machineId]!
            : parent.y + 60;
        if (bottom > maxBottom) maxBottom = bottom;
      }

      final midX = anchorParents.length == 1
          ? anchorParents.first.x
          : (anchorParents[0].x + anchorParents[1].x) / 2;

      final bucket = (midX / 80).round();
      final stackIndex = crossUserStacks[bucket] ?? 0;
      crossUserStacks[bucket] = stackIndex + 1;

      sharedNode.x = midX;
      sharedNode.y = maxBottom +
          _crossUserGap +
          stackIndex * (_symbolHeight + _ownerSymbolStackGap);
    }
  }

  int _symbolStackOrder(String symbolId) {
    if (symbolId.startsWith('lan_symbol_')) return 0;
    if (symbolId.startsWith('internet_symbol_')) return 1;
    if (symbolId.startsWith('taildrive_symbol_')) return 2;
    return 3;
  }

  String? _machineIdFromGraphNode(Node node) {
    final id = node.key?.value;
    if (id is String && id.startsWith('machine_')) {
      return id.substring(8);
    }
    return null;
  }

  Node? _graphNodeForMachine(String machineId) {
    try {
      return graph.nodes
          .firstWhere((n) => n.key?.value == 'machine_$machineId');
    } catch (_) {
      return null;
    }
  }

  String? _resolveSymbolOwnerId(String symbolId) {
    if (symbolId.startsWith('internet_symbol_')) {
      return symbolId.substring('internet_symbol_'.length);
    }

    if (symbolId.startsWith('taildrive_symbol_')) {
      final body = symbolId.substring('taildrive_symbol_'.length);
      final lastSep = body.lastIndexOf('_');
      if (lastSep > 0) return body.substring(lastSep + 1);
      return null;
    }

    if (symbolId.startsWith('lan_symbol_')) {
      final body = symbolId.substring('lan_symbol_'.length);
      for (final id in _idToNodeMap.keys) {
        if (body.startsWith('${id}_') || body == id) return id;
      }
      final parts = body.split('_');
      if (parts.isNotEmpty && _idToNodeMap.containsKey(parts.first)) {
        return parts.first;
      }
    }

    return null;
  }

  void _buildGraph() {
    _nodeWidgetCache.clear();
    graph.nodes.clear();
    graph.edges.clear();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color intraUserColor =
        isDarkMode ? Colors.cyanAccent[200]! : Colors.blue[800]!;
    final Color interUserColor =
        isDarkMode ? Colors.amberAccent[200]! : Colors.purple[800]!;
    final Color exitNodeLinkColor = isDarkMode
        ? Colors.greenAccent[400]!
        : const Color.fromARGB(255, 0, 128, 6);
    final Color structureColor = Colors.orange;

    final userNodeMap = <String, Node>{};
    final machineNodeMap = <String, Node>{};
    final routeSymbolMap = <String, Node>{};

    // --- Pass 1: Nodes & Structure ---
    final serverNode = Node.Id('server_headscale_server');
    graph.addNode(serverNode);

    for (var user in widget.users) {
      final userNode = Node.Id('user_${user.id}');
      userNodeMap[user.name] = userNode;
      graph.addNode(userNode);
      graph.addEdge(serverNode, userNode,
          paint: Paint()..color = structureColor);
    }

    for (var machine in widget.nodes) {
      final machineNode = Node.Id('machine_${machine.id}');
      machineNodeMap[machine.id] = machineNode;
      graph.addNode(machineNode);

      final owner = machine.getNormalizedOwner();
      User? matchedUser;
      for (var u in widget.users) {
        if (normalizeUserName(u.name) == owner) {
          matchedUser = u;
          break;
        }
      }
      final userNode = matchedUser != null ? userNodeMap[matchedUser.name] : null;
      if (userNode != null) {
        graph.addEdge(userNode, machineNode,
            paint: Paint()..color = structureColor);
      }

      for (var route in machine.sharedRoutes) {
        final trimmedRoute = route.trim();
        final isExitRoute =
            trimmedRoute == '0.0.0.0/0' || trimmedRoute == '::/0';
        final symbolId = isExitRoute
            ? 'internet_symbol_${machine.id}'
            : 'lan_symbol_${machine.id}_${trimmedRoute.replaceAll('/', '_')}';

        Node routeSymbolNode;
        if (routeSymbolMap.containsKey(symbolId)) {
          routeSymbolNode = routeSymbolMap[symbolId]!;
        } else {
          routeSymbolNode = Node.Id(symbolId);
          routeSymbolMap[symbolId] = routeSymbolNode;
          graph.addNode(routeSymbolNode);
        }
        // Lien rouge structurel (Propriétaire -> Route)
        graph.addEdge(machineNode, routeSymbolNode,
            paint: Paint()
              ..color = const Color.fromARGB(255, 255, 0, 0)
              ..strokeWidth = 4
              ..style = PaintingStyle.stroke);
      }
    }

    // --- Pass 2: Permissions ---
    for (var machine in widget.nodes) {
      final sourceMachineNode = machineNodeMap[machine.id]!;
      final permissions = _parser.getPermissionsForNode(machine);

      for (var subnetPermission in permissions.allowedSubnets) {
        // IMPORTANT : On utilise subnetPermission.subnet (le PARENT) pour lier graphiquement
        final trimmedRoute = subnetPermission.subnet.trim();
        String? ownerNodeId = subnetPermission.sourceNode?.id;
        if (ownerNodeId == null) {
          for (var node in widget.nodes) {
            if (node.sharedRoutes.contains(trimmedRoute)) {
              ownerNodeId = node.id;
              break;
            }
          }
        }
        final symbolId = ownerNodeId != null
            ? 'lan_symbol_${ownerNodeId}_${trimmedRoute.replaceAll('/', '_')}'
            : 'lan_symbol_${trimmedRoute.replaceAll('/', '_')}'; // Fallback
        final routeSymbolNode = routeSymbolMap[symbolId];

        if (routeSymbolNode != null) {
          if (graph.edges.any((e) =>
              e.source == sourceMachineNode &&
              e.destination == routeSymbolNode)) {
            continue;
          }
          final permissionSourceNode = subnetPermission.sourceNode;
          final color = (permissionSourceNode != null &&
                  machine.getNormalizedOwner() ==
                      permissionSourceNode.getNormalizedOwner())
              ? intraUserColor
              : interUserColor;

          graph.addEdge(sourceMachineNode, routeSymbolNode,
              paint: Paint()
                ..color = color
                ..strokeWidth = 2.0
                ..style = PaintingStyle.stroke);
        }
      }

      for (var exitNodePermission in permissions.allowedExitNodes) {
        final permissionSourceNode = exitNodePermission.sourceNode;
        if (permissionSourceNode == null) continue;

        final symbolId = 'internet_symbol_${permissionSourceNode.id}';
        final routeSymbolNode = routeSymbolMap[symbolId];

        if (routeSymbolNode != null) {
          if (graph.edges.any((e) =>
              e.source == sourceMachineNode &&
              e.destination == routeSymbolNode)) {
            continue;
          }
          final color = (machine.getNormalizedOwner() ==
                  permissionSourceNode.getNormalizedOwner())
              ? intraUserColor
              : interUserColor;

          graph.addEdge(sourceMachineNode, routeSymbolNode,
              paint: Paint()
                ..color = color
                ..strokeWidth = 2.0
                ..style = PaintingStyle.stroke);
        }
      }

      for (var peerPermission in permissions.allowedPeers) {
        final destMachine = peerPermission.node;
        final destMachineNode = machineNodeMap[destMachine.id];
        if (destMachineNode == null) continue;

        if (machine.getNormalizedOwner() ==
            destMachine.getNormalizedOwner()) {
          if (graph.edges.every((edge) => !(edge.source == destMachineNode &&
              edge.destination == sourceMachineNode))) {
            graph.addEdge(sourceMachineNode, destMachineNode,
                paint: Paint()
                  ..color = intraUserColor
                  ..strokeWidth = 2.0);
          }
        } else {
          final ids = [machine.id, destMachine.id]..sort();
          final symbolId = 'shared_peer_${ids[0]}_${ids[1]}';

          var sharedPeerSymbolNode = graph.nodes.firstWhere(
              (n) => n.key?.value == symbolId,
              orElse: () => Node.Id(symbolId));

          if (!graph.nodes.contains(sharedPeerSymbolNode)) {
            graph.addNode(sharedPeerSymbolNode);
          }
          if (!graph.edges.any((e) =>
              e.source == sourceMachineNode &&
              e.destination == sharedPeerSymbolNode)) {
            graph.addEdge(sourceMachineNode, sharedPeerSymbolNode,
                paint: Paint()
                  ..color = interUserColor
                  ..strokeWidth = 2.0);
          }
          if (!graph.edges.any((e) =>
              e.source == destMachineNode &&
              e.destination == sharedPeerSymbolNode)) {
            graph.addEdge(destMachineNode, sharedPeerSymbolNode,
                paint: Paint()
                  ..color = interUserColor
                  ..strokeWidth = 2.0);
          }
        }
      }

      for (var tdGrant in permissions.allowedTaildriveShares) {
        for (var sourceNode in tdGrant.sourceNodes) {
          final symbolId =
              'taildrive_symbol_${tdGrant.shareName}_${sourceNode.id}';

          Node tdSymbolNode;
          if (routeSymbolMap.containsKey(symbolId)) {
            tdSymbolNode = routeSymbolMap[symbolId]!;
          } else {
            tdSymbolNode = Node.Id(symbolId);
            routeSymbolMap[symbolId] = tdSymbolNode;
            graph.addNode(tdSymbolNode);

            // Lien structurel (Nœud source -> Symbole Taildrive)
            final targetMachineNode = machineNodeMap[sourceNode.id];
            if (targetMachineNode != null) {
              graph.addEdge(targetMachineNode, tdSymbolNode,
                  paint: Paint()
                    ..color = Colors.orange
                    ..strokeWidth = 4
                    ..style = PaintingStyle.stroke);
            }
          }

          // Lien de permission (Nœud recipient -> Symbole Taildrive)
          final color = (machine.getNormalizedOwner() ==
                  sourceNode.getNormalizedOwner())
              ? intraUserColor
              : interUserColor;

          if (!graph.edges.any((e) =>
              e.source == sourceMachineNode && e.destination == tdSymbolNode)) {
            graph.addEdge(sourceMachineNode, tdSymbolNode,
                paint: Paint()
                  ..color = color
                  ..strokeWidth = 2.0
                  ..style = PaintingStyle.stroke);
          }
        }
      }
    }

    // --- Pass 3: Implicit Intra-user Exit Node ---
    final userExitNodes = <String, List<headscale_node.Node>>{};
    for (var node in widget.nodes) {
      if (node.isExitNode) {
        userExitNodes
            .putIfAbsent(node.getNormalizedOwner(), () => [])
            .add(node);
      }
    }

    for (var machine in widget.nodes) {
      final exitNodesForUser = userExitNodes[machine.getNormalizedOwner()];
      if (exitNodesForUser == null) continue;

      final sourceMachineNode = machineNodeMap[machine.id]!;

      for (var exitNode in exitNodesForUser) {
        if (machine.id == exitNode.id) continue;

        final symbolId = 'internet_symbol_${exitNode.id}';
        final routeSymbolNode = routeSymbolMap[symbolId];

        if (routeSymbolNode != null) {
          if (graph.edges.any((e) =>
              e.source == sourceMachineNode &&
              e.destination == routeSymbolNode)) {
            continue;
          }

          graph.addEdge(sourceMachineNode, routeSymbolNode,
              paint: Paint()
                ..color = exitNodeLinkColor
                ..strokeWidth = 2.0
                ..style = PaintingStyle.stroke);
        }
      }
    }
  }

  Color _getNodeColor(headscale_node.Node node) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasSharedRoutes = node.sharedRoutes.isNotEmpty;
    final isExit = node.isExitNode;

    if (isDarkMode) {
      if (isExit && hasSharedRoutes) return Colors.purpleAccent[100]!;
      if (isExit) return Colors.redAccent[100]!;
      if (hasSharedRoutes) return Colors.orangeAccent[100]!;
      return Theme.of(context).colorScheme.primary;
    } else {
      if (isExit && hasSharedRoutes) return Colors.purple[700]!;
      if (isExit) return Colors.red[700]!;
      if (hasSharedRoutes) return Colors.orange[800]!;
      return Theme.of(context).colorScheme.primary;
    }
  }

  // Récupération des données
  dynamic _getItemFromNode(Node node) {
    final key = node.key?.value;
    if (key is! String) return null;
    final prefixedId = key;

    if (prefixedId == 'server_headscale_server') {
      return {'type': 'server', 'url': widget.serverUrl};
    }
    if (prefixedId.startsWith('user_')) {
      final userId = prefixedId.substring(5);
      final user = widget.users.firstWhere((u) => u.id == userId,
          orElse: () =>
              User(id: '', name: 'Inconnu', createdAt: DateTime.now()));
      if (user.id.isNotEmpty) return user;
    }
    if (prefixedId.startsWith('machine_')) {
      final machineId = prefixedId.substring(8);
      final machine = _idToNodeMap[machineId];
      if (machine != null) return machine;
    }
    if (prefixedId.startsWith('internet_symbol_')) {
      final machineId = prefixedId.substring(16);
      final machine = _idToNodeMap[machineId];
      return {'type': 'internet', 'machine': machine};
    }
    if (prefixedId.startsWith('taildrive_symbol_')) {
      final parts = prefixedId.split('_');
      final shareName = parts[2];
      final machineId = parts[3];
      final machine = _idToNodeMap[machineId];
      return {'type': 'taildrive', 'share': shareName, 'machine': machine};
    }
    if (prefixedId.startsWith('lan_symbol_')) {
      // Nouveau format: lan_symbol_nodeId_192.168.1.0_24
      final parts = prefixedId.substring(11).split('_');
      if (parts.length >= 3) {
        final nodeId = parts[0];
        final routeParts = parts.sublist(1);
        final route = routeParts.join('_').replaceAll('_', '/');
        final ownerNode = _idToNodeMap[nodeId];
        return {'type': 'lan', 'route': route, 'owner': ownerNode};
      }
      // Fallback pour ancien format
      final route = prefixedId.substring(11).replaceAll('_', '/');
      return {'type': 'lan', 'route': route};
    }
    if (prefixedId.startsWith('shared_peer_')) {
      final ids = prefixedId.substring(12).split('_');
      final node1 = _idToNodeMap[ids[0]];
      final node2 = _idToNodeMap[ids[1]];
      return {'type': 'shared_peer', 'node1': node1, 'node2': node2};
    }
    return null;
  }

  void _showDetailsDialog(dynamic itemData) {
    showDialog(
      context: context,
      builder: (context) {
        String title = 'Détails';
        List<Widget> content = [];

        if (itemData is User) {
          title = 'Utilisateur : ${itemData.name}';
          final normalizedName = normalizeUserName(itemData.name);
          final nodeCount = widget.nodes
              .where((n) => n.getNormalizedOwner() == normalizedName)
              .length;
          content.add(Text('Cet utilisateur gère $nodeCount machine(s).'));
          content.add(const SizedBox(height: 8));
          content.add(Text('ID : ${itemData.id}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)));
        } else if (itemData is headscale_node.Node) {
          title = 'Machine : ${itemData.name}';
          content.addAll([
            (() {
              final owner = itemData.getNormalizedOwner();
              final matchedUser = widget.users.firstWhere(
                (u) => normalizeUserName(u.name) == owner,
                orElse: () =>
                    User(id: '', name: owner, createdAt: DateTime.now()),
              );
              return _buildDetailRow('Propriétaire', matchedUser.name);
            }()),
            _buildDetailRow('IPs', itemData.ipAddresses.join('\n')),
            _buildDetailRow('Exit Node', itemData.isExitNode ? 'Oui' : 'Non'),
            if (itemData.tags.isNotEmpty)
              _buildDetailRow('Tags', itemData.tags.join(', ')),
            if (itemData.sharedRoutes.isNotEmpty)
              _buildDetailRow(
                  'Routes partagées', itemData.sharedRoutes.join(', ')),
          ]);
        } else if (itemData is Map) {
          if (itemData['type'] == 'server') {
            title = 'Serveur Headscale';
            content.add(Text('URL du serveur : ${itemData['url']}'));
            content.add(const Text(
                '\nC\'est le point central de votre réseau (Control Plane).'));
          } else if (itemData['type'] == 'internet') {
            final machine = itemData['machine'] as headscale_node.Node?;
            title = 'Accès Internet (Exit Node)';
            content
                .add(const Text('Ce symbole représente l\'accès à Internet.'));
            content.add(const SizedBox(height: 10));
            content.add(Text(
                'Le trafic passe par la machine "${machine?.name ?? 'Inconnue'}" qui agit comme passerelle de sortie.',
                style: const TextStyle(fontWeight: FontWeight.bold)));
          } else if (itemData['type'] == 'taildrive') {
            final machine = itemData['machine'] as headscale_node.Node?;
            final shareName = itemData['share'] as String;
            title = 'Partage Taildrive';
            content.add(Text('Nom du partage : $shareName',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)));
            content.add(const SizedBox(height: 10));
            content.add(Text(
                'Ce dossier est partagé par la machine "${machine?.name ?? 'Inconnue'}".'));

            content.add(const Divider());
            content.add(const Text('Accès autorisés :',
                style: TextStyle(fontWeight: FontWeight.bold)));
            content.add(const SizedBox(height: 8));

            final accessingNodes = <Widget>[];
            for (var node in widget.nodes) {
              final perms = _parser.getPermissionsForNode(node);
              final matchingPerms = perms.allowedTaildriveShares
                  .where((s) => s.shareName == shareName)
                  .toList();

              if (matchingPerms.isNotEmpty) {
                for (var p in matchingPerms) {
                  accessingNodes.add(Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('${node.name} (${p.access})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ));
                }
              }
            }
            if (accessingNodes.isEmpty) {
              content.add(const Text('Aucun accès distant configuré.',
                  style: TextStyle(fontStyle: FontStyle.italic)));
            } else {
              content.addAll(accessingNodes);
            }
          } else if (itemData['type'] == 'lan') {
            // --- DÉTAILS LAN (AVEC ANALYSE DES PERMISSIONS) ---
            final routeCidr = itemData['route'] as String;
            title = 'Réseau Local (Subnet)';

            content.add(Text('Route : $routeCidr',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)));
            content.add(const SizedBox(height: 10));
            content.add(const Text(
                'Ce symbole indique qu\'une machine partage l\'accès à ce réseau local interne (Advertise Routes).'));

            content.add(const Divider());
            content.add(const Text('Accès autorisés :',
                style: TextStyle(fontWeight: FontWeight.bold)));
            content.add(const SizedBox(height: 8));

            // Analyser qui a accès à CE symbole spécifique
            final accessingNodes = <Widget>[];

            // On parcourt tous les nœuds pour voir qui pointe vers CE subnet
            for (var node in widget.nodes) {
              final perms = _parser.getPermissionsForNode(node);

              // On cherche les permissions qui pointent vers CE subnet parent
              final matchingPerms = perms.allowedSubnets
                  .where((s) => s.subnet == routeCidr)
                  .toList();

              if (matchingPerms.isNotEmpty) {
                final List<String> accessDetails = [];
                bool fullAccess = false;

                for (var p in matchingPerms) {
                  if (p.specificRule == p.subnet) {
                    fullAccess = true;
                  } else {
                    final ports = p.ports.contains('*')
                        ? 'Tout port'
                        : 'Ports: ${p.ports.join(',')}';
                    accessDetails.add('${p.specificRule} ($ports)');
                  }
                }

                String statusText = '';
                if (fullAccess) {
                  statusText = 'Accès complet';
                } else {
                  statusText = 'Partiel : ${accessDetails.join(', ')}';
                }

                accessingNodes.add(Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green[700]),
                      ),
                      const SizedBox(width: 8),
                      Text('${node.name} : ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(statusText,
                              style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ));
              }
            }

            if (accessingNodes.isEmpty) {
              content.add(const Text(
                  'Aucun accès détecté pour d\'autres machines.',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: Colors.grey)));
            } else {
              content.addAll(accessingNodes);
            }
          } else if (itemData['type'] == 'shared_peer') {
            final node1 = itemData['node1'] as headscale_node.Node?;
            final node2 = itemData['node2'] as headscale_node.Node?;
            title = 'Connexion Partagée';
            content.add(const Text(
                'Lien direct (Peer-to-Peer) entre deux utilisateurs différents :'));
            content.add(const Divider());
            content.add(Text('1. ${node1?.name ?? '?'} (${node1?.user})'));
            content.add(const Center(child: Icon(Icons.swap_vert)));
            content.add(Text('2. ${node2?.name ?? '?'} (${node2?.user})'));
          }
        }

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: content)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'))
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label :',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(Node node) {
    final itemData = _getItemFromNode(node);

    if (itemData is User) {
      return _buildUserNode(itemData);
    } else if (itemData is headscale_node.Node) {
      return _buildMachineNode(itemData);
    } else if (itemData is Map) {
      if (itemData['type'] == 'server') {
        return _buildServerNode();
      } else if (itemData['type'] == 'internet') {
        final machine = itemData['machine'] as headscale_node.Node?;
        return _buildSymbolNode(
            Icons.public, 'Exit via\n${machine?.name ?? ''}');
      } else if (itemData['type'] == 'taildrive') {
        return _buildSymbolNode(Icons.folder_shared, itemData['share']);
      } else if (itemData['type'] == 'lan') {
        return _buildSymbolNode(Icons.lan, itemData['route']);
      } else if (itemData['type'] == 'shared_peer') {
        return _buildSymbolNode(Icons.handshake_outlined, 'Shared\nPeer');
      }
    }
    return Container();
  }

  Widget _buildUserNode(User user) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      // Largeur FIXE pour centrage parfait du trait
      width: 120.0,
      height: 50.0,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.blueGrey[100],
        border: Border.all(
            color: isDarkMode ? Colors.blueGrey[700]! : Colors.blueGrey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        user.name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMachineNode(headscale_node.Node machine) {
    final isOnline = machine.online;
    final nodeColor = _getNodeColor(machine);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: nodeColor,
        boxShadow: isOnline
            ? [
                // Halo effect for online nodes
                BoxShadow(
                  color: isDarkMode ? Colors.greenAccent[400]! : Colors.green,
                  spreadRadius: 3,
                  blurRadius: 15,
                  offset: const Offset(0, 0),
                ),
                BoxShadow(
                  color: nodeColor.withValues(alpha: 0.7),
                  spreadRadius: 1,
                  blurRadius: 3,
                )
              ]
            : [
                // Subtle shadow for offline nodes
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                )
              ],
      ),
      child: Center(
        child: Text(
          machine.name.length >= 2
              ? machine.name.substring(0, 2).toUpperCase()
              : machine.name.toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildSymbolNode(IconData icon, String label) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]
        : Colors.grey[700];

    return Container(
      color: Colors.transparent, // Zone transparente cliquable
      width: 60,
      height: 90, // Hauteur augmentée pour le texte (évite l'overflow)
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Collé au haut (au trait)
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildServerNode() {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      width: 80,
      height: 80,
      decoration: ShapeDecoration(
        color: isDarkMode ? Colors.green[800] : Colors.green[200],
        shape: const DiamondBorder(),
        shadows: [
          BoxShadow(
            color: (isDarkMode ? Colors.green[800] : Colors.green[200])!
                .withValues(alpha: 0.5),
            spreadRadius: 2,
            blurRadius: 4,
          )
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.dns,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _getOrCreateNodeWidget(Node node) {
    return _nodeWidgetCache.putIfAbsent(node, () {
      final item = _getItemFromNode(node);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item != null ? () => _showDetailsDialog(item) : null,
        child: _buildNodeWidget(node),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_graphError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Impossible d\'afficher le graphe ACL.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _graphError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      constrained: false, // Important pour laisser le graphe s'étendre
      boundaryMargin:
          const EdgeInsets.all(1000), // Marge énorme pour dézoomer librement
      minScale: 0.001, // Dézoom quasi-infini
      maxScale: 5.0,
      child: Stack(
        children: [
          // Couche 1 : Liens (Edges)
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                padding: EdgeInsets.all(
                    _graphPadding), // Padding pour éviter l'overflow
                child: GraphView(
                  graph: graph,
                  algorithm: _algorithm,
                  builder: (node) {
                    return IgnorePointer(
                      child: Opacity(
                        opacity: 0.0,
                        child: _getOrCreateNodeWidget(node),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // Couche 2 : Nœuds (Nodes) visibles
          Container(
            padding: EdgeInsets.all(_graphPadding), // Même padding pour aligner
            child: GraphView(
              graph: graph,
              algorithm: _nodeAlgorithm,
              builder: _getOrCreateNodeWidget,
              paint: Paint()..color = Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAINTER PERSONNALISÉ : FIBRE, COURBES & ANIMATION ---
class FiberCurvedEdgePainter extends EdgeRenderer {
  final BuchheimWalkerConfiguration configuration;
  final AnimationController animationController;
  final Map<String, headscale_node.Node> idToNodeMap;

  FiberCurvedEdgePainter(
      this.configuration, this.animationController, this.idToNodeMap);

  // Calcul du centre horizontal selon le type
  double _getCenterOffset(String nodeId) {
    if (nodeId.startsWith('server_')) return 40.0; // Largeur 80 -> centre 40
    if (nodeId.startsWith('user_')) return 60.0; // Largeur 120 -> centre 60
    if (nodeId.startsWith('lan_symbol_') ||
        nodeId.startsWith('internet_symbol_') ||
        nodeId.startsWith('taildrive_symbol_') ||
        nodeId.startsWith('shared_peer_')) {
      return 18.0; // Ajustement spécifique symboles bas
    }
    return 30.0; // Défaut (Machine) largeur 60 -> centre 30
  }

  // Calcul du départ vertical selon le type
  double _getVerticalOffset(String nodeId) {
    if (nodeId.startsWith('user_')) return 50.0; // Hauteur User
    if (nodeId.startsWith('server_')) return 80.0; // Hauteur Server
    return 40.0; // Défaut
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final source = edge.source;
    final dest = edge.destination;
    final sourceId = source.key?.value.toString() ?? '';
    final destId = dest.key?.value.toString() ?? '';

    bool isSourceMachineOffline = false;
    if (sourceId.startsWith('machine_')) {
      final machineId = sourceId.substring(8);
      final machine = idToNodeMap[machineId];
      if (machine != null && !machine.online) {
        isSourceMachineOffline = true;
      }
    }

    bool isDestMachineOffline = false;
    if (destId.startsWith('machine_')) {
      final machineId = destId.substring(8);
      final machine = idToNodeMap[machineId];
      if (machine != null && !machine.online) {
        isDestMachineOffline = true;
      }
    }

    final bool shouldAnimate = !isSourceMachineOffline && !isDestMachineOffline;

    // Calcul dynamique des points
    final startX = source.x + _getCenterOffset(sourceId);
    final startY = source.y + _getVerticalOffset(sourceId);
    final endX = dest.x + _getCenterOffset(destId);
    final endY = dest.y;

    // Courbe Sigmoïde
    var path = Path();
    path.moveTo(startX, startY);
    var deltaY = endY - startY;
    var controlPointOffset = deltaY * 0.5;

    path.cubicTo(startX, startY + controlPointOffset, endX,
        endY - controlPointOffset, endX, endY);

    // Type de lien
    bool isStructural = false;
    if (sourceId.startsWith('server_')) isStructural = true;
    if (sourceId.startsWith('user_') && destId.startsWith('machine_')) {
      isStructural = true;
    }
    if (paint.style == PaintingStyle.fill) isStructural = true;

    if (isStructural) {
      // --- FIBRE OPTIQUE (Structure) ---
      final fiberPaint = Paint()
        ..color = const Color.fromARGB(255, 255, 165, 30)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, fiberPaint);

      final flowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 1)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      // Flux inversé (blanc descendant)
      if (shouldAnimate) {
        _drawAnimatedDashes(canvas, path, flowPaint, isReversed: true);
      } else {
        // Dessine une ligne statique si hors ligne
        final staticFlowPaint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, staticFlowPaint);
      }
    } else {
      // --- RÉSEAU (Permissions) ---
      if (shouldAnimate) {
        _drawAnimatedDashes(canvas, path, paint, isReversed: true);
      } else {
        // Dessine une ligne statique si hors ligne
        final staticPaint = Paint()
          ..color = Colors.grey.withValues(alpha: 0.5)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawPath(path, staticPaint);
      }
    }
  }

  void _drawAnimatedDashes(Canvas canvas, Path path, Paint paint,
      {required bool isReversed}) {
    PathMetrics pathMetrics = path.computeMetrics();
    for (PathMetric pathMetric in pathMetrics) {
      double dashWidth = 10.0;
      double dashSpace = 8.0;
      double totalDash = dashWidth + dashSpace;

      double phase;
      if (isReversed) {
        phase = animationController.value * totalDash;
      } else {
        phase = -(animationController.value * totalDash);
      }

      double currentDistance = phase;

      while (currentDistance < pathMetric.length) {
        double start = currentDistance;
        double end = currentDistance + dashWidth;

        double visibleStart = start < 0 ? 0 : start;
        double visibleEnd = end > pathMetric.length ? pathMetric.length : end;

        if (visibleStart < visibleEnd) {
          canvas.drawPath(
              pathMetric.extractPath(visibleStart, visibleEnd), paint);
        }
        currentDistance += totalDash;
      }
    }
  }
}
