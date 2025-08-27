import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/widgets/cli_command_display_dialog.dart';
import 'package:headscalemanager/widgets/edit_tags_dialog.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/registration_dialogs.dart';
// For debugPrint

// Dialogs for node actions
import 'package:headscalemanager/widgets/rename_node_dialog.dart';
import 'package:headscalemanager/widgets/move_node_dialog.dart';
import 'package:headscalemanager/widgets/exit_node_command_dialog.dart';
import 'package:headscalemanager/widgets/share_subnet_dialog.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;

/// Écran affichant les détails d'un utilisateur spécifique et ses nœuds associés.
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(widget.user.name, style: const TextStyle(color: _primaryTextColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Text('Appareils', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor)),
            ),
            Expanded(child: _buildNodesGrid()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTailscaleUpCommandDialog(context, widget.user),
        label: const Text('Nouvel Appareil'),
        icon: const Icon(Icons.add_to_queue_sharp),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${widget.user.id}', style: const TextStyle(color: _secondaryTextColor, fontSize: 14)),
          const SizedBox(height: 8),
          Text('Créé le: ${widget.user.createdAt?.toLocal() ?? 'N/A'}', style: const TextStyle(color: _secondaryTextColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNodesGrid() {
    return ValueListenableBuilder<Future<List<Node>>>(
      valueListenable: _nodesFutureNotifier,
      builder: (context, nodesFuture, child) {
        return FutureBuilder<List<Node>>(
          future: nodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              debugPrint('Erreur lors du chargement des nœuds : ${snapshot.error}');
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucun appareil trouvé.'));
            }

            final userNodes = snapshot.data!.where((node) => node.user == widget.user.name).toList();

            if (userNodes.isEmpty) {
              return const Center(child: Text('Aucun appareil trouvé pour cet utilisateur.'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: userNodes.length,
              itemBuilder: (context, index) {
                final node = userNodes[index];
                return _NodeCard(node: node, onNodeUpdate: _refreshNodes);
              },
            );
          },
        );
      },
    );
  }
}

class _NodeCard extends StatelessWidget {
  final Node node;
  final VoidCallback onNodeUpdate;

  const _NodeCard({required this.node, required this.onNodeUpdate});

  Future<void> _runAction(BuildContext context, Future<void> Function() action, String successMessage) async {
    try {
      await action();
      showSafeSnackBar(context, successMessage);
      onNodeUpdate();
    } catch (e) {
      debugPrint('Action échouée : $e');
      showSafeSnackBar(context, 'Erreur : $e');
    }
  }

  void _showEditTagsFlow(BuildContext context) async {
    final String? generatedCommand = await showDialog<String>(
      context: context,
      builder: (dialogContext) => EditTagsDialog(
        node: node,
      ),
    );

    if (generatedCommand != null && generatedCommand.isNotEmpty && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) => CliCommandDisplayDialog(command: generatedCommand),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Commande CLI générée. Exécutez-la et actualisez la page pour voir les changements.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showExitNodeWarningAndProceed(BuildContext context) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Avertissement sur les Nœuds de Sortie'),
          content: const Text(
              'Dans la configuration ACL actuelle, si plusieurs nœuds de sortie appartiennent à différents utilisateurs, ils ne peuvent pas être rendus exclusifs. Tout utilisateur autorisé pourra voir et utiliser tous les nœuds de sortie disponibles sur le réseau.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Continuer', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        builder: (dialogContext) =>
            ExitNodeCommandDialog(node: node, onExitNodeEnabled: onNodeUpdate),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final onlineColor = node.online ? Colors.green : Colors.grey.shade400;
    final isExitNode = node.isExitNode;
    final hasSharedRoutes = node.sharedRoutes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: isExitNode ? Border.all(color: Colors.blueAccent, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(Icons.circle, color: onlineColor, size: 12),
                _buildPopupMenu(context, provider),
              ],
            ),
            const Spacer(),
            Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryTextColor), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(node.ipAddresses.join('\n'), style: const TextStyle(fontSize: 12, color: _secondaryTextColor)),
            const Spacer(),
            if (isExitNode)
              const Row(
                children: [
                  Icon(Icons.exit_to_app, size: 14, color: Colors.blueAccent),
                  SizedBox(width: 4),
                  Text('Exit Node', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            if (hasSharedRoutes)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.router_outlined, size: 14, color: _secondaryTextColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        node.sharedRoutes.join(", "),
                        style: const TextStyle(fontSize: 12, color: _secondaryTextColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            const Text('Dernière connexion:', style: TextStyle(fontSize: 10, color: _secondaryTextColor)),
            Text(node.lastSeen.toLocal().toString(), style: const TextStyle(fontSize: 10, color: _secondaryTextColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, AppProvider provider) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
      onSelected: (String value) {
        switch (value) {
          case 'rename':
            showDialog(context: context, builder: (dialogContext) => RenameNodeDialog(node: node, onNodeRenamed: onNodeUpdate));
            break;
          case 'move':
            showDialog(context: context, builder: (dialogContext) => MoveNodeDialog(node: node, onNodeMoved: onNodeUpdate));
            break;
          case 'edit_tags':
            _showEditTagsFlow(context);
            break;
          case 'enable_exit_node':
            _showExitNodeWarningAndProceed(context);
            break;
          case 'disable_exit_node':
            _runAction(context, () => provider.apiService.setNodeRoutes(node.id, []), 'Nœud de sortie désactivé.');
            break;
          case 'share_subnet':
            showDialog(context: context, builder: (dialogContext) => ShareSubnetDialog(node: node, onSubnetShared: onNodeUpdate));
            break;
          case 'disable_subnet':
            _runAction(context, () => provider.apiService.setNodeRoutes(node.id, []), 'Routes de sous-réseau désactivées.');
            break;
          case 'delete_device':
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Supprimer l\'appareil ?'),
                content: Text('Êtes-vous sûr de vouloir supprimer ${node.name} ?'),
                actions: <Widget>[
                  TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop()),
                  TextButton(
                    child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _runAction(context, () => provider.apiService.deleteNode(node.id), 'Appareil supprimé.');
                    },
                  ),
                ],
              ),
            );
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'rename', child: Text('Renommer')),
        const PopupMenuItem<String>(value: 'move', child: Text('Changer d\'utilisateur')),
        const PopupMenuItem<String>(value: 'edit_tags', child: Text('Modifier les tags')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'enable_exit_node', child: Text('Activer nœud de sortie')),
        const PopupMenuItem<String>(value: 'disable_exit_node', child: Text('Désactiver nœud de sortie')),
        const PopupMenuItem<String>(value: 'share_subnet', child: Text('Partager sous-réseau')),
        const PopupMenuItem<String>(value: 'disable_subnet', child: Text('Désactiver sous-réseau')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'delete_device', child: Text('Supprimer', style: TextStyle(color: Colors.red))),
      ],
    );
  }
}