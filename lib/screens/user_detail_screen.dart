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
        title: Text(widget.user.name, style: theme.appBarTheme.titleTextStyle),
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
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${widget.user.id}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
              '${isFr ? 'Créé le' : 'Created on'}: ${widget.user.createdAt?.toLocal() ?? 'N/A'}',
              style: theme.textTheme.bodySmall),
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

  void _showEditTagsFlow(BuildContext context) async {
    final String? generatedCommand = await showDialog<String>(
      context: context,
      builder: (dialogContext) => EditTagsDialog(
        node: node,
      ),
    );

    if (generatedCommand != null &&
        generatedCommand.isNotEmpty &&
        context.mounted) {
      final locale = context.read<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      showDialog(
        context: context,
        builder: (dialogContext) =>
            CliCommandDisplayDialog(command: generatedCommand),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFr
                  ? 'Commande CLI générée. Exécutez-la et actualisez la page pour voir les changements.'
                  : 'CLI command generated. Run it and refresh the page to see the changes.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white)),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showExitNodeWarningAndProceed(BuildContext context) async {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
              isFr
                  ? 'Avertissement sur les Nœuds de Sortie'
                  : 'Exit Node Warning',
              style: theme.textTheme.titleLarge),
          content: Text(
              isFr
                  ? 'Dans la configuration ACL actuelle, si plusieurs nœuds de sortie appartiennent à différents utilisateurs, ils ne peuvent pas être rendus exclusifs. Tout utilisateur autorisé pourra voir et utiliser tous les nœuds de sortie disponibles sur le réseau.'
                  : 'In the current ACL configuration, if multiple exit nodes belong to different users, they cannot be made exclusive. Any authorized user will be able to see and use all available exit nodes on the network.',
              style: theme.textTheme.bodyMedium),
          actions: <Widget>[
            TextButton(
              child: Text(isFr ? 'Annuler' : 'Cancel',
                  style: theme.textTheme.labelLarge),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: Text(isFr ? 'Continuer' : 'Continue',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
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
    final theme = Theme.of(context);
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final onlineColor = node.online ? Colors.green : Colors.grey.shade400;
    final isExitNode = node.isExitNode;
    final hasSharedRoutes = node.sharedRoutes.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: isExitNode ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
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
            Text(node.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(node.ipAddresses.join('\n'), style: theme.textTheme.bodySmall),
            const Spacer(),
            if (isExitNode)
              Row(
                children: [
                  Icon(Icons.exit_to_app,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('Exit Node',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            if (hasSharedRoutes)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.router_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        node.sharedRoutes.join(", "),
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(isFr ? 'Dernière connexion:' : 'Last seen:',
                style: theme.textTheme.bodySmall),
            Text(node.lastSeen.toLocal().toString(),
                style: theme.textTheme.bodySmall),
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
      icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
      onSelected: (String value) {
        switch (value) {
          case 'rename':
            showDialog(
                context: context,
                builder: (dialogContext) => RenameNodeDialog(
                    node: node, onNodeRenamed: onNodeUpdate));
            break;
          case 'move':
            showDialog(
                context: context,
                builder: (dialogContext) =>
                    MoveNodeDialog(node: node, onNodeMoved: onNodeUpdate));
            break;
          case 'edit_tags':
            _showEditTagsFlow(context);
            break;
          case 'enable_exit_node':
            _showExitNodeWarningAndProceed(context);
            break;
          case 'disable_exit_node':
            _runAction(
                context,
                () => provider.apiService.setNodeRoutes(node.id, []),
                isFr
                    ? 'Nœud de sortie désactivé.'
                    : 'Exit node disabled.');
            break;
          case 'share_subnet':
            showDialog(
                context: context,
                builder: (dialogContext) => ShareSubnetDialog(
                    node: node, onSubnetShared: onNodeUpdate));
            break;
          case 'disable_subnet':
            _runAction(
                context,
                () => provider.apiService.setNodeRoutes(node.id, []),
                isFr
                    ? 'Routes de sous-réseau désactivées.'
                    : 'Subnet routes disabled.');
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
                style: theme.textTheme.bodyMedium)),
        PopupMenuItem<String>(
            value: 'move',
            child: Text(isFr ? 'Changer d\'utilisateur' : 'Change user',
                style: theme.textTheme.bodyMedium)),
        PopupMenuItem<String>(
            value: 'edit_tags',
            child: Text(isFr ? 'Modifier les tags' : 'Edit tags',
                style: theme.textTheme.bodyMedium)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
            value: 'enable_exit_node',
            child: Text(isFr ? 'Activer nœud de sortie' : 'Enable exit node',
                style: theme.textTheme.bodyMedium)),
        PopupMenuItem<String>(
            value: 'disable_exit_node',
            child:
                Text(isFr ? 'Désactiver nœud de sortie' : 'Disable exit node', style: theme.textTheme.bodyMedium)),
        PopupMenuItem<String>(
            value: 'share_subnet',
            child: Text(isFr ? 'Partager sous-réseau' : 'Share subnet',
                style: theme.textTheme.bodyMedium)),
        PopupMenuItem<String>(
            value: 'disable_subnet',
            child: Text(isFr ? 'Désactiver sous-réseau' : 'Disable subnet',
                style: theme.textTheme.bodyMedium)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
            value: 'delete_device',
            child: Text(isFr ? 'Supprimer' : 'Delete',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red))),
      ],
    );
  }
}
