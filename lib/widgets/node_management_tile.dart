import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';
// For debugPrint

// Import the new extracted dialogs
import 'package:headscalemanager/widgets/rename_node_dialog.dart';
import 'package:headscalemanager/widgets/move_node_dialog.dart';
import 'package:headscalemanager/widgets/exit_node_command_dialog.dart';
import 'package:headscalemanager/widgets/share_subnet_dialog.dart';

/// Un widget réutilisable pour afficher un nœud et fournir des actions de gestion.
///
/// Cette tuile affiche les informations clés d'un nœud et permet d'effectuer
/// diverses opérations (renommer, déplacer, activer/désactiver nœud de sortie,
/// partager/désactiver sous-réseau, supprimer) via un menu contextuel.
class NodeManagementTile extends StatelessWidget {
  /// Le nœud à gérer.
  final Node node;

  /// Fonction de rappel appelée après une mise à jour du nœud (ex: renommage, déplacement).
  final VoidCallback onNodeUpdate;

  const NodeManagementTile({super.key, required this.node, required this.onNodeUpdate});

  /// Exécute une action asynchrone et affiche un SnackBar de succès ou d'erreur.
  ///
  /// [context] : Le contexte de construction du widget.
  /// [action] : La fonction asynchrone à exécuter.
  /// [successMessage] : Le message à afficher en cas de succès.
  Future<void> _runAction(BuildContext context, Future<void> Function() action,
      String successMessage) async {
    try {
      await action();
      showSafeSnackBar(context, successMessage);
      onNodeUpdate(); // Rafraîchit la liste des nœuds après l'action.
    } catch (e) {
      debugPrint('Action échouée : $e');
      showSafeSnackBar(context, 'Erreur : $e');
    }
  }

  /// Getter pour vérifier si le nœud est un nœud de sortie.
  bool get _isExitNode => node.isExitNode;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        // Navigue vers l'écran de détails du nœud au tap.
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node)));
        },
        // Icône indiquant le statut en ligne/hors ligne du nœud.
        leading: Icon(
            Icons.circle, color: node.online ? Colors.green : Colors.grey,
            size: 18),
        title: Row(
          children: [
            Text(node.name),
            // Affiche une icône si le nœud est un nœud de sortie.
            if (_isExitNode)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.exit_to_app, size: 18, color: Colors.blueGrey),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.ipAddresses.join(', ')),
            Text('Dernière connexion : ${node.lastSeen.toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        // Menu contextuel pour les actions de gestion du nœud.
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) {
            switch (value) {
              case 'rename':
                // Affiche le dialogue pour renommer le nœud.
                showDialog(
                  context: context,
                  builder: (ctx) => RenameNodeDialog(node: node, onNodeRenamed: onNodeUpdate),
                );
                break;
              case 'move':
                // Affiche le dialogue pour déplacer le nœud.
                showDialog(
                  context: context,
                  builder: (ctx) => MoveNodeDialog(node: node, onNodeMoved: onNodeUpdate),
                );
                break;
              case 'enable_exit_node':
                // Affiche le dialogue pour activer le nœud de sortie.
                showDialog(
                  context: context,
                  builder: (ctx) => ExitNodeCommandDialog(node: node, onExitNodeEnabled: onNodeUpdate),
                );
                break;
              case 'disable_exit_node':
                // Désactive le nœud de sortie via l'API.
                _runAction(context,
                        () => provider.apiService.setNodeRoutes(node.id, []),
                    'Nœud de sortie désactivé.'
                );
                break;
              case 'share_subnet':
                // Affiche le dialogue pour partager un sous-réseau.
                showDialog(
                  context: context,
                  builder: (ctx) => ShareSubnetDialog(node: node, onSubnetShared: onNodeUpdate),
                );
                break;
              case 'disable_subnet':
                // Désactive les routes de sous-réseau via l'API.
                _runAction(
                  context,
                  () => provider.apiService.setNodeRoutes(node.id, []),
                  'Routes de sous-réseau désactivées.'
                );
                break;
              case 'delete_device':
                // Affiche le dialogue de confirmation de suppression.
                showDialog(
                  context: context,
                  builder: (dialogCtx) =>
                      AlertDialog(
                        title: const Text('Supprimer l\'appareil ?'),
                        content: Text(
                            'Êtes-vous sûr de vouloir supprimer ${node.name} ?'),
                        actions: <Widget>[
                          TextButton(child: const Text('Annuler'),
                              onPressed: () => Navigator.of(dialogCtx).pop()),
                          TextButton(
                            child: const Text(
                                'Confirmer', style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _runAction(context,
                                      () =>
                                      provider.apiService.deleteNode(node.id),
                                  'Appareil supprimé.'
                              );
                            },
                          ),
                        ],
                      ),
                );
                break;
            }
          },
          itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Renommer l\'appareil'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.move_up),
                title: Text('Déplacer l\'appareil'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'enable_exit_node',
              child: ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text('Activer le nœud de sortie'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'disable_exit_node',
              child: ListTile(
                leading: Icon(Icons.remove_circle_outline),
                title: Text('Désactiver le nœud de sortie'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'share_subnet',
              child: ListTile(
                leading: Icon(Icons.router_outlined),
                title: Text('Partager le sous-réseau local'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'disable_subnet',
              child: ListTile(
                leading: Icon(Icons.router_outlined), // Réutilisation de l'icône pour l'instant
                title: Text('Désactiver les routes de sous-réseau'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'delete_device',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Supprimer l\'appareil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
