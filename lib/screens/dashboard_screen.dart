import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/failover_event.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/services/ha_failover_service.dart';
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
  List<Node>? _previousNodes;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  Future<void> _refreshNodes() async {
    if (mounted) {
      setState(() {
        _nodesFuture =
            context.read<AppProvider>().apiService.getNodes().then((nodes) {
          _checkForFailedNodes(nodes);
          return nodes;
        });
      });
    }
    // Return a completed future to satisfy RefreshIndicator
    return Future.value();
  }

  void _checkForFailedNodes(List<Node> currentNodes) {
    if (_previousNodes != null) {
      final failedNodes =
          HaFailoverService.detectFailedLanNodes(_previousNodes!, currentNodes);

      if (failedNodes.isNotEmpty) {
        // Traiter les pannes détectées
        for (var failedInfo in failedNodes) {
          _handleNodeFailure(failedInfo);
        }
      }
    }
    _previousNodes = List.from(currentNodes);
  }

  void _handleNodeFailure(FailedNodeInfo failedInfo) async {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    try {
      final allNodes = await appProvider.apiService.getNodes();

      // Créer la map des nœuds de remplacement pour toutes les routes affectées
      final Map<String, Node?> replacementNodes = {};
      for (var route in failedInfo.affectedRoutes) {
        replacementNodes[route] = HaFailoverService.getNextAvailableNode(
            route, failedInfo.node.user, allNodes);
      }

      // Afficher le dialogue de basculement si au moins une route a un remplacement
      if (replacementNodes.values.any((node) => node != null) && mounted) {
        final shouldFailover = await HaFailoverService.showFailoverDialog(
            context, failedInfo, replacementNodes, isFr);

        if (shouldFailover) {
          await _performFailover(
              failedInfo, replacementNodes, appProvider, isFr);
        }
      } else if (mounted) {
        // Aucun nœud de remplacement disponible - juste notifier
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Nœud "${failedInfo.node.name}" hors ligne - Aucun backup disponible pour ${failedInfo.affectedRoutes.join(", ")}'
                : 'Node "${failedInfo.node.name}" offline - No backup available for ${failedInfo.affectedRoutes.join(", ")}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Erreur lors de la détection de panne: $e'
                : 'Error during failure detection: $e'),
          ),
        );
      }
    }
  }

  Future<void> _performFailover(
    FailedNodeInfo failedInfo,
    Map<String, Node?> replacementNodes,
    AppProvider appProvider,
    bool isFr,
  ) async {
    showSafeSnackBar(
        context, isFr ? 'Basculement en cours...' : 'Failover in progress...');

    try {
      // 1. Désactiver les routes sur le nœud défaillant
      final failedNodeRoutes = List<String>.from(failedInfo.node.sharedRoutes)
        ..removeWhere((r) => failedInfo.affectedRoutes.contains(r));
      await appProvider.apiService
          .setNodeRoutes(failedInfo.node.id, failedNodeRoutes);

      // 2. Activer les routes sur les nœuds de remplacement
      for (var route in failedInfo.affectedRoutes) {
        final replacementNode = replacementNodes[route];
        if (replacementNode != null) {
          final newRoutes = List<String>.from(replacementNode.sharedRoutes);
          if (!newRoutes.contains(route)) {
            newRoutes.add(route);
          }
          await appProvider.apiService
              .setNodeRoutes(replacementNode.id, newRoutes);

          // Sauvegarder l'événement de basculement
          final failoverEvent = FailoverEvent(
            timestamp: DateTime.now(),
            route: route,
            user: failedInfo.node.user,
            failedNodeName: failedInfo.node.name,
            failedNodeId: failedInfo.node.id,
            replacementNodeName: replacementNode.name,
            replacementNodeId: replacementNode.id,
            reason: isFr ? 'Nœud hors ligne détecté' : 'Node offline detected',
          );
          await HaFailoverService.saveFailoverHistory(failoverEvent);
        }
      }

      // 3. Régénérer et appliquer les ACLs
      final allUsers = await appProvider.apiService.getUsers();
      final updatedNodes =
          await appProvider.apiService.getNodes(); // Re-fetch nodes
      final tempRules = await appProvider.storageService.getTemporaryRules();

      final aclGenerator = NewAclGeneratorService();
      final newPolicyMap = aclGenerator.generatePolicy(
          users: allUsers, nodes: updatedNodes, temporaryRules: tempRules);
      final newPolicyJson = jsonEncode(newPolicyMap);
      await appProvider.apiService.setAclPolicy(newPolicyJson);

      showSafeSnackBar(
          context,
          isFr
              ? 'Basculement HA réussi et ACLs mises à jour !'
              : 'HA failover successful and ACLs updated!');
    } catch (e) {
      showSafeSnackBar(
          context, isFr ? 'Échec du basculement: $e' : 'Failover failed: $e');
    } finally {
      _refreshNodes();
    }
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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final List<Widget> icons = [];

    // 1. Icône de basculement pour les maîtres HA
    final masteredRoutes =
        RouteConflictService.getHaMasteredRoutes(node, allNodes);
    if (masteredRoutes.isNotEmpty) {
      icons.add(
        IconButton(
          icon: const Icon(Icons.swap_horiz, color: Colors.purple),
          tooltip: isFr ? 'Forcer le basculement HA' : 'Force HA Failover',
          onPressed: () => _showHaSwapDialog(context, node, allNodes),
        ),
      );
    }

    // 2. Icônes pour les routes en attente
    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();
    if (pendingRoutes.isNotEmpty) {
      bool hasHaBackupRole = false;
      for (var route in pendingRoutes) {
        if (route != '0.0.0.0/0' && route != '::/0') {
          final validation = RouteConflictService.validateRouteApproval(
              route, node.id, allNodes);
          if (validation.isHaMode) {
            hasHaBackupRole = true;
            break;
          }
        }
      }

      if (hasHaBackupRole) {
        icons.add(
          IconButton(
            icon: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.backup, color: Colors.white, size: 16),
            ),
            tooltip: isFr
                ? 'Ce nœud est un backup pour une route HA'
                : 'This node is a backup for an HA route',
            onPressed: () {
              final pendingHaRoutes = node.availableRoutes
                  .where((r) =>
                      !node.sharedRoutes.contains(r) &&
                      r != '0.0.0.0/0' &&
                      r != '::/0')
                  .toList();
              final routeToDisplay =
                  pendingHaRoutes.isNotEmpty ? pendingHaRoutes.first : '';

              showSafeSnackBar(
                context,
                isFr
                    ? 'Ce nœud est en attente pour la route HA : $routeToDisplay'
                    : 'This node is on standby for HA route: $routeToDisplay',
              );
            },
          ),
        );
      } else {
        icons.add(
          IconButton(
            icon: const Icon(Icons.warning, color: Colors.amber),
            tooltip: isFr ? 'Approbation requise' : 'Approval required',
            onPressed: () => _showApprovalDialog(context, node),
          ),
        );
      }
    }

    // 3. Icône de désynchronisation
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

  void _showHaSwapDialog(
      BuildContext context, Node masterNode, List<Node> allNodes) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    final masteredRoutes =
        RouteConflictService.getHaMasteredRoutes(masterNode, allNodes);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        if (masteredRoutes.isEmpty) {
          return AlertDialog(
            title: Text(isFr ? 'Information' : 'Information'),
            content: Text(isFr
                ? 'Ce nœud n\'est maître d\'aucune route HA.'
                : 'This node is not a master for any HA route.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(isFr ? 'Fermer' : 'Close'),
              ),
            ],
          );
        }

        // Pour l'instant, on gère le basculement pour la première route maîtrisée
        final routeToSwap = masteredRoutes.first;
        final backupNodes = RouteConflictService.getBackupNodesForRoute(
            routeToSwap, masterNode.user, allNodes);

        if (backupNodes.isEmpty) {
          return AlertDialog(
            title:
                Text(isFr ? 'Aucun Backup Disponible' : 'No Backup Available'),
            content: Text(isFr
                ? 'Aucun nœud de backup n\'est disponible pour la route $routeToSwap.'
                : 'No backup node is available for route $routeToSwap.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(isFr ? 'Fermer' : 'Close'),
              ),
            ],
          );
        }

        Node? selectedBackup = backupNodes.first;

        return AlertDialog(
          title: Text(isFr ? 'Forcer le Basculement HA' : 'Force HA Failover'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isFr
                      ? 'Vous allez forcer le basculement de la route $routeToSwap depuis "${masterNode.name}" vers un nœud de backup.'
                      : 'You are about to force a failover for route $routeToSwap from "${masterNode.name}" to a backup node.'),
                  const SizedBox(height: 20),
                  Text(
                      isFr
                          ? 'Choisir le nouveau maître :'
                          : 'Choose the new master:',
                      style: Theme.of(context).textTheme.titleSmall),
                  DropdownButton<Node>(
                    value: selectedBackup,
                    isExpanded: true,
                    items: backupNodes.map((Node node) {
                      return DropdownMenuItem<Node>(
                        value: node,
                        child: Text(node.name),
                      );
                    }).toList(),
                    onChanged: (Node? newValue) {
                      setState(() {
                        selectedBackup = newValue;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isFr ? 'Annuler' : 'Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedBackup == null) return;

                Navigator.of(dialogContext).pop();
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Basculement en cours...'
                        : 'Failover in progress...');

                try {
                  await HaFailoverService.performManualFailover(
                    route: routeToSwap,
                    newPrimaryNode: selectedBackup!,
                    allNodes: allNodes,
                    appProvider: appProvider,
                  );

                  showSafeSnackBar(
                      context,
                      isFr
                          ? 'Basculement réussi et ACLs mises à jour !'
                          : 'Failover successful and ACLs updated!');
                } catch (e) {
                  showSafeSnackBar(
                      context,
                      isFr
                          ? 'Échec du basculement: $e'
                          : 'Failover failed: $e');
                } finally {
                  refreshNodes();
                }
              },
              child: Text(isFr ? 'Confirmer' : 'Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showHaTakeoverDialog(
      BuildContext context, Node backupNode, List<Node> allNodes) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final pendingHaRoutes = backupNode.availableRoutes
            .where((r) =>
                !backupNode.sharedRoutes.contains(r) &&
                r != '0.0.0.0/0' &&
                r != '::/0')
            .toList();

        if (pendingHaRoutes.isEmpty) {
          return AlertDialog(
            title: Text(isFr ? 'Erreur' : 'Error'),
            content: Text(isFr
                ? 'Aucune route HA en attente trouvée pour ce nœud.'
                : 'No pending HA routes found for this node.'),
            actions: [
              TextButton(
                child: Text(isFr ? 'Fermer' : 'Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        }

        // Pour simplifier, on ne gère que la première route en attente.
        // La logique peut être étendue pour en gérer plusieurs.
        final routeToTakeover = pendingHaRoutes.first;
        final activeNode = RouteConflictService.getActiveNodeForRoute(
            routeToTakeover, backupNode.user, allNodes);

        if (activeNode == null) {
          return AlertDialog(
            title: Text(isFr ? 'Erreur' : 'Error'),
            content: Text(isFr
                ? 'Impossible de trouver le nœud actif pour la route $routeToTakeover.'
                : 'Could not find the active node for route $routeToTakeover.'),
            actions: [
              TextButton(
                child: Text(isFr ? 'Fermer' : 'Close'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(isFr ? 'Prise de Contrôle Manuelle' : 'Manual Takeover'),
          content: Text(isFr
              ? 'Attention, cela va remplacer le nœud "${activeNode.name}" qui partage actuellement la route $routeToTakeover.\n\nVoulez-vous continuer ?'
              : 'Warning, this will replace node "${activeNode.name}" which is currently sharing the route $routeToTakeover.\n\nDo you want to continue?'),
          actions: <Widget>[
            TextButton(
              child: Text(isFr ? 'Non' : 'No'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(isFr ? 'Oui' : 'Yes'),
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Fermer la dialog
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Prise de contrôle en cours...'
                        : 'Takeover in progress...');

                try {
                  // 1. Désactiver la route sur le nœud A (actif)
                  final activeNodeRoutes =
                      List<String>.from(activeNode.sharedRoutes)
                        ..remove(routeToTakeover);
                  await appProvider.apiService
                      .setNodeRoutes(activeNode.id, activeNodeRoutes);

                  // 2. Activer la route sur le nœud B (backup)
                  final backupNodeRoutes =
                      List<String>.from(backupNode.sharedRoutes)
                        ..add(routeToTakeover);
                  await appProvider.apiService
                      .setNodeRoutes(backupNode.id, backupNodeRoutes);

                  // 3. Régénérer et appliquer les ACLs
                  final allUsers = await appProvider.apiService.getUsers();
                  final updatedNodes =
                      await appProvider.apiService.getNodes(); // Re-fetch nodes
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
                          ? 'Prise de contrôle réussie !'
                          : 'Takeover successful!');
                } catch (e) {
                  showSafeSnackBar(
                      context,
                      isFr
                          ? 'Échec de la prise de contrôle: $e'
                          : 'Takeover failed: $e');
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

  void _showApprovalDialog(BuildContext context, Node node) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    // Obtenir tous les nœuds pour la validation
    appProvider.apiService.getNodes().then((allNodes) {
      final pendingRoutes = node.availableRoutes
          .where((r) => !node.sharedRoutes.contains(r))
          .toList();
      final isExitNodeRequest =
          pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');
      final lanRoutes =
          pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
      final isLanSharerRequest = lanRoutes.isNotEmpty;

      String title = isFr ? 'Approbation Requise' : 'Approval Required';
      String content = '';
      bool hasConflicts = false;
      List<String> haRoutes = [];
      List<String> conflictRoutes = [];

      // Vérifier les conflits pour chaque route LAN
      for (var route in lanRoutes) {
        final validation = RouteConflictService.validateRouteApproval(
            route, node.id, allNodes);

        if (validation.isConflict) {
          conflictRoutes.add(route);
          hasConflicts = true;
        } else if (validation.isHaMode) {
          haRoutes.add(route);
        }
      }

      // Si il y a des conflits inter-utilisateurs, bloquer l'approbation
      if (conflictRoutes.isNotEmpty) {
        title = isFr ? 'Conflit Détecté' : 'Conflict Detected';
        content = isFr
            ? 'Impossible d\'approuver les routes suivantes car elles sont déjà utilisées par d\'autres utilisateurs :\n\n'
            : 'Cannot approve the following routes as they are already used by other users:\n\n';
        content += '• ${conflictRoutes.join('\n• ')}\n\n';
        content += isFr
            ? 'Veuillez résoudre ces conflits avant de continuer.'
            : 'Please resolve these conflicts before continuing.';

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: <Widget>[
                TextButton(
                  child: Text(isFr ? 'Compris' : 'Understood'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
        return;
      }

      // Construire le message d'approbation
      if (isExitNodeRequest) {
        content += isFr
            ? 'Le nœud "${node.name}" demande à devenir un Exit Node.'
            : 'Node "${node.name}" is requesting to be an exit node.';
      }

      if (isLanSharerRequest) {
        if (content.isNotEmpty) content += '\n\n';

        if (haRoutes.isNotEmpty) {
          content += isFr
              ? 'Routes qui seront placées en backup HA :\n• ${haRoutes.join('\n• ')}\n\n'
              : 'Routes that will be placed in HA backup:\n• ${haRoutes.join('\n• ')}\n\n';
        }

        final normalRoutes =
            lanRoutes.where((r) => !haRoutes.contains(r)).toList();
        if (normalRoutes.isNotEmpty) {
          content += isFr
              ? 'Routes qui seront approuvées normalement :\n• ${normalRoutes.join('\n• ')}\n\n'
              : 'Routes that will be approved normally:\n• ${normalRoutes.join('\n• ')}\n\n';
        }
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
                  Navigator.of(context).pop(); // Close dialog first
                  showSafeSnackBar(context,
                      isFr ? 'Traitement en cours...' : 'Processing...');

                  bool aclMode = true;
                  try {
                    await appProvider.apiService.getAclPolicy();
                  } catch (e) {
                    aclMode = false;
                  }

                  try {
                    if (aclMode) {
                      // Full logic: Tags + Routes + ACLs
                      final newTags = _addCapabilities(
                        List.from(node.tags),
                        addExitNode: isExitNodeRequest,
                        addLanSharer: isLanSharerRequest,
                      );
                      await appProvider.apiService.setTags(node.id, newTags);

                      await appProvider.apiService
                          .setNodeRoutes(node.id, pendingRoutes);

                      final allUsers = await appProvider.apiService.getUsers();
                      final allNodes = await appProvider.apiService.getNodes();
                      final tempRules =
                          await appProvider.storageService.getTemporaryRules();
                      final aclGenerator = NewAclGeneratorService();
                      final newPolicyMap = aclGenerator.generatePolicy(
                          users: allUsers,
                          nodes: allNodes,
                          temporaryRules: tempRules);
                      final newPolicyJson = jsonEncode(newPolicyMap);
                      await appProvider.apiService.setAclPolicy(newPolicyJson);

                      String successMessage = isFr
                          ? 'Nœud approuvé et ACLs mises à jour !'
                          : 'Node approved and ACLs updated!';

                      if (haRoutes.isNotEmpty) {
                        successMessage += isFr
                            ? '\n${haRoutes.length} route(s) placée(s) en backup HA.'
                            : '\n${haRoutes.length} route(s) placed in HA backup.';
                      }

                      showSafeSnackBar(context, successMessage);
                    } else {
                      // Simplified logic: Routes only
                      await appProvider.apiService
                          .setNodeRoutes(node.id, pendingRoutes);
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
                            ? 'Échec de l\'approbation: $e'
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
    }).catchError((error) {
      showSafeSnackBar(
          context,
          isFr
              ? 'Erreur lors de la validation: $error'
              : 'Validation error: $error');
    });
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
                    final allNodes = await appProvider.apiService.getNodes();
                    final tempRules =
                        await appProvider.storageService.getTemporaryRules();
                    final aclGenerator = NewAclGeneratorService();
                    final newPolicyMap = aclGenerator.generatePolicy(
                        users: allUsers,
                        nodes: allNodes,
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
