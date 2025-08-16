import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

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
    _nodesFuture = context.read<AppProvider>().apiService.getNodes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Node>>(
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
          if (nodesByUser.containsKey(node.user)) {
            nodesByUser[node.user]!.add(node);
          } else {
            nodesByUser[node.user] = [node];
          }
        }

        final users = nodesByUser.keys.toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userNodes = nodesByUser[user]!;

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ExpansionTile(
                title: Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
                children: userNodes.map((node) {
                  return ListTile(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node)));
                    },
                    leading: Icon(
                      Icons.circle,
                      color: node.online ? Colors.green : Colors.grey,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.name),
                        Text(node.hostname, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    subtitle: Column( // Utiliser une colonne pour empiler plusieurs lignes
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(node.ipAddresses.join(', ')),
                        if (node.advertisedRoutes.isNotEmpty)
                          Text(
                            'Routes : ${node.advertisedRoutes.join(', ')}',
                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey), // Police plus petite pour les routes
                          ),
                        Text('Dernière connexion : ${node.lastSeen.toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }
}