import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

/// Écran du tableau de bord affichant un aperçu des nœuds Headscale.
///
/// Les nœuds sont regroupés par utilisateur et peuvent être développés
/// pour afficher des détails supplémentaires.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Future qui contiendra la liste des nœuds récupérés depuis l'API.
  late Future<List<Node>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  /// Rafraîchit la liste des nœuds en effectuant un nouvel appel API.
  void _refreshNodes() {
    setState(() {
      _nodesFuture = context.read<AppProvider>().apiService.getNodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Node>>(
        future: _nodesFuture,
        builder: (context, snapshot) {
          // Affiche un indicateur de chargement pendant la récupération des nœuds.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Affiche un message d'erreur si la récupération des nœuds échoue.
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          // Affiche un message si aucun nœud n'est trouvé.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun nœud trouvé.'));
          }

          final nodes = snapshot.data!;
          // Regroupe les nœuds par utilisateur.
          final nodesByUser = <String, List<Node>>{};
          for (var node in nodes) {
            if (nodesByUser.containsKey(node.user)) {
              nodesByUser[node.user]!.add(node);
            } else {
              nodesByUser[node.user] = [node];
            }
          }

          final users = nodesByUser.keys.toList();
          final connectedNodes = nodes.where((node) => node.online).length;
          final disconnectedNodes = nodes.length - connectedNodes;

          // Construit une liste déroulante de cartes, une par utilisateur.
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _InfoCard(
                          title: 'Utilisateurs',
                          value: users.length.toString(),
                          color: Colors.grey,
                          icon: Icons.people,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          title: 'Connectés',
                          value: connectedNodes.toString(),
                          color: Colors.green,
                          icon: Icons.lan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InfoCard(
                          title: 'Déconnectés',
                          value: disconnectedNodes.toString(),
                          color: Colors.red,
                          icon: Icons.phonelink_off,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userNodes = nodesByUser[user]!;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        // Titre de la tuile d'expansion (nom de l'utilisateur).
                        title: Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // Contenu de la tuile d'expansion (liste des nœuds de l'utilisateur).
                        children: userNodes.map((node) {
                          return ListTile(
                            // Navigue vers l'écran de détails du nœud au tap.
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node)));
                            },
                            // Icône indiquant le statut en ligne/hors ligne du nœud.
                            leading: Icon(
                              Icons.circle,
                              color: node.online ? Colors.green : Colors.grey,
                            ),
                            // Nom du nœud et nom d'hôte.
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(node.name),
                                    if (node.isExitNode)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4.0),
                                        child: Icon(Icons.exit_to_app, size: 16, color: Colors.orange),
                                      ),
                                  ],
                                ),
                                Text(node.hostname, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            // Adresses IP, routes partagées et dernière connexion.
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(node.ipAddresses.join(', ')),
                                if (node.sharedRoutes.isNotEmpty)
                                  Text(
                                    'Routes partagées : ${node.sharedRoutes.join(', ')}',
                                    style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                  ),
                                Text('Dernière connexion : ${node.lastSeen.toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      // Bouton flottant pour rafraîchir la liste des nœuds.
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshNodes,
        heroTag: 'refreshNodes',
        tooltip: 'Rafraîchir les nœuds',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
