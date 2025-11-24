import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/ha_node_info.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/ha_failover_service.dart';
import 'package:provider/provider.dart';

class HaManagementScreen extends StatefulWidget {
  const HaManagementScreen({super.key});

  @override
  State<HaManagementScreen> createState() => _HaManagementScreenState();
}

class _HaManagementScreenState extends State<HaManagementScreen> {
  bool _isLoading = true;
  List<User> _users = [];
  List<Node> _nodes = [];
  final Map<String, Map<String, List<HaNodeInfo>>> _haGroups = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      _users = await apiService.getUsers();
      _nodes = await apiService.getNodes();
      _buildHaGroups();
    } catch (e) {
      debugPrint('Erreur lors du chargement des données HA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _buildHaGroups() {
    _haGroups.clear();

    // Grouper par utilisateur puis par réseau LAN (routes actives ET en attente)
    for (var node in _nodes) {
      // Routes LAN actives (partagées)
      final activeLanRoutes = node.sharedRoutes
          .where((route) => route != '0.0.0.0/0' && route != '::/0')
          .toList();

      // Routes LAN en attente (disponibles mais non partagées)
      final pendingLanRoutes = node.availableRoutes
          .where((route) => 
              route != '0.0.0.0/0' && 
              route != '::/0' && 
              !node.sharedRoutes.contains(route))
          .toList();

      // Traiter les routes actives
      if (activeLanRoutes.isNotEmpty) {
        _haGroups.putIfAbsent(node.user, () => {});

        for (var route in activeLanRoutes) {
          _haGroups[node.user]!.putIfAbsent(route, () => []);

          final haNodeInfo = HaNodeInfo(
            node: node,
            route: route,
            order: _haGroups[node.user]![route]!.length + 1,
            isActive: true, // Route active
          );

          _haGroups[node.user]![route]!.add(haNodeInfo);
        }
      }

      // Traiter les routes en attente (seulement si elles forment un groupe HA potentiel)
      if (pendingLanRoutes.isNotEmpty) {
        _haGroups.putIfAbsent(node.user, () => {});

        for (var route in pendingLanRoutes) {
          // Vérifier si cette route est déjà active chez un autre nœud du même utilisateur
          final isHaBackup = HaFailoverService.hasHaBackupRoutes(node, _nodes);
          
          if (isHaBackup) {
            _haGroups[node.user]!.putIfAbsent(route, () => []);

            final haNodeInfo = HaNodeInfo(
              node: node,
              route: route,
              order: _haGroups[node.user]![route]!.length + 1,
              isActive: false, // Route en attente
            );

            _haGroups[node.user]![route]!.add(haNodeInfo);
          }
        }
      }
    }

    // Assigner les ordres en priorisant les nœuds actifs
    for (var userGroups in _haGroups.values) {
      for (var routeNodes in userGroups.values) {
        // Trier : nœuds actifs en premier, puis nœuds en attente
        routeNodes.sort((a, b) {
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;
          return 0; // Garder l'ordre existant pour les nœuds de même statut
        });

        // Réassigner les ordres après tri
        for (int i = 0; i < routeNodes.length; i++) {
          routeNodes[i].order = i + 1;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isFr ? 'Gestion Haute Disponibilité' : 'High Availability Management',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: isFr ? 'Actualiser' : 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildHaContent(isFr),
    );
  }

  Widget _buildHaContent(bool isFr) {
    if (_haGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.network_check,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isFr
                  ? 'Aucun réseau LAN partagé détecté'
                  : 'No shared LAN networks detected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Les nœuds doivent partager des routes LAN pour apparaître ici'
                  : 'Nodes must share LAN routes to appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(isFr),
          const SizedBox(height: 16),
          ..._haGroups.entries
              .map((userEntry) =>
                  _buildUserSection(userEntry.key, userEntry.value, isFr))
              ,
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isFr) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isFr ? 'Haute Disponibilité (HA)' : 'High Availability (HA)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isFr
                  ? 'Cette page liste tous les réseaux LAN partagés organisés par utilisateur. '
                      'Quand plusieurs nœuds d\'un même utilisateur partagent le même réseau, '
                      'ils forment un groupe HA. Utilisez le glisser-déposer pour réorganiser l\'ordre de priorité.'
                  : 'This page lists all shared LAN networks organized by user. '
                      'When multiple nodes from the same user share the same network, '
                      'they form an HA group. Use drag and drop to reorder the priority.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection(
      String userName, Map<String, List<HaNodeInfo>> userRoutes, bool isFr) {
    final user = _users.firstWhere((u) => u.name == userName,
        orElse: () => User(id: '', name: userName, createdAt: DateTime.now()));

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          userName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          isFr
              ? '${userRoutes.length} réseau(x) LAN partagé(s)'
              : '${userRoutes.length} shared LAN network(s)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: userRoutes.entries
            .map((routeEntry) =>
                _buildRouteSection(routeEntry.key, routeEntry.value, isFr))
            .toList(),
      ),
    );
  }

  Widget _buildRouteSection(String route, List<HaNodeInfo> nodes, bool isFr) {
    final isHaGroup = nodes.length > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isHaGroup
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
        color: isHaGroup
            ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHaGroup
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHaGroup ? Icons.group_work : Icons.router,
                  size: 20,
                  color: isHaGroup
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
                if (isHaGroup) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'HA',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isHaGroup)
            _buildReorderableNodeList(route, nodes, isFr)
          else
            ...nodes.map(
                (haNodeInfo) => _buildNodeTile(haNodeInfo, isHaGroup, isFr)),
        ],
      ),
    );
  }

  Widget _buildReorderableNodeList(
      String route, List<HaNodeInfo> nodes, bool isFr) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: nodes.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = nodes.removeAt(oldIndex);
          nodes.insert(newIndex, item);

          // Réassigner les ordres et le statut actif
          for (int i = 0; i < nodes.length; i++) {
            nodes[i].order = i + 1;
            nodes[i].isActive = (i == 0);
          }
        });

        // Exécuter la logique de basculement en arrière-plan
        _performHaReorder(route, nodes);
      },
      itemBuilder: (context, index) {
        final haNodeInfo = nodes[index];
        return _buildDraggableNodeTile(
          key: ValueKey('${haNodeInfo.node.id}_${haNodeInfo.route}'),
          haNodeInfo: haNodeInfo,
          isHaGroup: true,
          isFr: isFr,
        );
      },
    );
  }

  Future<void> _performHaReorder(String route, List<HaNodeInfo> orderedNodes) async {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    if (orderedNodes.isEmpty) return;

    final newPrimaryNode = orderedNodes.first.node;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFr
            ? 'Application de la nouvelle priorité pour $route...'
            : 'Applying new priority for $route...'),
      ),
    );

    try {
      await HaFailoverService.performManualFailover(
        route: route,
        newPrimaryNode: newPrimaryNode,
        allNodes: _nodes,
        appProvider: appProvider,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Priorité HA et ACLs mises à jour pour $route !'
                : 'HA priority and ACLs updated for $route!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Erreur lors de la mise à jour: $e'
                : 'Error during update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Recharger les données pour refléter l'état réel du serveur
      if (mounted) {
        _loadData();
      }
    }
  }

  Widget _buildDraggableNodeTile({
    required Key key,
    required HaNodeInfo haNodeInfo,
    required bool isHaGroup,
    required bool isFr,
  }) {
    final node = haNodeInfo.node;
    final isPrimary = haNodeInfo.order == 1 && isHaGroup;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        children: [
          // Icône de glisser-déposer
          Icon(
            Icons.drag_handle,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          const SizedBox(width: 8),

          // Indicateur d'ordre/priorité
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
            ),
            child: Center(
              child: Text(
                haNodeInfo.order.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isPrimary ? 16 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Informations du nœud
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: node.online ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      node.online
                          ? (isFr ? 'En ligne' : 'Online')
                          : (isFr ? 'Hors ligne' : 'Offline'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: node.online ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.ipAddresses.join(', '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Badge de statut
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            haNodeInfo.isActive ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        haNodeInfo.isActive
                            ? (isFr ? 'ACTIF' : 'ACTIVE')
                            : (isFr ? 'ATTENTE' : 'STANDBY'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFr ? 'PRIMAIRE' : 'PRIMARY',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeTile(HaNodeInfo haNodeInfo, bool isHaGroup, bool isFr) {
    final node = haNodeInfo.node;
    final isPrimary = haNodeInfo.order == 1 && isHaGroup;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Indicateur d'ordre/priorité
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPrimary
                  ? Theme.of(context).colorScheme.primary
                  : isHaGroup
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            child: Center(
              child: Text(
                isHaGroup ? haNodeInfo.order.toString() : '•',
                style: TextStyle(
                  color: isPrimary || isHaGroup
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: isPrimary ? 16 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Informations du nœud
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      node.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: node.online ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      node.online
                          ? (isFr ? 'En ligne' : 'Online')
                          : (isFr ? 'Hors ligne' : 'Offline'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: node.online ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.ipAddresses.join(', '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Badge de statut
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            haNodeInfo.isActive ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        haNodeInfo.isActive
                            ? (isFr ? 'ACTIF' : 'ACTIVE')
                            : (isFr ? 'ATTENTE' : 'STANDBY'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isFr ? 'PRIMAIRE' : 'PRIMARY',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
