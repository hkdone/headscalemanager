import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/api_keys_screen.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;
const Color _accentColor = Colors.blue;

/// Écran du tableau de bord affichant un aperçu des nœuds Headscale.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Node>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  void _refreshNodes() {
    setState(() {
      _nodesFuture = context.read<AppProvider>().apiService.getNodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<Node>>(
          future: _nodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucun nœud trouvé.'));
            }

            final nodes = snapshot.data!;
            final nodesByUser = <String, List<Node>>{};
            for (var node in nodes) {
              (nodesByUser[node.user] ??= []).add(node);
            }

            final users = nodesByUser.keys.toList();
            final connectedNodes = nodes.where((node) => node.online).length;
            final disconnectedNodes = nodes.length - connectedNodes;

            return Column(
              children: [
                _buildSummarySection(users.length, connectedNodes, disconnectedNodes),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userNodes = nodesByUser[user]!;
                      return _UserNodeCard(user: user, nodes: userNodes);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildSummarySection(int userCount, int connectedCount, int disconnectedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(title: 'Utilisateurs', value: userCount.toString(), color: Colors.grey, icon: Icons.people),
              const SizedBox(height: 40, child: VerticalDivider(thickness: 1)),
              _StatItem(title: 'Connectés', value: connectedCount.toString(), color: Colors.green, icon: Icons.lan),
              const SizedBox(height: 40, child: VerticalDivider(thickness: 1)),
              _StatItem(title: 'Déconnectés', value: disconnectedCount.toString(), color: Colors.red, icon: Icons.phonelink_off),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: _refreshNodes,
          heroTag: 'refreshNodes',
          tooltip: 'Rafraîchir les nœuds',
          backgroundColor: _accentColor,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApiKeysScreen())),
          heroTag: 'apiKeys',
          tooltip: 'Gérer les clés API',
          backgroundColor: _accentColor,
          child: const Icon(Icons.api, color: Colors.white),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _secondaryTextColor, fontWeight: FontWeight.w500, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _UserNodeCard extends StatelessWidget {
  final String user;
  final List<Node> nodes;

  const _UserNodeCard({required this.user, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(user, style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryTextColor, fontSize: 17)),
        childrenPadding: const EdgeInsets.only(bottom: 8.0),
        children: nodes.map((node) => _buildNodeTile(context, node)).toList(),
      ),
    );
  }

  Widget _buildNodeTile(BuildContext context, Node node) {
    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node))),
      leading: Icon(Icons.circle, color: node.online ? Colors.green : Colors.grey.shade300, size: 12),
      title: Row(
        children: [
          Text(node.name, style: const TextStyle(color: _primaryTextColor, fontWeight: FontWeight.w500)),
          if (node.isExitNode)
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Icon(Icons.exit_to_app, size: 16, color: Colors.orange),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(node.hostname, style: const TextStyle(fontSize: 13, color: _secondaryTextColor)),
          Text(node.ipAddresses.join(', '), style: const TextStyle(fontSize: 13, color: _secondaryTextColor)),
          if (node.sharedRoutes.isNotEmpty)
            Text(
              'Routes: ${node.sharedRoutes.join(', ')}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          Text('Dernière connexion : ${node.lastSeen.toLocal()}', style: const TextStyle(fontSize: 12, color: _secondaryTextColor)),
        ],
      ),
    );
  }
}
