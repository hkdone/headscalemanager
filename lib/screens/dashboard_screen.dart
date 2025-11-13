import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/api_keys_screen.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Node>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNodes();
  }

  void _refreshNodes() {
    if (mounted) {
      setState(() {
        _nodesFuture = context.read<AppProvider>().apiService.getNodes();
      });
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
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                      '${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Text(isFr ? 'Aucun nœud trouvé.' : 'No node found.'));
            }

            final nodes = snapshot.data!;
            final nodesByUser = <String, List<Node>>{};
            for (var node in nodes) {
              (nodesByUser[node.user] ??= []).add(node);
            }

            final users = nodesByUser.keys.toList();
            final connectedNodes = nodes.where((node) => node.online).length;
            final disconnectedNodes = nodes.length - connectedNodes;

            return Column(
              children: [
                _buildSummarySection(
                    users.length, connectedNodes, disconnectedNodes, isFr),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userNodes = nodesByUser[user]!;
                      return _UserNodeCard(
                        user: user,
                        nodes: userNodes,
                        refreshNodes: _refreshNodes,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(isFr),
    );
  }

  Widget _buildSummarySection(
      int userCount, int connectedCount, int disconnectedCount, bool isFr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
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

  Widget _buildFloatingActionButtons(bool isFr) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: _refreshNodes,
          heroTag: 'refreshNodes',
          tooltip: isFr ? 'Rafraîchir les nœuds' : 'Refresh nodes',
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ApiKeysScreen())),
          heroTag: 'apiKeys',
          tooltip: isFr ? 'Gérer les clés API' : 'Manage API keys',
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.api, color: Colors.white),
        ),
      ],
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
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _UserNodeCard extends StatelessWidget {
  final String user;
  final List<Node> nodes;
  final VoidCallback refreshNodes;

  const _UserNodeCard(
      {required this.user, required this.nodes, required this.refreshNodes});

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
        children:
            nodes.map((node) => _buildNodeTile(context, node)).toList(),
      ),
    );
  }

  Widget _buildNodeTile(BuildContext context, Node node) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final trailingIcon = _buildTrailingIcon(context, node);

    return ListTile(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => NodeDetailScreen(node: node))),
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

  Widget? _buildTrailingIcon(BuildContext context, Node node) {
    final hasPendingApproval = node.availableRoutes
        .any((r) => !node.sharedRoutes.contains(r));

    if (hasPendingApproval) {
      return IconButton(
        icon: const Icon(Icons.warning, color: Colors.amber),
        tooltip: 'Approbation requise',
        onPressed: () => _showApprovalDialog(context, node),
      );
    }

    final hasDesync = node.sharedRoutes
        .any((r) => !node.availableRoutes.contains(r));
    
    if (hasDesync) {
      return IconButton(
        icon: const Icon(Icons.link_off, color: Colors.blueGrey),
        tooltip: 'Nettoyage de la configuration requis',
        onPressed: () => _showCleanupDialog(context, node),
      );
    }

    return null;
  }

  void _showApprovalDialog(BuildContext context, Node node) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    final pendingRoutes = node.availableRoutes
        .where((r) => !node.sharedRoutes.contains(r))
        .toList();
    final isExitNodeRequest = pendingRoutes.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes = pendingRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
    final isLanSharerRequest = lanRoutes.isNotEmpty;

    String title = isFr ? 'Approbation Requise' : 'Approval Required';
    String content = '';

    if (isExitNodeRequest) {
      content += isFr
          ? 'Le nœud "${node.name}" demande à devenir un Exit Node.'
          : 'Node "${node.name}" is requesting to be an exit node.';
    }
    if (isLanSharerRequest) {
      if (content.isNotEmpty) content += '\n\n';
      content += isFr
          ? 'Il demande aussi à partager le(s) sous-réseau(x) : ${lanRoutes.join(', ')}.'
          : 'It is also requesting to share the subnet(s): ${lanRoutes.join(', ')}.';
    }
    content += isFr
        ? '\n\nVoulez-vous approuver cette (ces) demande(s) ?'
        : '\n\nDo you want to approve this (these) request(s)?';

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
                showSnackBar(context,
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
                    List<String> newTags = List.from(node.tags);
                    int clientTagIndex =
                        newTags.indexWhere((t) => t.endsWith('-client'));

                    if (clientTagIndex != -1) {
                      String clientTag = newTags[clientTagIndex];
                      if (isExitNodeRequest && !clientTag.contains(';exit-node')) {
                        clientTag += ';exit-node';
                      }
                      if (isLanSharerRequest && !clientTag.contains(';lan-sharer')) {
                        clientTag += ';lan-sharer';
                      }
                      newTags[clientTagIndex] = clientTag;
                    } else {
                      if (isExitNodeRequest && !newTags.contains('tag:exit-node')) {
                        newTags.add('tag:exit-node');
                      }
                      if (isLanSharerRequest && !newTags.contains('tag:lan-sharer')) {
                        newTags.add('tag:lan-sharer');
                      }
                    }
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService.setNodeRoutes(node.id, pendingRoutes);

                    final allUsers = await appProvider.apiService.getUsers();
                    final allNodes = await appProvider.apiService.getNodes();
                    final tempRules =
                        await appProvider.storageService.getTemporaryRules();
                    final aclGenerator = NewAclGeneratorService();
                    final newPolicyMap = aclGenerator.generatePolicy(
                        users: allUsers, nodes: allNodes, temporaryRules: tempRules);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    showSuccessSnackBar(
                        context,
                        isFr
                            ? 'Nœud approuvé et ACLs mises à jour !'
                            : 'Node approved and ACLs updated!');
                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService.setNodeRoutes(node.id, pendingRoutes);
                    showSuccessSnackBar(
                        context,
                        isFr
                            ? 'Routes approuvées (ACLs non gérées).'
                            : 'Routes approved (ACLs not managed).');
                  }
                } catch (e) {
                  showErrorSnackBar(context, isFr ? 'Échec : $e' : 'Failed: $e');
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
    final hadExitNode = routesToClean.any((r) => r == '0.0.0.0/0' || r == '::/0');
    final lanRoutes = routesToClean.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
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
                showSnackBar(context, isFr ? 'Nettoyage en cours...' : 'Cleaning up...');

                bool aclMode = true;
                try {
                  await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                try {
                  final remainingRoutes = node.sharedRoutes.where((r) => node.availableRoutes.contains(r)).toList();

                  if (aclMode) {
                    // Full logic: Tags + Routes + ACLs
                    List<String> newTags = List.from(node.tags);
                    int clientTagIndex =
                        newTags.indexWhere((t) => t.endsWith('-client'));

                    if (clientTagIndex != -1) {
                      String clientTag = newTags[clientTagIndex];
                      if (hadExitNode) {
                        clientTag = clientTag.replaceAll(';exit-node', '');
                      }
                      if (hadLanSharing) {
                        clientTag = clientTag.replaceAll(';lan-sharer', '');
                      }
                      newTags[clientTagIndex] = clientTag;
                    } else {
                        newTags.removeWhere((t) => t == 'tag:exit-node' || t == 'tag:lan-sharer');
                    }
                    await appProvider.apiService.setTags(node.id, newTags);

                    await appProvider.apiService.setNodeRoutes(node.id, remainingRoutes);

                    final allUsers = await appProvider.apiService.getUsers();
                    final allNodes = await appProvider.apiService.getNodes();
                    final tempRules =
                        await appProvider.storageService.getTemporaryRules();
                    final aclGenerator = NewAclGeneratorService();
                    final newPolicyMap = aclGenerator.generatePolicy(
                        users: allUsers, nodes: allNodes, temporaryRules: tempRules);
                    final newPolicyJson = jsonEncode(newPolicyMap);
                    await appProvider.apiService.setAclPolicy(newPolicyJson);

                    showSuccessSnackBar(
                        context,
                        isFr
                            ? 'Configuration nettoyée et ACLs mises à jour !'
                            : 'Configuration cleaned up and ACLs updated!');

                  } else {
                    // Simplified logic: Routes only
                    await appProvider.apiService.setNodeRoutes(node.id, remainingRoutes);
                     showSuccessSnackBar(
                        context,
                        isFr
                            ? 'Configuration des routes nettoyée (ACLs non gérées).'
                            : 'Route configuration cleaned up (ACLs not managed).');
                  }
                } catch (e) {
                  showErrorSnackBar(context, isFr ? 'Échec : $e' : 'Failed: $e');
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
}
