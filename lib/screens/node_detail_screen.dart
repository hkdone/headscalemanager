import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
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
  final List<PingData> _pingResponses = [];

  String get _ipv4 {
    return widget.node.ipAddresses
        .firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  }

  String get _ipv6 {
    return widget.node.ipAddresses
        .firstWhere((ip) => ip.contains(':'), orElse: () => '');
  }

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  void _toggleContinuousPing(bool value) {
    setState(() {
      _isPingingContinuously = value;
      _pingResponses.clear();
    });

    if (_isPingingContinuously) {
      if (_ipv4.isEmpty) {
        setState(() => _isPingingContinuously = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucune adresse IPv4 trouvée pour ce nœud.')),
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
            _buildIpAddressesCard(context),
            const SizedBox(height: 16),
            _buildIdentifiersCard(context),
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
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle,
                  color: widget.node.online ? Colors.green : Colors.grey,
                  size: 16),
              const SizedBox(width: 8),
              Text(widget.node.online ? 'En ligne' : 'Hors ligne',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: widget.node.online ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.node.isExitNode)
                Chip(
                    label: const Text('Exit Node'),
                    backgroundColor: theme.colorScheme.primary,
                    labelStyle: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.onPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.node.hostname,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Utilisateur: ${widget.node.user}',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Dernière connexion: ${widget.node.lastSeen.toLocal()}',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildIpAddressesCard(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adresses IP',
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
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Identifiants',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          _DetailRowWithCopy(label: 'ID Nœud', value: widget.node.id),
          _DetailRowWithCopy(
              label: 'Clé Machine', value: widget.node.machineKey),
          _DetailRowWithCopy(label: 'FQDN', value: widget.node.fqdn),
        ],
      ),
    );
  }

  Widget _buildTagsAndRoutesCard(BuildContext context) {
    final theme = Theme.of(context);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tags & Routes',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          Text('Tags:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: widget.node.tags.isEmpty
                ? [Text('Aucun tag', style: theme.textTheme.bodyMedium)]
                : widget.node.tags
                    .map((tag) => Chip(
                        label: Text(tag, style: theme.textTheme.labelSmall)))
                    .toList(),
          ),
          const SizedBox(height: 16),
          Text('Routes partagées:',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          widget.node.sharedRoutes.isEmpty
              ? Text('Aucune', style: theme.textTheme.bodyMedium)
              : Text(widget.node.sharedRoutes.join(', '),
                  style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildPingCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: Text('Outils de diagnostic',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text("Ping en continu", style: theme.textTheme.bodyMedium),
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
        Text("Latence moyenne: ${avgLatency.toStringAsFixed(2)} ms",
            style: theme.textTheme.bodyMedium),
        Text(
            "Paquets perdus: ${loss.toStringAsFixed(0)}% ($received/$transmitted reçus)",
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 20),
        _buildPingChart(context),
        const SizedBox(height: 20),
        Text("Journal du ping:", style: theme.textTheme.bodyMedium),
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
                    "Réponse de ${data.response!.ip}: temps=${data.response!.time?.inMilliseconds}ms",
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontFamily: 'monospace'));
              } else if (data.error != null) {
                return Text("Erreur: ${data.error!.error.toString()}",
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
              child: Text("En attente de données de ping...",
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
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Copié dans le presse-papiers',
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
