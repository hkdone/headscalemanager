import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/widgets/edit_tags_dialog.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/registration_dialogs.dart';
// For debugPrint

// Dialogs for node actions
import 'package:headscalemanager/widgets/rename_node_dialog.dart';
import 'package:headscalemanager/widgets/move_node_dialog.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';

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
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(context),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Text(isFr ? 'Appareils' : 'Devices',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _buildNodesGrid(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTailscaleUpCommandDialog(context, widget.user),
        label: Text(isFr ? 'Nouvel Appareil' : 'New Device',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        icon: Icon(Icons.add_to_queue_sharp,
            color: theme.colorScheme.onPrimary),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${widget.user.id}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 8),
          Text(
              '${isFr ? 'Créé le' : 'Created on'}: ${widget.user.createdAt?.toLocal() ?? 'N/A'}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildNodesGrid(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return ValueListenableBuilder<Future<List<Node>>>(
      valueListenable: _nodesFutureNotifier,
      builder: (context, nodesFuture, child) {
        return FutureBuilder<List<Node>>(
          future: nodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary));
            }
            if (snapshot.hasError) {
              debugPrint(
                  'Erreur lors du chargement des nœuds : ${snapshot.error}');
              return Center(
                  child: Text(
                      '${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}',
                      style: theme.textTheme.bodyMedium));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Text(isFr ? 'Aucun appareil trouvé.' : 'No devices found.',
                      style: theme.textTheme.bodyMedium));
            }

            final userNodes = snapshot.data!
                .where((node) => node.user == widget.user.name)
                .toList();

            if (userNodes.isEmpty) {
              return Center(
                  child: Text(
                      isFr
                          ? 'Aucun appareil trouvé pour cet utilisateur.'
                          : 'No devices found for this user.',
                      style: theme.textTheme.bodyMedium));
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

  Future<void> _runAction(BuildContext context, Future<void> Function() action,
      String successMessage) async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    try {
      await action();
      showSafeSnackBar(context, successMessage);
      onNodeUpdate();
    } catch (e) {
      debugPrint('Action échouée : $e');
      showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
    }
  }

  void _showEditTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => EditTagsDialog(
        node: node,
        onTagsUpdated: onNodeUpdate, // Passer la fonction de rafraîchissement
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final onlineColor = node.online ? Colors.green : theme.colorScheme.onPrimary.withOpacity(0.5);
    final isExitNode = node.isExitNode;
    final hasSharedRoutes = node.sharedRoutes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12.0),
        border: isExitNode ? Border.all(color: theme.colorScheme.onPrimary, width: 2) : null,
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
            Text(node.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(node.ipAddresses.join('\n'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
            const Spacer(),
            if (isExitNode)
              Row(
                children: [
                  Icon(Icons.exit_to_app,
                      size: 14, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 4),
                  Text('Exit Node',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            if (hasSharedRoutes)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.router_outlined, size: 14, color: theme.colorScheme.onPrimary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        node.sharedRoutes.join(", "),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(isFr ? 'Dernière connexion:' : 'Last seen:',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
            Text(node.lastSeen.toLocal().toString(),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, AppProvider provider) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
      onSelected: (String value) async {
        switch (value) {
          case 'rename':
            showDialog(
                context: context,
                builder: (dialogContext) => RenameNodeDialog(
                    node: node, onNodeRenamed: onNodeUpdate));
            break;
          case 'move':
            final moved = await showDialog<bool>(
                context: context,
                builder: (dialogContext) =>
                    MoveNodeDialog(node: node, onNodeMoved: onNodeUpdate));
            if (moved == true && context.mounted) {
              showSafeSnackBar(
                context,
                isFr
                    ? 'Appareil déplacé. Redémarrage de Headscale recommandé.'
                    : 'Device moved. Headscale restart recommended.',
              );
            }
            break;
          case 'edit_tags':
            _showEditTagsDialog(context);
            break;
          case 'delete_device':
            showDialog(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                    isFr ? 'Supprimer l\'appareil ?' : 'Delete device?',
                    style: theme.textTheme.titleLarge),
                content: Text(
                    isFr
                        ? 'Êtes-vous sûr de vouloir supprimer ${node.name} ?'
                        : 'Are you sure you want to delete ${node.name}?',
                    style: theme.textTheme.bodyMedium),
                actions: <Widget>[
                  TextButton(
                      child: Text(isFr ? 'Annuler' : 'Cancel',
                          style: theme.textTheme.labelLarge),
                      onPressed: () => Navigator.of(dialogContext).pop()),
                  TextButton(
                    child: Text(isFr ? 'Confirmer' : 'Confirm',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: Colors.red)),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _runAction(
                          context,
                          () => provider.apiService.deleteNode(node.id),
                          isFr ? 'Appareil supprimé.' : 'Device deleted.');
                    },
                  ),
                ],
              ),
            );
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
            value: 'rename',
            child: Text(isFr ? 'Renommer' : 'Rename',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface))),
        PopupMenuItem<String>(
            value: 'move',
            child: Text(isFr ? 'Changer d\'utilisateur' : 'Change user',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface))),
        PopupMenuItem<String>(
            value: 'edit_tags',
            child: Text(isFr ? 'Modifier les tags' : 'Edit tags',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface))),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
            value: 'delete_device',
            child: Text(isFr ? 'Supprimer' : 'Delete',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red))),
      ],
    );
  }
}
