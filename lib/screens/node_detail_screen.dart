import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/widgets/cli_command_display_dialog.dart';
import 'package:headscalemanager/widgets/edit_tags_dialog.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';

/// Écran affichant les détails d'un nœud Headscale spécifique.
///
/// Permet de visualiser les informations du nœud et de gérer ses tags.
class NodeDetailScreen extends StatefulWidget {
  /// Le nœud dont les détails doivent être affichés.
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  /// Liste des tags actuels du nœud.
  late List<String> _currentTags;
  bool _isPinging = false;
  PingSummary? _pingSummary;
  bool _isPingingContinuously = false;
  StreamSubscription<PingData>? _pingSubscription;
  final List<PingData> _pingResponses = [];

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.node.tags);
  }

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  /// Lance un ping sur l'adresse IPv4 du nœud.
  void _pingNode() async {
    setState(() {
      _isPinging = true;
      _pingSummary = null;
    });

    final ipv4 = widget.node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
    if (ipv4.isEmpty) {
      setState(() {
        _isPinging = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune adresse IPv4 trouvée pour ce nœud.')),
      );
      return;
    }

    final ping = Ping(ipv4, count: 5);
    final completer = Completer<PingSummary?>();

    final subscription = ping.stream.listen((event) {
      if (event.summary != null) {
        if (!completer.isCompleted) {
          completer.complete(event.summary);
        }
      }
    });

    final summary = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      return null;
    });

    subscription.cancel();

    setState(() {
      _isPinging = false;
      _pingSummary = summary;
    });
  }

  void _toggleContinuousPing(bool value) {
    setState(() {
      _isPingingContinuously = value;
      _pingSummary = null; // Clear previous results
      _pingResponses.clear();
    });

    if (_isPingingContinuously) {
      final ipv4 = widget.node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
      if (ipv4.isEmpty) {
        setState(() {
          _isPingingContinuously = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune adresse IPv4 trouvée pour ce nœud.')),
        );
        return;
      }

      final ping = Ping(ipv4, count: 10000); // Effectively continuous
      _pingSubscription = ping.stream.listen((event) {
        setState(() {
          _pingResponses.add(event);
        });
      }, onDone: () {
        setState(() {
          _isPingingContinuously = false;
        });
      });
    } else {
      _pingSubscription?.cancel();
    }
  }


  /// Affiche un dialogue pour modifier les tags du nœud.
  ///
  /// Le dialogue permet à l'utilisateur de saisir de nouveaux tags et génère
  /// une commande CLI correspondante. Cette commande doit être exécutée
  /// manuellement par l'utilisateur.
  void _showEditTagsFlow() async {
    final String? generatedCommand = await showDialog<String>( // Await the dialog dismissal and get returned value
      context: context,
      builder: (context) => EditTagsDialog(
        node: widget.node,
      ),
    );

    if (generatedCommand != null && generatedCommand.isNotEmpty) {
      // Affiche le dialogue de commande CLI après la génération.
      showDialog(
        context: context,
        builder: (ctx) => CliCommandDisplayDialog(command: generatedCommand),
      );
      // Affiche un SnackBar pour informer l'utilisateur.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Commande CLI générée. Exécutez-la et actualisez la page pour voir les changements.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node.name),
        actions: [
          // Bouton pour modifier les tags du nœud.
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier les tags',
            onPressed: _showEditTagsFlow,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Affichage des différentes propriétés du nœud.
            _buildDetailRow('Nom : ', widget.node.name),
            _buildDetailRow('Hostname : ', widget.node.hostname),
            _buildDetailRow('Nom de domaine complet (FQDN) : ', widget.node.fqdn),
            _buildDetailRow('ID : ', widget.node.id),
            _buildDetailRow('Clé machine : ', widget.node.machineKey),
            _buildDetailRow('Utilisateur : ', widget.node.user),
            _buildDetailRow('En ligne : ', widget.node.online ? 'Oui' : 'Non'),
            _buildDetailRow(
                'Dernière connexion : ', widget.node.lastSeen.toLocal().toString()),
            _buildDetailRow(
                'Adresses IP : ', widget.node.ipAddresses.join(', ')),
            _buildDetailRow(
                'Routes annoncées : ',
                widget.node.advertisedRoutes.isEmpty
                    ? 'Aucune'
                    : widget.node.advertisedRoutes.join(', ')),
            _buildDetailRow('Tags : ',
                _currentTags.isEmpty ? 'Aucun' : _currentTags.join(', ')),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isPingingContinuously ? null : _pingNode,
                  icon: const Icon(Icons.network_ping),
                  label: const Text('Ping'),
                ),
                const SizedBox(width: 16),
                if (_isPinging && !_isPingingContinuously)
                  const CircularProgressIndicator()
                else if (_pingSummary != null && !_isPingingContinuously)
                  _buildPingResults(_pingSummary!)
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text("Ping en continu"),
                Switch(
                  value: _isPingingContinuously,
                  onChanged: _toggleContinuousPing,
                ),
              ],
            ),
            if (_isPingingContinuously)
              _buildContinuousPingResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildPingResults(PingSummary summary) {
    final received = summary.received;
    final transmitted = summary.transmitted;
    final time = summary.time;

    if (received == 0) {
      return const Row(
        children: [
          Icon(Icons.cancel, color: Colors.red),
          SizedBox(width: 8),
          Text("Échec du Ping", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
    }

    final loss = transmitted > 0 ? (1 - received / transmitted) * 100 : 0;
    final avgLatency = time != null && received > 0 ? (time.inMicroseconds / 1000 / received) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text("Succès", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        SizedBox(height: 8),
        Text("Latence moyenne: ${avgLatency.toStringAsFixed(2)} ms"),
        Text("Paquets perdus: ${loss.toStringAsFixed(0)}% ($received/$transmitted reçus)"),
      ],
    );
  }

  Widget _buildContinuousPingResults() {
    if (_pingResponses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final responses = _pingResponses.where((e) => e.response != null).map((e) => e.response!).toList();
    final errors = _pingResponses.where((e) => e.error != null).toList();
    final transmitted = _pingResponses.length;
    final received = responses.length;
    final loss = transmitted > 0 ? (1 - received / transmitted) * 100 : 0;

    final latencies = responses.where((e) => e.time != null).map((e) => e.time!.inMilliseconds).toList();
    final avgLatency = latencies.isNotEmpty ? latencies.reduce((a, b) => a + b) / latencies.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Statistiques en direct :", style: Theme.of(context).textTheme.titleMedium),
        Text("Latence moyenne: ${avgLatency.toStringAsFixed(2)} ms"),
        Text("Paquets perdus: ${loss.toStringAsFixed(0)}% ($received/$transmitted reçus)"),
        const SizedBox(height: 10),
        Text("Journal du ping :", style: Theme.of(context).textTheme.titleMedium),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            reverse: true,
            itemCount: _pingResponses.length,
            itemBuilder: (context, index) {
              final data = _pingResponses.reversed.toList()[index];
              if (data.response != null) {
                return Text("  Réponse de ${data.response!.ip}: temps=${data.response!.time?.inMilliseconds}ms");
              } else if (data.error != null) {
                return Text("  Erreur: ${data.error!.error.toString()}", style: TextStyle(color: Colors.red));
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  /// Construit une ligne pour afficher un détail du nœud (libellé et valeur).
  ///
  /// [label] : Le libellé du détail (ex: "Nom :").
  /// [value] : La valeur du détail.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Largeur ajustée pour un meilleur affichage du libellé.
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value), // Texte sélectionnable pour faciliter la copie.
          ),
          if (label == 'Nom de domaine complet (FQDN) : ')
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copier le FQDN',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('FQDN copié dans le presse-papiers.'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
