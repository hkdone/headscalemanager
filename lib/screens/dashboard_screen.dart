import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Node>> _nodesFuture;
  String _filterStatus = 'all'; // 'all', 'online', 'offline'

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  Future<void> _refreshNodes() async {
    if (mounted) {
      setState(() {
        _nodesFuture = context.read<AppProvider>().apiService.getNodes();
      });
    }
    // Return a completed future to satisfy RefreshIndicator
    return Future.value();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<Node>>(
          future: _nodesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child:
                      Text('${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refreshNodes,
                child: ListView(
                  children: [
                    Center(
                        child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child:
                          Text(isFr ? 'Aucun nœud trouvé.' : 'No node found.'),
                    ))
                  ],
                ),
              );
            }

            final allNodes = snapshot.data!;
            final connectedNodesCount =
                allNodes.where((node) => node.online).length;
            final disconnectedNodesCount =
                allNodes.length - connectedNodesCount;

            final filteredNodes = allNodes.where((node) {
              if (_filterStatus == 'online') return node.online;
              if (_filterStatus == 'offline') return !node.online;
              return true;
            }).toList();

            final filteredNodesByUser = <String, List<Node>>{};
            for (var node in filteredNodes) {
              (filteredNodesByUser[node.user] ??= []).add(node);
            }
            final users = filteredNodesByUser.keys.toList();

            return RefreshIndicator(
              onRefresh: _refreshNodes,
              child: Column(
                children: [
                  _buildSummarySection(users.length, connectedNodesCount,
                      disconnectedNodesCount, isFr),
                  _buildFilterChips(isFr),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final userNodes = filteredNodesByUser[user]!;
                        return _UserNodeCard(
                          user: user,
                          nodes: userNodes,
                          allNodes: allNodes,
                          refreshNodes: _refreshNodes,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummarySection(
      int userCount, int connectedCount, int disconnectedCount, bool isFr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                  title: isFr ? 'Utilisateurs' : 'Users',
                  value: userCount.toString(),
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  icon: Icons.people),
              SizedBox(
                  height: 40,
                  child: VerticalDivider(
                      thickness: 1, color: Theme.of(context).dividerColor)),
              _StatItem(
                  title: isFr ? 'Connectés' : 'Connected',
                  value: connectedCount.toString(),
                  color: Colors.green,
                  icon: Icons.lan),
              SizedBox(
                  height: 40,
                  child: VerticalDivider(
                      thickness: 1, color: Theme.of(context).dividerColor)),
              _StatItem(
                  title: isFr ? 'Déconnectés' : 'Disconnected',
                  value: disconnectedCount.toString(),
                  color: Colors.red,
                  icon: Icons.phonelink_off),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isFr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilterChip(
            label: Text(isFr ? 'Tous' : 'All'),
            selected: _filterStatus == 'all',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'all');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(isFr ? 'En ligne' : 'Online'),
            selected: _filterStatus == 'online',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'online');
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(isFr ? 'Hors ligne' : 'Offline'),
            selected: _filterStatus == 'offline',
            onSelected: (selected) {
              if (selected) setState(() => _filterStatus = 'offline');
            },
          ),
        ],
      ),
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _UserNodeCard extends StatelessWidget {
  final String user;
  final List<Node> nodes;
  final List<Node> allNodes;
  final VoidCallback refreshNodes;

  const _UserNodeCard(
      {required this.user,
      required this.nodes,
      required this.allNodes,
      required this.refreshNodes});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(user, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.only(bottom: 8.0),
        children: nodes
            .map((node) => _buildNodeTile(context, node, allNodes))
            .toList(),
      ),
    );
  }

  Widget _buildNodeTile(BuildContext context, Node node, List<Node> allNodes) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final trailingIcon = _buildTrailingIcon(context, node, allNodes);

    return ListTile(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node))),
      leading: Icon(Icons.circle,
          color: node.online ? Colors.green : Theme.of(context).disabledColor,
          size: 12),
      title: Row(
        children: [
          Flexible(
              child: Text(node.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis)),
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
          Text(node.hostname, style: Theme.of(context).textTheme.bodySmall),
          Text(node.ipAddresses.join(', '),
              style: Theme.of(context).textTheme.bodySmall),
          if (node.sharedRoutes.isNotEmpty)
            Text(
              '${isFr ? 'Routes' : 'Routes'}: ${node.sharedRoutes.join(', ')}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          Text(
              '${isFr ? 'Dernière connexion' : 'Last seen'}: ${node.lastSeen.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: trailingIcon,
    );
  }

  Widget? _buildTrailingIcon(
      BuildContext context, Node node, List<Node> allNodes) {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    final List<Widget> icons = [];

    // 1. Logique pour les routes en attente (approbation ou conflit)
    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();

    if (pendingRoutes.isNotEmpty) {
      final pendingLanRoutes =
          pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();

      Map<String, Node> conflicts = {};
      List<String> approvableLanRoutes = [];

      for (var route in pendingLanRoutes) {
        final validation = RouteConflictService.validateRouteApproval(
            route, node.id, allNodes);
        if (validation.isConflict) {
          conflicts[route] = validation.conflictingNode!;
        } else {
          approvableLanRoutes.add(route);
        }
      }

      final hasPendingExitNode =
          pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');

      if (conflicts.isNotEmpty) {
        icons.add(
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.red),
            tooltip: isFr
                ? 'Certaines routes sont en conflit'
                : 'Some routes are in conflict',
            onPressed: () => _showConflictInfoDialog(context, node, conflicts),
          ),
        );
      }

      if (approvableLanRoutes.isNotEmpty || hasPendingExitNode) {
        icons.add(
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.amber),
            tooltip: isFr ? 'Approbation requise' : 'Approval required',
            onPressed: () => _showApprovalDialog(context, node, allNodes),
          ),
        );
      }
    }

    // 2. Icône de désynchronisation
    final hasDesync =
        node.sharedRoutes.any((r) => !node.availableRoutes.contains(r));
    if (hasDesync) {
      icons.add(
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.warning, color: Colors.blue),
            tooltip: isFr
                ? 'Nettoyage de la configuration requis'
                : 'Configuration cleanup required',
            onPressed: () => _showCleanupDialog(context, node),
          ),
        ),
      );
    }

    if (icons.isEmpty) {
      return const SizedBox.shrink();
    }
    if (icons.length == 1) {
      return icons.first;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }

  void _showConflictInfoDialog(
      BuildContext context, Node node, Map<String, Node> conflicts) {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';

    String content = isFr
        ? 'Le nœud "${node.name}" ne peut pas partager les réseaux suivants car ils sont déjà utilisés :\n\n'
        : 'Node "${node.name}" cannot share the following networks as they are already in use:\n\n';

    conflicts.forEach((route, conflictingNode) {
      content += isFr
          ? '• Le réseau $route est déjà partagé par "${conflictingNode.name}".\n'
          : '• Network $route is already shared by "${conflictingNode.name}".\n';
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            isFr ? 'Conflit de Routes Détecté' : 'Route Conflict Detected'),
        content: Text(content),
        actions: [
          TextButton(
            child: Text(isFr ? 'Fermer' : 'Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(
      BuildContext context, Node node, List<Node> allNodes) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();
    final isExitNodeRequest =
        pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes =
        pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();

    String title = isFr ? 'Approbation Requise' : 'Approval Required';
    String content = '';

    final approvableLanRoutes = lanRoutes.where((route) {
      final validation =
          RouteConflictService.validateRouteApproval(route, node.id, allNodes);
      return !validation.isConflict;
    }).toList();

    if (approvableLanRoutes.isEmpty && !isExitNodeRequest) {
      // Ce cas ne devrait pas se produire car l'icône d'approbation n'est affichée
      // que si des routes approuvables existent. C'est une sécurité.
      return;
    }

    // Construire le message d'approbation
    if (isExitNodeRequest) {
      content += isFr
          ? 'Le nœud "${node.name}" demande à devenir un Exit Node.'
          : 'Node "${node.name}" is requesting to be an exit node.';
    }

    if (approvableLanRoutes.isNotEmpty) {
      if (content.isNotEmpty) content += '\n\n';
      content += isFr
          ? 'Routes qui seront approuvées :\n• ${approvableLanRoutes.join('\n• ')}\n\n'
          : 'Routes that will be approved:\n• ${approvableLanRoutes.join('\n• ')}\n\n';
    }

    content += isFr
        ? 'Voulez-vous approuver cette (ces) demande(s) ?'
        : 'Do you want to approve this (these) request(s)?';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text(isFr ? 'Non' : 'No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(isFr ? 'Oui' : 'Yes'),
              onPressed: () async {
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context, isFr ? 'Traitement en cours...' : 'Processing...');

                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                try {
                  final routesToApprove = [...approvableLanRoutes];
                  if (isExitNodeRequest) {
                    routesToApprove.addAll(pendingRoutes
                        .where((r) => r == '0.0.0.0/0' || r == '::/0'));
                  }

                  if (aclMode) {
                    // Full logic: Tags + Routes + ACLs
                    final newTags = _addCapabilities(
                      List.from(node.tags),
                      addExitNode: isExitNodeRequest,
                      addLanSharer: approvableLanRoutes.isNotEmpty,
                    );
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService
                        .setNodeRoutes(node.id, routesToApprove);

                    final allUsers = await appProvider.apiService.getUsers();
                    final updatedNodes =
                        await appProvider.apiService.getNodes();
                    final tempRules =
                        await appProvider.storageService.getTemporaryRules();
                    final aclGenerator = NewAclGeneratorService();
                    final newPolicyMap = aclGenerator.generatePolicy(
                        users: allUsers,
                        nodes: updatedNodes,
                        temporaryRules: tempRules);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Nœud approuvé et ACLs mises à jour !'
                            : 'Node approved and ACLs updated!');
                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService
                        .setNodeRoutes(node.id, routesToApprove);
                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Routes approuvées (ACLs non gérées).'
                            : 'Routes approved (ACLs not managed).');
                  }
                } catch (e) {
                  showSafeSnackBar(
                      context,
                      isFr
                          ? 'Échec de lapprrobation: $e'
                          : 'Approval failed: $e');
                } finally {
                  refreshNodes();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showCleanupDialog(BuildContext context, Node node) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    final routesToClean = node.sharedRoutes
        .where((r) => !node.availableRoutes.contains(r))
        .toList();
    final hadExitNode =
        routesToClean.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes =
        routesToClean.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
    final hadLanSharing = lanRoutes.isNotEmpty;

    String title = isFr ? 'Nettoyage Requis' : 'Cleanup Required';
    String content = isFr
        ? 'La configuration du nœud "${node.name}" est désynchronisée.\n\n'
        : 'Node "${node.name}" configuration is out of sync.\n\n';

    if (hadExitNode) {
      content += isFr
          ? 'Le client a désactivé sa fonction de Nœud de Sortie.\n'
          : 'The client has disabled its Exit Node function.\n';
    }
    if (hadLanSharing) {
      content += isFr
          ? 'Le client a arrêté de partager le(s) sous-réseau(x) : ${lanRoutes.join(', ')}.\n'
          : 'The client has stopped sharing the subnet(s): ${lanRoutes.join(', ')}.\n';
    }
    content += isFr
        ? '\nVoulez-vous nettoyer la configuration ?'
        : '\nDo you want to clean up the configuration?';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text(isFr ? 'Non' : 'No'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(isFr ? 'Oui, Nettoyer' : 'Yes, Clean Up'),
              onPressed: () async {
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context, isFr ? 'Nettoyage en cours...' : 'Cleaning up...');

                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                try {
                  final remainingRoutes = node.sharedRoutes
                      .where((r) => node.availableRoutes.contains(r))
                      .toList();

                  if (aclMode) {
                    // Full logic: Tags + Routes + ACLs
                    final newTags = _removeCapabilities(
                      List.from(node.tags),
                      removeExitNode: hadExitNode,
                      removeLanSharer: hadLanSharing,
                    );
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService
                        .setNodeRoutes(node.id, remainingRoutes);

                    final allUsers = await appProvider.apiService.getUsers();
                    final updatedNodes =
                        await appProvider.apiService.getNodes();
                    final tempRules =
                        await appProvider.storageService.getTemporaryRules();
                    final aclGenerator = NewAclGeneratorService();
                    final newPolicyMap = aclGenerator.generatePolicy(
                        users: allUsers,
                        nodes: updatedNodes,
                        temporaryRules: tempRules);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Configuration nettoyée et ACLs mises à jour !'
                            : 'Configuration cleaned up and ACLs updated!');
                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService
                        .setNodeRoutes(node.id, remainingRoutes);
                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Configuration des routes nettoyée (ACLs non gérées).'
                            : 'Route configuration cleaned up (ACLs not managed).');
                  }
                } catch (e) {
                  showSafeSnackBar(context,
                      isFr ? 'Échec du nettoyage: $e' : 'Cleanup failed: $e');
                } finally {
                  refreshNodes();
                }
              },
            ),
          ],
        );
      },
    );
  }

  List<String> _addCapabilities(List<String> tags,
      {bool addExitNode = false, bool addLanSharer = false}) {
    List<String> newTags = List.from(tags);
    int clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex != -1) {
      final oldClientTag = newTags[clientTagIndex];
      final parts = oldClientTag
          .replaceFirst('tag:', '')
          .split(';')
          .where((p) => p.isNotEmpty)
          .toSet();

      if (addExitNode) parts.add('exit-node');
      if (addLanSharer) parts.add('lan-sharer');

      final clientPart =
          parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
      if (clientPart.isEmpty) return newTags; // Should not happen

      final otherParts = parts.where((p) => p != clientPart).toList()..sort();

      final newClientTagBuilder = StringBuffer('tag:$clientPart');
      if (otherParts.isNotEmpty) {
        newClientTagBuilder.write(';${otherParts.join(';')}');
      }
      newTags[clientTagIndex] = newClientTagBuilder.toString();

      // Remove standalone tags if they exist, as they are now consolidated
      if (addExitNode) newTags.removeWhere((t) => t == 'tag:exit-node');
      if (addLanSharer) newTags.removeWhere((t) => t == 'tag:lan-sharer');
    } else {
      if (addExitNode && !newTags.contains('tag:exit-node')) {
        newTags.add('tag:exit-node');
      }
      if (addLanSharer && !newTags.contains('tag:lan-sharer')) {
        newTags.add('tag:lan-sharer');
      }
    }
    return newTags;
  }

  List<String> _removeCapabilities(List<String> tags,
      {bool removeExitNode = false, bool removeLanSharer = false}) {
    List<String> newTags = List.from(tags);
    int clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex != -1) {
      final oldClientTag = newTags[clientTagIndex];
      final parts = oldClientTag
          .replaceFirst('tag:', '')
          .split(';')
          .where((p) => p.isNotEmpty)
          .toSet();

      if (removeExitNode) parts.remove('exit-node');
      if (removeLanSharer) parts.remove('lan-sharer');

      final clientPart =
          parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
      if (clientPart.isEmpty) return newTags;

      final otherParts = parts.where((p) => p != clientPart).toList()..sort();

      final newClientTagBuilder = StringBuffer('tag:$clientPart');
      if (otherParts.isNotEmpty) {
        newClientTagBuilder.write(';${otherParts.join(';')}');
      }
      newTags[clientTagIndex] = newClientTagBuilder.toString();
    } else {
      if (removeExitNode) newTags.remove('tag:exit-node');
      if (removeLanSharer) newTags.remove('tag:lan-sharer');
    }
    return newTags;
  }
}
