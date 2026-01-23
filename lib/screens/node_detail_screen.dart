import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/widgets/rename_node_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NodeDetailScreen extends StatefulWidget {
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  bool _isPingingContinuously = false;
  StreamSubscription<PingData>? _pingSubscription;
  late Node _currentNode;
  late Set<String> _selectedRoutes;
  final List<PingData> _pingResponses = [];
  bool _isMonitoringEnabled = false;

  @override
  void initState() {
    super.initState();
    _currentNode = widget.node;
    _selectedRoutes = Set<String>.from(_currentNode.sharedRoutes);
    _loadMonitoringStatus();
  }

  Future<void> _loadMonitoringStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final monitoredNodes = prefs.getStringList('monitoredNodeIds') ?? [];
    if (!mounted) return;
    setState(() {
      _isMonitoringEnabled = monitoredNodes.contains(_currentNode.id);
    });
  }

  Future<void> _toggleMonitoring(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> monitoredNodes = prefs.getStringList('monitoredNodeIds') ?? [];
    String lastKnownStatusKey = 'monitoredNode_${_currentNode.id}_status';
    if (!mounted) return;
    setState(() {
      _isMonitoringEnabled = value;
    });

    if (value) {
      if (!monitoredNodes.contains(_currentNode.id)) {
        monitoredNodes.add(_currentNode.id);
      }
      // Store the current status to avoid immediate notification
      await prefs.setBool(lastKnownStatusKey, _currentNode.online);
    } else {
      monitoredNodes.remove(_currentNode.id);
      // Clean up the stored status
      await prefs.remove(lastKnownStatusKey);
    }
    await prefs.setStringList('monitoredNodeIds', monitoredNodes);
  }

  String get _ipv4 {
    return _currentNode.ipAddresses
        .firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  }

  String get _ipv6 {
    return _currentNode.ipAddresses
        .firstWhere((ip) => ip.contains(':'), orElse: () => '');
  }

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  void _toggleContinuousPing(bool value) {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    setState(() {
      _isPingingContinuously = value;
      _pingResponses.clear();
    });

    if (_isPingingContinuously) {
      if (_ipv4.isEmpty) {
        setState(() => _isPingingContinuously = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isFr
                  ? 'Aucune adresse IPv4 trouvée pour ce nœud.'
                  : 'No IPv4 address found for this node.')),
        );
        return;
      }

      final ping = Ping(_ipv4, count: 10000); // Effectively continuous
      _pingSubscription = ping.stream.listen((event) {
        if (mounted) setState(() => _pingResponses.add(event));
      }, onDone: () {
        if (mounted) setState(() => _isPingingContinuously = false);
      });
    } else {
      _pingSubscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.node.name, style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildMainInfoCard(context),
            const SizedBox(height: 16),
            _buildMonitoringCard(context),
            const SizedBox(height: 16),
            _buildIpAddressesCard(context),
            const SizedBox(height: 16),
            _buildIdentifiersCard(context),
            const SizedBox(height: 16),
            _buildRoutesCard(context),
            const SizedBox(height: 16),
            _buildTagsAndRoutesCard(context),
            const SizedBox(height: 16),
            _buildPingCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle,
                  color: _currentNode.online
                      ? Colors.green
                      : theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  size: 16),
              const SizedBox(width: 8),
              Text(
                  _currentNode.online
                      ? (isFr ? 'En ligne' : 'Online')
                      : (isFr ? 'Hors ligne' : 'Offline'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: _currentNode.online
                          ? Colors.green
                          : theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.node.isExitNode)
                Chip(
                    label: Text('Exit Node',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                    backgroundColor: theme.colorScheme.onPrimary,
                    labelStyle: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                child: Text(_currentNode.hostname,
                    style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary)),
              ),
              if (!isValidDns1123Subdomain(_currentNode.name))
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 24),
                    tooltip: isFr
                        ? 'Nom invalide (v0.27+)'
                        : 'Invalid name (v0.27+)',
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (dialogContext) => RenameNodeDialog(
                              node: _currentNode,
                              onNodeRenamed: () async {
                                // Refresh local node details
                                final updated = await context
                                    .read<AppProvider>()
                                    .apiService
                                    .getNodeDetails(_currentNode.id);
                                if (context.mounted) {
                                  setState(() => _currentNode = updated);
                                }
                              }));
                    },
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text('${isFr ? 'Utilisateur' : 'User'}: ${_currentNode.user}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 8),
          Text(
              '${isFr ? 'Dernière connexion' : 'Last seen'}: ${_currentNode.lastSeen.toLocal()}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildMonitoringCard(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    return _SectionCard(
      child: SwitchListTile(
        title: Text(isFr ? 'Surveiller le statut' : 'Monitor Status',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        subtitle: Text(
            isFr
                ? 'Recevoir une notification si le nœud se connecte ou se déconnecte.'
                : 'Receive a notification if the node goes online or offline.',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7))),
        value: _isMonitoringEnabled,
        onChanged: _toggleMonitoring,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildIpAddressesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFr ? 'Adresses IP' : 'IP Addresses',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          if (_ipv4.isNotEmpty) _DetailRowWithCopy(label: 'IPv4', value: _ipv4),
          if (_ipv6.isNotEmpty) _DetailRowWithCopy(label: 'IPv6', value: _ipv6),
        ],
      ),
    );
  }

  Widget _buildIdentifiersCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFr ? 'Identifiants' : 'Identifiers',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          _DetailRowWithCopy(
              label: isFr ? 'ID Nœud' : 'Node ID', value: _currentNode.id),
          _DetailRowWithCopy(
              label: isFr ? 'Clé Machine' : 'Machine Key',
              value: _currentNode.machineKey),
          _DetailRowWithCopy(label: 'FQDN', value: _currentNode.fqdn),
        ],
      ),
    );
  }

  Widget _buildRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final allPossibleRoutes = (Set<String>.from(_currentNode.availableRoutes)
          ..addAll(_currentNode.sharedRoutes))
        .toList();

    if (allPossibleRoutes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFr ? 'Gestion des Routes' : 'Route Management',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          Text(
              isFr
                  ? 'Cochez les routes que vous souhaitez approuver pour ce nœud.'
                  : 'Check the routes you want to approve for this node.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPossibleRoutes.length,
            itemBuilder: (context, index) {
              final route = allPossibleRoutes[index];
              return CheckboxListTile(
                title: Text(route,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onPrimary)),
                value: _selectedRoutes.contains(route),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedRoutes.add(route);
                    } else {
                      _selectedRoutes.remove(route);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                checkColor: theme.colorScheme.primary,
                activeColor: theme.colorScheme.onPrimary,
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _saveRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(isFr ? 'Appliquer les changements' : 'Apply Changes',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsAndRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          Divider(
              height: 20,
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
          Text('Tags:',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: _currentNode.tags.isEmpty
                ? [
                    Text(isFr ? 'Aucun tag' : 'No tags',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary))
                  ]
                : _currentNode.tags
                    .map((tag) => Chip(
                          label: Text(tag,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: theme.colorScheme.primary)),
                          backgroundColor: theme.colorScheme.onPrimary,
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoutes() async {
    final appProvider = context.read<AppProvider>();
    final apiService = appProvider.apiService;
    final isFr = appProvider.locale.languageCode == 'fr';

    try {
      // Obtenir tous les nœuds pour la validation
      final allNodes = await apiService.getNodes();

      // Vérifier les conflits pour les nouvelles routes sélectionnées
      final newRoutes =
          _selectedRoutes.difference(Set.from(_currentNode.sharedRoutes));
      List<String> conflictRoutes = [];

      for (var route in newRoutes) {
        // Ignorer les routes exit node
        if (route == '0.0.0.0/0' || route == '::/0') continue;

        final validation = RouteConflictService.validateRouteApproval(
            route, _currentNode.id, allNodes);

        if (validation.isConflict) {
          conflictRoutes.add(route);
        }
      }

      // Si il y a des conflits, afficher un message d'erreur et empêcher la sauvegarde
      if (conflictRoutes.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(isFr ? 'Conflit Détecté' : 'Conflict Detected'),
                content: Text(isFr
                    ? 'Impossible d\'approuver les routes suivantes car elles sont déjà utilisées par d\'autres utilisateurs :\n\n• ${conflictRoutes.join('\n• ')}\n\nVeuillez décocher ces routes avant de continuer.'
                    : 'Cannot approve the following routes as they are already used by other users:\n\n• ${conflictRoutes.join('\n• ')}\n\nPlease uncheck these routes before continuing.'),
                actions: <Widget>[
                  TextButton(
                    child: Text(isFr ? 'Compris' : 'Understood'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Décocher automatiquement les routes en conflit
                      setState(() {
                        for (var route in conflictRoutes) {
                          _selectedRoutes.remove(route);
                        }
                      });
                    },
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // Procéder à la sauvegarde si aucun conflit
      if (!mounted) return;
      showSafeSnackBar(
          context, isFr ? 'Mise à jour des routes...' : 'Updating routes...');
      await apiService.setNodeRoutes(_currentNode.id, _selectedRoutes.toList());

      // Régénérer et appliquer les ACLs
      if (!mounted) return;
      showSafeSnackBar(
          context, isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');
      final allUsers = await apiService.getUsers();
      final updatedNodes = await apiService.getNodes(); // Re-fetch nodes
      final serverId = appProvider.activeServer?.id;
      if (serverId == null) {
        if (!mounted) return;
        showSafeSnackBar(
            context,
            isFr
                ? 'Aucun serveur actif sélectionné.'
                : 'No active server selected.');
        return;
      }
      final tempRules =
          await appProvider.storageService.getTemporaryRules(serverId);

      final aclGenerator = NewAclGeneratorService();
      final newPolicyMap = aclGenerator.generatePolicy(
          users: allUsers, nodes: updatedNodes, temporaryRules: tempRules);
      final newPolicyJson = jsonEncode(newPolicyMap);
      await apiService.setAclPolicy(newPolicyJson);

      if (mounted) {
        showSafeSnackBar(
            context,
            isFr
                ? 'Routes et ACLs mises à jour avec succès !'
                : 'Routes and ACLs updated successfully!');

        // Rafraîchir l'état local
        final freshlyUpdatedNode =
            await apiService.getNodeDetails(_currentNode.id);
        setState(() {
          _currentNode = freshlyUpdatedNode;
          _selectedRoutes = Set<String>.from(_currentNode.sharedRoutes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${isFr ? 'Erreur' : 'Error'}: $e')));
      }
    }
  }

  Widget _buildPingCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: Text(isFr ? 'Outils de diagnostic' : 'Diagnostic Tools',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(isFr ? "Ping en continu" : "Continuous Ping",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                    const Spacer(),
                    Switch(
                      value: _isPingingContinuously,
                      onChanged: _toggleContinuousPing,
                      activeThumbColor: theme.colorScheme.onPrimary,
                      inactiveTrackColor:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.3),
                      inactiveThumbColor:
                          theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isPingingContinuously)
                  _buildContinuousPingResults(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousPingResults(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    if (_pingResponses.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }

    final responses = _pingResponses
        .where((e) => e.response != null)
        .map((e) => e.response!)
        .toList();
    final transmitted = _pingResponses.length;
    final received = responses.length;
    final loss = transmitted > 0 ? (1 - received / transmitted) * 100 : 0;

    final latencies = responses
        .where((e) => e.time != null)
        .map((e) => e.time!.inMilliseconds)
        .toList();
    final avgLatency = latencies.isNotEmpty
        ? latencies.reduce((a, b) => a + b) / latencies.length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            "${isFr ? 'Latence moyenne' : 'Average latency'}: ${avgLatency.toStringAsFixed(2)} ms",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        Text(
            "${isFr ? 'Paquets perdus' : 'Packet loss'}: ${loss.toStringAsFixed(0)}% ($received/$transmitted ${isFr ? 'reçus' : 'received'})",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        const SizedBox(height: 20),
        _buildPingChart(context),
        const SizedBox(height: 20),
        Text(isFr ? "Journal du ping:" : "Ping Log:",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimary)),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
            border: Border.all(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            reverse: true,
            itemCount: _pingResponses.length,
            itemBuilder: (context, index) {
              final data = _pingResponses.reversed.toList()[index];
              if (data.response != null) {
                return Text(
                    "${isFr ? 'Réponse de' : 'Reply from'} ${data.response!.ip}: ${isFr ? 'temps' : 'time'}=${data.response!.time?.inMilliseconds}ms",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onPrimary));
              } else if (data.error != null) {
                return Text(
                    "${isFr ? 'Erreur' : 'Error'}: ${data.error!.error.toString()}",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.red, fontFamily: 'monospace'));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPingChart(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final List<FlSpot> spots = [];
    final relevantPings =
        _pingResponses.where((p) => p.response?.time != null).toList();

    final start = relevantPings.length > 30 ? relevantPings.length - 30 : 0;
    for (int i = start; i < relevantPings.length; i++) {
      final ping = relevantPings[i];
      spots.add(
          FlSpot(i.toDouble(), ping.response!.time!.inMilliseconds.toDouble()));
    }

    if (spots.isEmpty) {
      return SizedBox(
          height: 150,
          child: Center(
              child: Text(
                  isFr
                      ? "En attente de données de ping..."
                      : "Waiting for ping data...",
                  style: theme.textTheme.bodyMedium)));
    }

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  strokeWidth: 0.1),
              getDrawingVerticalLine: (value) => FlLine(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  strokeWidth: 0.1)),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
              show: true,
              border: Border.all(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
                  width: 1)),
          minX: spots.first.x,
          maxX: spots.last.x,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.secondary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.primary,
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}

class _DetailRowWithCopy extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRowWithCopy({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary)),
          ),
          Expanded(
            child: SelectableText(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onPrimary)),
          ),
          IconButton(
            icon:
                Icon(Icons.copy, size: 18, color: theme.colorScheme.onPrimary),
            tooltip: isFr ? 'Copier' : 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        isFr
                            ? 'Copié dans le presse-papiers'
                            : 'Copied to clipboard',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                    backgroundColor: theme.colorScheme.onPrimary),
              );
            },
          ),
        ],
      ),
    );
  }
}
