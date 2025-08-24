import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;
const Color _accentColor = Colors.blue;
const Color _cardBackgroundColor = Colors.white;

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
    return widget.node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  }

  String get _ipv6 {
     return widget.node.ipAddresses.firstWhere((ip) => ip.contains(':'), orElse: () => '');
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
          const SnackBar(content: Text('Aucune adresse IPv4 trouvée pour ce nœud.')),
        );
        return;
      }

      final ping = Ping(_ipv4, count: 10000); // Effectively continuous
      _pingSubscription = ping.stream.listen((event) {
        if(mounted) setState(() => _pingResponses.add(event));
      }, onDone: () {
        if(mounted) setState(() => _isPingingContinuously = false);
      });
    } else {
      _pingSubscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(widget.node.name, style: const TextStyle(color: _primaryTextColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMainInfoCard(),
          const SizedBox(height: 16),
          _buildIpAddressesCard(),
          const SizedBox(height: 16),
          _buildIdentifiersCard(),
          const SizedBox(height: 16),
          _buildTagsAndRoutesCard(),
          const SizedBox(height: 16),
          _buildPingCard(),
        ],
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: widget.node.online ? Colors.green : Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(widget.node.online ? 'En ligne' : 'Hors ligne', style: TextStyle(color: widget.node.online ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.node.isExitNode)
                const Chip(label: Text('Exit Node'), backgroundColor: _accentColor, labelStyle: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.node.hostname, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryTextColor)),
          const SizedBox(height: 4),
          Text('Utilisateur: ${widget.node.user}', style: const TextStyle(color: _secondaryTextColor, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Dernière connexion: ${widget.node.lastSeen.toLocal()}', style: const TextStyle(color: _secondaryTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildIpAddressesCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Adresses IP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)),
          const Divider(height: 20),
          if (_ipv4.isNotEmpty) _DetailRowWithCopy(label: 'IPv4', value: _ipv4),
          if (_ipv6.isNotEmpty) _DetailRowWithCopy(label: 'IPv6', value: _ipv6),
        ],
      ),
    );
  }

  Widget _buildIdentifiersCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Identifiants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)),
          const Divider(height: 20),
          _DetailRowWithCopy(label: 'ID Nœud', value: widget.node.id),
          _DetailRowWithCopy(label: 'Clé Machine', value: widget.node.machineKey),
          _DetailRowWithCopy(label: 'FQDN', value: widget.node.fqdn),
        ],
      ),
    );
  }

  Widget _buildTagsAndRoutesCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tags & Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)),
          const Divider(height: 20),
          const Text('Tags:', style: TextStyle(fontWeight: FontWeight.bold, color: _secondaryTextColor)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: widget.node.tags.isEmpty
                ? [const Text('Aucun tag', style: TextStyle(color: _secondaryTextColor))]
                : widget.node.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Routes partagées:', style: TextStyle(fontWeight: FontWeight.bold, color: _secondaryTextColor)),
          const SizedBox(height: 8),
           widget.node.sharedRoutes.isEmpty
              ? const Text('Aucune', style: TextStyle(color: _secondaryTextColor))
              : Text(widget.node.sharedRoutes.join(', '), style: const TextStyle(color: _primaryTextColor)),
        ],
      ),
    );
  }

  Widget _buildPingCard() {
    return Card(
      elevation: 0,
      color: _cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: const Text('Outils de diagnostic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text("Ping en continu"),
                    const Spacer(),
                    Switch(
                      value: _isPingingContinuously,
                      onChanged: _toggleContinuousPing,
                      activeColor: _accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isPingingContinuously) _buildContinuousPingResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousPingResults() {
    if (_pingResponses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final responses = _pingResponses.where((e) => e.response != null).map((e) => e.response!).toList();
    final transmitted = _pingResponses.length;
    final received = responses.length;
    final loss = transmitted > 0 ? (1 - received / transmitted) * 100 : 0;

    final latencies = responses.where((e) => e.time != null).map((e) => e.time!.inMilliseconds).toList();
    final avgLatency = latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Latence moyenne: ${avgLatency.toStringAsFixed(2)} ms", style: const TextStyle(color: _primaryTextColor)),
        Text("Paquets perdus: ${loss.toStringAsFixed(0)}% ($received/$transmitted reçus)", style: const TextStyle(color: _primaryTextColor)),
        const SizedBox(height: 10),
        const Text("Journal du ping:"),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: _backgroundColor,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            reverse: true,
            itemCount: _pingResponses.length,
            itemBuilder: (context, index) {
              final data = _pingResponses.reversed.toList()[index];
              if (data.response != null) {
                return Text("Réponse de ${data.response!.ip}: temps=${data.response!.time?.inMilliseconds}ms", style: const TextStyle(fontFamily: 'monospace', fontSize: 12));
              } else if (data.error != null) {
                return Text("Erreur: ${data.error!.error.toString()}", style: const TextStyle(color: Colors.red, fontFamily: 'monospace', fontSize: 12));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
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
      color: _cardBackgroundColor,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _secondaryTextColor)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(color: _primaryTextColor, fontFamily: 'monospace')),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
            tooltip: 'Copier',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copié dans le presse-papiers')),
              );
            },
          ),
        ],
      ),
    );
  }
}