import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/node_management_tile.dart';
import 'package:headscalemanager/widgets/registration_dialogs.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Écran affichant les détails d'un utilisateur spécifique et ses nœuds associés.
///
/// Permet de visualiser les informations de l'utilisateur et de gérer les appareils
/// (nœuds) qui lui sont liés.
class UserDetailScreen extends StatefulWidget {
  /// L'utilisateur dont les détails doivent être affichés.
  final User user;

  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  /// Notifier de valeur pour le Future qui contiendra la liste des nœuds.
  /// Utilisé pour rafraîchir la liste des nœuds de manière réactive.
  late ValueNotifier<Future<List<Node>>> _nodesFutureNotifier;

  @override
  void initState() {
    super.initState();
    // Initialise le Future pour récupérer tous les nœuds.
    _nodesFutureNotifier = ValueNotifier(context.read<AppProvider>().apiService.getNodes());
  }

  /// Rafraîchit la liste des nœuds en effectuant un nouvel appel API.
  void _refreshNodes() {
    _nodesFutureNotifier.value = context.read<AppProvider>().apiService.getNodes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.name), // Affiche le nom de l'utilisateur dans la barre d'application.
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affiche l'ID de l'utilisateur.
            Text('ID : ${widget.user.id}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Affiche la date de création de l'utilisateur.
            Text('Créé le : ${widget.user.createdAt?.toLocal() ?? 'N/A'}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            // Bouton pour enregistrer un nouvel appareil sous cet utilisateur.
            Center(
              child: ElevatedButton.icon(
                onPressed: () => showTailscaleUpCommandDialog(context, widget.user),
                icon: const Icon(Icons.add_to_queue_sharp),
                label: const Text('Enregistrer un nouvel appareil'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(), // Séparateur visuel.
            // Titre de la section des appareils.
            Text('Appareils', style: Theme.of(context).textTheme.headlineSmall),
            // Liste extensible des nœuds associés à l'utilisateur.
            Expanded(
              child: ValueListenableBuilder<Future<List<Node>>>(
                valueListenable: _nodesFutureNotifier,
                builder: (context, nodesFuture, child) {
                  return FutureBuilder<List<Node>>(
                    future: nodesFuture,
                    builder: (context, snapshot) {
                      // Affiche un indicateur de chargement pendant la récupération des nœuds.
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // Affiche un message d'erreur si la récupération des nœuds échoue.
                      if (snapshot.hasError) {
                        debugPrint('Erreur lors du chargement des nœuds : ${snapshot.error}');
                        return Center(child: Text('Erreur : ${snapshot.error}'));
                      }
                      // Affiche un message si aucun appareil n'est trouvé pour cet utilisateur.
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('Aucun appareil trouvé pour cet utilisateur.'));
                      }

                      // Filtre les nœuds pour n'afficher que ceux appartenant à l'utilisateur actuel.
                      final userNodes = snapshot.data!.where((node) => node.user == widget.user.name).toList();

                      // Affiche un message si, après filtrage, aucun appareil n'est trouvé.
                      if (userNodes.isEmpty) {
                        return const Center(child: Text('Aucun appareil trouvé pour cet utilisateur.'));
                      }

                      // Construit une liste des nœuds de l'utilisateur.
                      return ListView.builder(
                        itemCount: userNodes.length,
                        itemBuilder: (context, index) {
                          final node = userNodes[index];
                          // Utilise NodeManagementTile pour chaque nœud, permettant des actions de gestion.
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