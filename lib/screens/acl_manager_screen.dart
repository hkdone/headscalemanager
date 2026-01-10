import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/widgets/acl_graph_widget.dart';

class AclManagerScreen extends StatefulWidget {
  const AclManagerScreen({super.key});

  @override
  State<AclManagerScreen> createState() => _AclManagerScreenState();
}

class _PermissionRowData {
  final String destination;
  final String type;
  final String ports;
  final String source;

  _PermissionRowData({
    required this.destination,
    required this.type,
    required this.ports,
    required this.source,
  });
}

class _AclManagerScreenState extends State<AclManagerScreen> {
  bool _isLoading = true;
  String? _error;
  List<User> _users = [];
  List<Node> _nodes = [];
  Map<String, dynamic> _aclPolicy = {};
  bool _showGraphView = true;
  String _serverUrl = '';
  Key _graphKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (mounted && showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      final results = await Future.wait([
        apiService.getUsers(),
        apiService.getNodes(),
        apiService.getAclPolicy().then((p) => jsonDecode(p)),
      ]);

      if (mounted) {
        setState(() {
          _users = results[0] as List<User>;
          _nodes = results[1] as List<Node>;
          _aclPolicy = results[2] as Map<String, dynamic>;
          _serverUrl = appProvider.activeServer?.url ?? '';
          _graphKey = UniqueKey(); // Force graph widget to rebuild
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title:
            Text('View', style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: Icon(_showGraphView ? Icons.list_alt : Icons.account_tree),
            tooltip: _showGraphView
                ? (isFr ? 'Vue tableau' : 'Table View')
                : (isFr ? 'Vue graphique' : 'Graph View'),
            onPressed: () {
              setState(() {
                _showGraphView = !_showGraphView;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildBody(isFr),
      ),
    );
  }

  Widget _buildBody(bool isFr) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '${isFr ? 'Erreur' : 'Error'}: $_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(isFr ? 'Aucun utilisateur trouvé.' : 'No users found.'),
      );
    }

    if (_showGraphView) {
      return AclGraphWidget(
        key: _graphKey,
        users: _users,
        nodes: _nodes,
        aclPolicy: _aclPolicy,
        serverUrl: _serverUrl,
      );
    } else {
      final parser = AclParserService(
        aclPolicy: _aclPolicy,
        allNodes: _nodes,
        allUsers: _users,
      );
      return ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final userNodes =
              _nodes.where((node) => node.user == user.name).toList();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(user.name,
                  style: Theme.of(context).textTheme.titleLarge),
              children: userNodes
                  .map((node) => _buildNodePermissionTile(node, parser, isFr))
                  .toList(),
            ),
          );
        },
      );
    }
  }

  Widget _buildNodePermissionTile(
      Node node, AclParserService parser, bool isFr) {
    final permissions = parser.getPermissionsForNode(node);

    return ExpansionTile(
      title: Row(
        children: [
          Icon(Icons.computer,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              node.name,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (node.isExitNode)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.exit_to_app, size: 16, color: Colors.orange),
            ),
        ],
      ),
      subtitle: Text(node.ipAddresses.join(', '),
          style: Theme.of(context).textTheme.bodySmall),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      children: _buildPermissionSections(permissions, isFr),
    );
  }

  List<Widget> _buildPermissionSections(NodePermission permissions, bool isFr) {
    final rows = <_PermissionRowData>[];

    rows.addAll(permissions.allowedPeers.map((p) => _PermissionRowData(
          destination: p.node.name,
          type: isFr ? 'Pair' : 'Peer',
          ports: p.ports.join(', '),
          source: 'N/A',
        )));

    rows.addAll(permissions.allowedSubnets.map((s) => _PermissionRowData(
          destination: s.subnet,
          type: isFr ? 'Sous-réseau' : 'Subnet',
          ports: s.ports.join(', '),
          source: s.sourceNode?.name ?? (isFr ? 'Inconnu' : 'Unknown'),
        )));

    rows.addAll(permissions.allowedExitNodes.map((e) => _PermissionRowData(
          destination: e.node.name,
          type: 'Exit Node',
          ports: '*',
          source: e.sourceNode?.name ?? (isFr ? 'Direct' : 'Direct'),
        )));

    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Text(
              isFr
                  ? 'Aucune permission spécifique trouvée.'
                  : 'No specific permissions found.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ];
    }

    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          columns: [
            DataColumn(
                label: Text(isFr ? 'Destination' : 'Destination',
                    style: Theme.of(context).textTheme.titleSmall)),
            DataColumn(
                label: Text(isFr ? 'Type' : 'Type',
                    style: Theme.of(context).textTheme.titleSmall)),
            DataColumn(
                label: Text(isFr ? 'Ports' : 'Ports',
                    style: Theme.of(context).textTheme.titleSmall)),
            DataColumn(
                label: Text(isFr ? 'Source' : 'Source',
                    style: Theme.of(context).textTheme.titleSmall)),
          ],
          rows: rows.map((rowData) {
            return DataRow(cells: [
              DataCell(Text(rowData.destination)),
              DataCell(Text(rowData.type)),
              DataCell(Text(rowData.ports)),
              DataCell(Text(rowData.source)),
            ]);
          }).toList(),
        ),
      ),
    ];
  }
}