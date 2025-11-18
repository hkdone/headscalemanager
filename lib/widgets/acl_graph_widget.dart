import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:headscalemanager/models/node.dart' as headscale_node;
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/widgets/diamond_painter.dart';

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

class _AclGraphWidgetState extends State<AclGraphWidget> {
  final Graph graph = Graph();
  late AclParserService _parser;
  final Map<String, headscale_node.Node> _idToNodeMap = {};
  bool _graphBuilt = false;
  final BuchheimWalkerConfiguration configuration =
      BuchheimWalkerConfiguration();

  @override
  void initState() {
    super.initState();

    configuration
      ..siblingSeparation = (100)
      ..levelSeparation = (100)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_graphBuilt) {
      _buildGraph();
      _graphBuilt = true;
    }
  }

  void _buildGraph() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color intraUserColor =
        isDarkMode ? Colors.cyanAccent[200]! : Colors.blue[800]!;
    final Color interUserColor =
        isDarkMode ? Colors.amberAccent[200]! : Colors.purple[800]!;
    final Color defaultColor =
        isDarkMode ? Colors.grey[600]! : Colors.grey[800]!;

    final userNodeMap = <String, Node>{};
    final machineNodeMap = <String, Node>{};

    final serverNode = Node.Id('server_headscale_server');
    graph.addNode(serverNode);

    for (var user in widget.users) {
      final userNode = Node.Id('user_${user.id}');
      userNodeMap[user.name] = userNode;
      graph.addNode(userNode);
      graph.addEdge(serverNode, userNode,
          paint: Paint()
            ..color = defaultColor
            ..strokeWidth = 1.5);
    }

    for (var machine in widget.nodes) {
      final machineNode = Node.Id('machine_${machine.id}');
      machineNodeMap[machine.id] = machineNode;
      graph.addNode(machineNode);

      final userNode = userNodeMap[machine.user];
      if (userNode != null) {
        graph.addEdge(userNode, machineNode,
            paint: Paint()
              ..color = defaultColor
              ..strokeWidth = 1.5);
      }

      final permissions = _parser.getPermissionsForNode(machine);

      for (var peer in permissions.allowedPeers) {
        final destMachineNode = machineNodeMap[peer.node.id];
        if (destMachineNode != null) {
          if (graph.edges.every((edge) => !(edge.source == destMachineNode &&
              edge.destination == machineNode))) {
            final destMachine = _idToNodeMap[peer.node.id];
            Color color;
            if (destMachine != null) {
              color = machine.user == destMachine.user
                  ? intraUserColor
                  : interUserColor;
            } else {
              color = defaultColor;
            }
            graph.addEdge(machineNode, destMachineNode,
                paint: Paint()
                  ..color = color
                  ..strokeWidth = 2.0);
          }
        }
      }

      if (machine.isExitNode) {
        final exitNodeSymbol = Node.Id('exit_${machine.id}');
        graph.addNode(exitNodeSymbol);
        graph.addEdge(machineNode, exitNodeSymbol,
            paint: Paint()
              ..color = defaultColor
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke);
      }

      if (machine.sharedRoutes.isNotEmpty) {
        final subnetSymbol = Node.Id('subnet_${machine.id}');
        graph.addNode(subnetSymbol);
        graph.addEdge(machineNode, subnetSymbol,
            paint: Paint()
              ..color = defaultColor
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke);
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

  dynamic _getItemFromNode(Node node) {
    final prefixedId = node.key!.value as String;

    if (prefixedId == 'server_headscale_server') {
      return {'type': 'server', 'url': widget.serverUrl};
    }

    if (prefixedId.startsWith('user_')) {
      final userId = prefixedId.substring(5);
      final user = widget.users.firstWhere((u) => u.id == userId,
          orElse: () => User(id: '', name: '', createdAt: DateTime.now()));
      if (user.id.isNotEmpty) return user;
    }

    if (prefixedId.startsWith('machine_')) {
      final machineId = prefixedId.substring(8);
      final machine = _idToNodeMap[machineId];
      if (machine != null) return machine;
    }

    if (prefixedId.startsWith('exit_')) {
      final machineId = prefixedId.substring(5);
      return {'type': 'exit', 'machine': _idToNodeMap[machineId]};
    }
    if (prefixedId.startsWith('subnet_')) {
      final machineId = prefixedId.substring(7);
      return {'type': 'subnet', 'machine': _idToNodeMap[machineId]};
    }
    return null;
  }

  void _showDetailsDialog(dynamic itemData) {
    showDialog(
      context: context,
      builder: (context) {
        String title = 'Details';
        List<Widget> content = [];

        if (itemData is User) {
          title = 'User: ${itemData.name}';
          final nodeCount =
              widget.nodes.where((n) => n.user == itemData.name).length;
          content.add(Text('Manages $nodeCount machine(s).'));
        } else if (itemData is headscale_node.Node) {
          title = 'Machine: ${itemData.name}';
          content.addAll([
            Text('User: ${itemData.user}'),
            Text('IPs: ${itemData.ipAddresses.join(', ')}'),
            Text('Tags: ${itemData.tags.join(', ')}'),
            Text('Exit Node: ${itemData.isExitNode ? 'Yes' : 'No'}'),
            Text(
                'Shared Routes: ${itemData.sharedRoutes.isEmpty ? 'None' : itemData.sharedRoutes.join(', ')}'),
          ]);
        } else if (itemData is Map) {
          if (itemData['type'] == 'server') {
            title = 'Headscale Server';
            content.add(Text('URL: ${itemData['url']}'));
          } else {
            final machine = itemData['machine'] as headscale_node.Node?;
            if (itemData['type'] == 'exit') {
              title = 'Exit Node Symbol';
              content.add(Text(
                  'Represents the exit node capability for ${machine?.name ?? 'N/A'}.'));
            } else if (itemData['type'] == 'subnet') {
              title = 'Shared Subnet Symbol';
              content.add(Text(
                  'Represents shared subnets from ${machine?.name ?? 'N/A'}.'));
              content.add(
                  Text('Routes: ${machine?.sharedRoutes.join(', ') ?? ''}'));
            }
          }
        }

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content)),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'))
          ],
        );
      },
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
      } else if (itemData['type'] == 'exit') {
        return _buildSymbolNode(Icons.public, 'Exit Node');
      } else if (itemData['type'] == 'subnet') {
        return _buildSymbolNode(Icons.lan, 'Shared Subnet');
      }
    }
    return Container();
  }

  Widget _buildUserNode(User user) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.blueGrey[100],
        border: Border.all(
            color: isDarkMode ? Colors.blueGrey[700]! : Colors.blueGrey[400]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        user.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildMachineNode(headscale_node.Node machine) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getNodeColor(machine),
        boxShadow: [
          BoxShadow(
              color: _getNodeColor(machine).withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 4)
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: color)),
      ],
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
                .withOpacity(0.5),
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

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.01,
      maxScale: 5.0,
      child: GraphView(
        graph: graph,
        algorithm: TidierTreeLayoutAlgorithm(
            configuration, TreeEdgeRenderer(configuration)),
        paint: Paint()
          ..color = Colors.transparent
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
        builder: (Node node) {
          final item = _getItemFromNode(node);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: item != null ? () => _showDetailsDialog(item) : null,
            child: _buildNodeWidget(node),
          );
        },
      ),
    );
  }
}
