import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

/// Écran affichant les détails d'un nœud Headscale spécifique.
class NodeDetailScreen extends StatefulWidget {
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  bool _isPingingContinuously = false;
  StreamSubscription<PingData>? _pingSubscription;
  // Variable d'état pour le nœud actuel, afin de pouvoir le mettre à jour.
  late Node _currentNode;
  // Utilisation d'un Set pour gérer efficacement les routes sélectionnées.
  late Set<String> _selectedRoutes;
  final List<PingData> _pingResponses = [];

  @override
  void initState() {
    super.initState();
    // Initialise l'état local avec les données du nœud passées au widget.
    _currentNode = widget.node;
    _selectedRoutes = Set<String>.from(_currentNode.sharedRoutes);
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
    final isDarkMode = theme.brightness == Brightness.dark;
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme
          .scaffoldBackgroundColor, // Utilisation de la couleur de fond du thème
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
            _buildIpAddressesCard(context),
            const SizedBox(height: 16),
            _buildIdentifiersCard(context),
            const SizedBox(height: 16),
            _buildRoutesCard(
                context), // Ajout de la nouvelle carte de gestion des routes
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
              Icon(Icons.circle, // Utilise _currentNode pour le statut
                  color: _currentNode.online ? Colors.green : Colors.grey,
                  size: 16), // Taille de l'icône
              const SizedBox(width: 8),
              Text(
                  _currentNode.online
                      ? (isFr ? 'En ligne' : 'Online')
                      : (isFr ? 'Hors ligne' : 'Offline'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: _currentNode.online ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold)), // Style du texte
              const Spacer(),
              if (widget.node.isExitNode)
                Chip(
                    label: const Text('Exit Node'),
                    backgroundColor: theme.colorScheme.primary,
                    labelStyle: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
            ],
          ),
          const SizedBox(height: 16), // Espace vertical
          Text(_currentNode.hostname, // Utilise _currentNode pour le nom d'hôte
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              '${isFr ? 'Utilisateur' : 'User'}: ${_currentNode.user}', // Utilise _currentNode pour l'utilisateur
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
              '${isFr ? 'Dernière connexion' : 'Last seen'}: ${_currentNode.lastSeen.toLocal()}', // Utilise _currentNode pour la dernière connexion
              style: theme.textTheme.bodySmall),
        ],
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20), // Séparateur visuel
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

  /// Construit la carte de gestion des routes.
  Widget _buildRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    // Fusionne les routes disponibles et approuvées pour tout afficher, en évitant les doublons.
    final allPossibleRoutes = (Set<String>.from(_currentNode.availableRoutes)
          ..addAll(_currentNode.sharedRoutes))
        .toList();

    // Si le nœud n'annonce aucune route, on n'affiche pas la carte.
    if (allPossibleRoutes.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isFr ? 'Gestion des Routes' : 'Route Management',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Text(
            isFr
                ? 'Cochez les routes que vous souhaitez approuver pour ce nœud.'
                : 'Check the routes you want to approve for this node.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          // Liste des routes avec des cases à cocher.
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allPossibleRoutes.length,
            itemBuilder: (context, index) {
              final route = allPossibleRoutes[index];
              return CheckboxListTile(
                title: Text(route,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace')),
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
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _saveRoutes,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(isFr ? 'Appliquer les changements' : 'Apply Changes',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: theme.colorScheme.onPrimary)),
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
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Text('Tags:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: _currentNode.tags.isEmpty
                ? [
                    Text(isFr ? 'Aucun tag' : 'No tags',
                        style: theme.textTheme.bodyMedium)
                  ]
                : _currentNode.tags
                    .map((tag) => Chip(
                        label: Text(tag, style: theme.textTheme.labelSmall)))
                    .toList(),
          ),
        ],
      ),
    );
  }

  /// Sauvegarde les routes sélectionnées via l'API et met à jour l'état local.
  Future<void> _saveRoutes() async {
    final apiService = context.read<AppProvider>().apiService;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    try {
      // Envoie la liste des routes sélectionnées à l'API.
      await apiService.setNodeRoutes(_currentNode.id, _selectedRoutes.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isFr
                  ? 'Routes mises à jour avec succès.'
                  : 'Routes updated successfully.')),
        );
        // Recharge les détails du nœud pour refléter les changements immédiatement.
        final updatedNode = await apiService.getNodeDetails(_currentNode.id);
        setState(() {
          _currentNode = updatedNode;
          // Resynchronise également les routes sélectionnées au cas où.
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
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: Text(isFr ? 'Outils de diagnostic' : 'Diagnostic Tools',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(isFr ? "Ping en continu" : "Continuous Ping",
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Switch(
                      value: _isPingingContinuously,
                      onChanged: _toggleContinuousPing,
                      activeColor: theme.colorScheme.primary,
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
            style: theme.textTheme.bodyMedium),
        Text(
            "${isFr ? 'Paquets perdus' : 'Packet loss'}: ${loss.toStringAsFixed(0)}% ($received/$transmitted ${isFr ? 'reçus' : 'received'})",
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        _buildPingChart(context),
        const SizedBox(height: 20),
        Text(isFr ? "Journal du ping:" : "Ping Log:",
            style: theme.textTheme.bodyMedium),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.grey[200],
            border: Border.all(color: theme.dividerColor),
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'));
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

    // Limiter le nombre de points affichés pour la lisibilité
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
                  color: theme.dividerColor.withOpacity(0.5), strokeWidth: 0.1),
              getDrawingVerticalLine: (value) => FlLine(
                  color: theme.dividerColor.withOpacity(0.5),
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
              border: Border.all(color: theme.dividerColor, width: 1)),
          minX: spots.first.x,
          maxX: spots.last.x,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                  show: true,
                  color: theme.colorScheme.primary.withOpacity(0.3)),
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
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
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
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace')),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: theme.iconTheme.color),
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
                            ?.copyWith(color: theme.colorScheme.onPrimary)),
                    backgroundColor: theme.colorScheme.primary),
              );
            },
          ),
        ],
      ),
    );
  }
}
