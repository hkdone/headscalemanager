import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:dart_ping/dart_ping.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkOverviewScreen extends StatefulWidget {
  const NetworkOverviewScreen({super.key});

  @override
  State<NetworkOverviewScreen> createState() => _NetworkOverviewScreenState();
}

class PingResult {
  final bool isOnline;
  final double? averageLatency;

  PingResult({required this.isOnline, this.averageLatency});
}

class _NetworkOverviewScreenState extends State<NetworkOverviewScreen> {
  List<Node> _nodes = [];
  bool _isLoading = true;
  Node? _selectedNode;
  final Map<String, PingResult> _pingResults = {};
  final Map<String, StreamSubscription<PingData>> _pingSubscriptions = {};
  String? _publicIp;
  List<String> _traceRouteHops = [];
  bool _isTracingRoute = false;
  Node? _exitNodeInUse;
  int _traceRouteGeneration = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    // Incrémente la génération pour invalider les traceroutes précédents.
    _traceRouteGeneration++;
    final currentGeneration = _traceRouteGeneration;

    setState(() {
      _isLoading = true;
      _exitNodeInUse = null;
      _traceRouteHops.clear();
    });

    try {
      // Étape 1: Toujours récupérer les nœuds en premier.
      await _fetchNodes();

      // Si l'écran est toujours monté et que la génération est actuelle.
      if (mounted && _traceRouteGeneration == currentGeneration) {
        // Étape 2: Récupérer l'IP publique et ENSUITE lancer le traceroute.
        await _fetchPublicIpAndTrace(currentGeneration);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Erreur lors du rafraîchissement' : 'Refresh error'}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNodes() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final nodes = await appProvider.apiService.getNodes();
      if (!mounted) return;
      final selectedNodeId = _selectedNode?.id;
      setState(() {
        _nodes = nodes;
        if (selectedNodeId != null) {
          try {
            _selectedNode =
                _nodes.firstWhere((node) => node.id == selectedNodeId);
          } catch (e) {
            _selectedNode = _nodes.isNotEmpty ? _nodes.first : null;
          }
        } else {
          _selectedNode = _nodes.isNotEmpty ? _nodes.first : null;
        }
      });
      _startPinging();
    } catch (e) {
      if (!mounted) return;
      final locale = context.read<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${isFr ? 'Erreur lors de la récupération des nœuds' : 'Error fetching nodes'}: $e')),
      );
    }
  }

  Future<void> _fetchPublicIpAndTrace(int generation) async {
    try {
      final response =
          await http.get(Uri.parse('https://api.ipify.org?format=json'));
      if (response.statusCode == 200) {
        if (!mounted || _traceRouteGeneration != generation) return;
        setState(() {
          _publicIp = json.decode(response.body)['ip'];
        });
        // Le traceroute est lancé ici, après que _fetchNodes soit terminé.
        _startTraceRoute(generation);
      }
    } catch (e) {
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Erreur de récupération de l\'IP publique' : 'Error fetching public IP'}: $e')),
        );
      }
    }
  }

  void _startTraceRoute(int generation) async {
    // Si une autre actualisation a été lancée, on ne commence pas un nouveau traceroute.
    if (_traceRouteGeneration != generation) return;

    // La génération garantit qu'une seule trace est active et pertinente.

    // Log de débogage : Affiche toutes les IPs connues au début de la trace.
    final allKnownIps = _nodes.expand((node) => node.ipAddresses).toList();
    print('--- Début du Traceroute (Génération $generation) ---');
    print('IPs connues: $allKnownIps');

    setState(() {
      _isTracingRoute = true;
      // On s'assure de vider les données pour la nouvelle trace.
      _traceRouteHops.clear();
      _exitNodeInUse = null;
    });

    const String targetIp = '8.8.8.8'; // Google DNS

    for (int ttl = 1; ttl <= 30; ttl++) {
      // Vérifie à chaque itération si une nouvelle actualisation a été demandée.
      if (_traceRouteGeneration != generation || !mounted) break;

      final ping = Ping(targetIp, count: 1, ttl: ttl, timeout: 2);
      final completer = Completer<PingData?>();

      final StreamSubscription sub = ping.stream.listen((data) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
      });

      // Gère le cas où aucun paquet n'est reçu (timeout)
      Future.delayed(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      final PingData? data = await completer.future;
      sub.cancel(); // Annule l'abonnement pour éviter les fuites

      String hopIp = '*';
      if (data?.response?.ip != null) {
        hopIp = data!.response!.ip!;
        // Correction: La librairie de ping ajoute parfois un ':' à la fin de l'IP en mode traceroute.
        if (hopIp.endsWith(':')) {
          hopIp = hopIp.substring(0, hopIp.length - 1);
        }
      }

      // Log de débogage : Affiche chaque saut.
      print('Génération $generation - Saut $ttl: $hopIp');

      // N'applique les changements que si la génération est toujours valide.
      if (_traceRouteGeneration == generation && mounted) {
        setState(() {
          // Crée une nouvelle liste pour garantir la reconstruction du widget.
          _traceRouteHops = [..._traceRouteHops, hopIp];
          // Vérifie si le saut correspond à un exit node
          if (hopIp != '*') {
            try {
              // On cherche si le saut correspond à N'IMPORTE QUEL nœud du réseau.
              final gatewayNode = _nodes.firstWhere(
                (node) => node.ipAddresses.contains(hopIp),
              );
              _exitNodeInUse = gatewayNode;
            } catch (e) {
              // Pas un exit node, on continue
            }
          }
        });
      }

      // On s'arrête uniquement si on atteint la destination finale.
      // La détection d'un exit node ne doit pas interrompre le traceroute complet.
      if (hopIp == targetIp) {
        break;
      }
    }

    if (mounted && _traceRouteGeneration == generation) {
      print('--- Fin du Traceroute (Génération $generation) ---');
      setState(() {
        _isTracingRoute = false;
      });
    }
  }

  void _startPinging() {
    for (var sub in _pingSubscriptions.values) {
      sub.cancel();
    }
    _pingSubscriptions.clear();

    for (var node in _nodes) {
      if (node.ipAddresses.isNotEmpty) {
        final ip = node.ipAddresses.first;
        final ping = Ping(ip, count: 5, interval: 1);
        final responses = <PingResponse>[];

        _pingSubscriptions[node.id] = ping.stream.listen(
          (PingData data) {
            // On ne compte que les réponses valides (avec un temps de réponse) et sans erreur.
            if (data.response != null && data.error == null) {
              responses.add(data.response!);
            }
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              if (responses.isNotEmpty) {
                final totalTime = responses
                    .map((r) => r.time?.inMilliseconds ?? 0)
                    .reduce((a, b) => a + b);
                _pingResults[node.id] = PingResult(
                  isOnline: true,
                  averageLatency: totalTime / responses.length,
                );
              } else {
                _pingResults[node.id] = PingResult(isOnline: false);
              }
            });
          },
        );
      }
    }
  }

  @override
  void dispose() {
    for (var sub in _pingSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Vue d\'ensemble du réseau' : 'Network Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Exclut le nœud sélectionné de la liste à afficher pour le ping.
    final nodesToDisplay =
        _nodes.where((node) => node.id != _selectedNode?.id).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildNodeSelector(),
          _buildNetworkVisualizer(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nodesToDisplay.length,
            itemBuilder: (context, index) {
              final node = nodesToDisplay[index];
              final result = _pingResults[node.id];
              final isOnline = result?.isOnline ?? false;
              final latency = result?.averageLatency;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline ? Colors.green : Colors.red,
                  radius: 10,
                ),
                title: Text(node.name),
                subtitle: Text(node.ipAddresses.join(', ')),
                trailing: latency != null
                    ? Text('${latency.toStringAsFixed(2)} ms')
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkVisualizer() {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              isFr
                  ? 'Visualisation du chemin réseau'
                  : 'Network Path Visualization',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVisualizerNode(
                    context,
                    isFr ? 'Mon Appareil' : 'My Device',
                    Icons.phone_iphone,
                    _selectedNode?.name ?? (isFr ? 'N/A' : 'N/A')),
                if (_exitNodeInUse != null) ...[
                  Icon(Icons.arrow_forward,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                  _buildVisualizerNode(
                      context, 'Exit Node', Icons.router, _exitNodeInUse!.name),
                ],
                Icon(Icons.arrow_forward,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                _buildVisualizerNode(
                    context, 'Internet', Icons.cloud, _publicIp ?? '...'),
              ],
            ),
            if (_isTracingRoute) ...[
              const SizedBox(height: 10),
              CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary),
              Text(
                  isFr ? 'Traceroute en cours...' : 'Traceroute in progress...',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (_traceRouteHops.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                    isFr ? 'Détails du traceroute' : 'Traceroute Details',
                    style: Theme.of(context).textTheme.titleMedium),
                children: _traceRouteHops.map((hop) {
                  String nodeName = '';
                  try {
                    final node =
                        _nodes.firstWhere((n) => n.ipAddresses.contains(hop));
                    nodeName = ' (${node.name})';
                  } catch (e) {
                    // Ce n'est pas un nœud connu
                  }
                  return ListTile(
                    dense: true,
                    title: Text(
                        '${_traceRouteHops.indexOf(hop) + 1}: $hop$nodeName',
                        style: Theme.of(context).textTheme.bodyMedium),
                  );
                }).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizerNode(
      BuildContext context, String title, IconData icon, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildNodeSelector() {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButton<Node>(
        value: _selectedNode,
        hint: Text(isFr ? 'Sélectionnez un nœud' : 'Select a node',
            style: Theme.of(context).textTheme.bodyMedium),
        isExpanded: true,
        onChanged: (Node? newValue) {
          setState(() {
            _selectedNode = newValue;
          });
        },
        items: _nodes.map<DropdownMenuItem<Node>>((Node node) {
          return DropdownMenuItem<Node>(
            value: node,
            child:
                Text(node.name, style: Theme.of(context).textTheme.bodyMedium),
          );
        }).toList(),
      ),
    );
  }
}
