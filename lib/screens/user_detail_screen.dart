import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
// Importation pour le presse-papiers
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/node_management_tile.dart';
import 'package:headscalemanager/widgets/registration_dialogs.dart';

class UserDetailScreen extends StatefulWidget {
  final User user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late ValueNotifier<Future<List<Node>>> _nodesFutureNotifier;

  @override
  void initState() {
    super.initState();
    _nodesFutureNotifier = ValueNotifier(context.read<AppProvider>().apiService.getNodes());
  }

  void _refreshNodes() {
    _nodesFutureNotifier.value = context.read<AppProvider>().apiService.getNodes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID : ${widget.user.id}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Créé le : ${widget.user.createdAt.toLocal()}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => showTailscaleUpCommandDialog(context, widget.user), // Appel mis à jour
                icon: const Icon(Icons.add_to_queue_sharp),
                label: const Text('Enregistrer un nouvel appareil'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            Text('Appareils', style: Theme.of(context).textTheme.headlineSmall),
            Expanded(
              child: ValueListenableBuilder<Future<List<Node>>>(
                valueListenable: _nodesFutureNotifier,
                builder: (context, nodesFuture, child) {
                  return FutureBuilder<List<Node>>(
                    future: nodesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        print('Erreur lors du chargement des nœuds : ${snapshot.error}');
                        return Center(child: Text('Erreur : ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('Aucun appareil trouvé pour cet utilisateur.'));
                      }

                      final userNodes = snapshot.data!.where((node) => node.user == widget.user.name).toList();

                      if (userNodes.isEmpty) {
                        return const Center(child: Text('Aucun appareil trouvé pour cet utilisateur.'));
                      }

                      return ListView.builder(
                        itemCount: userNodes.length,
                        itemBuilder: (context, index) {
                          final node = userNodes[index];
                          return NodeManagementTile(node: node, onNodeUpdate: _refreshNodes);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
