import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:share_plus/share_plus.dart';

class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});

  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  List<Node> _nodes = [];
  List<Node> _filteredNodes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final apiService = Provider.of<AppProvider>(context, listen: false).apiService;
      final nodes = await apiService.getNodes();
      if (mounted) {
        setState(() {
          _nodes = nodes;
          _filteredNodes = nodes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFr ? 'Erreur lors de la récupération' : 'Error fetching data'}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _filterNodes(String query) {
    setState(() {
      _searchQuery = query;
      if (_searchQuery.isEmpty) {
        _filteredNodes = _nodes;
      } else {
        _filteredNodes = _nodes.where((node) {
          final queryLower = query.toLowerCase();
          return node.name.toLowerCase().contains(queryLower) ||
                 node.fqdn.toLowerCase().contains(queryLower) ||
                 node.ipAddresses.any((ip) => ip.contains(queryLower));
        }).toList();
      }
    });
  }
  
  String _getIpv4(Node node) => node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  String _getIpv6(Node node) => node.ipAddresses.firstWhere((ip) => ip.contains(':'), orElse: () => '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Vue DNS' : 'DNS View'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: isFr ? 'Rechercher par nom, FQDN ou IP' : 'Search by name, FQDN, or IP',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                      onChanged: _filterNodes,
                    ),
                  ),
                  Expanded(
                    child: _filteredNodes.isEmpty && !_isLoading
                        ? Center(child: Text(isFr ? 'Aucun nœud trouvé' : 'No nodes found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filteredNodes.length,
                            itemBuilder: (context, index) {
                              final node = _filteredNodes[index];
                              final ipv4 = _getIpv4(node);
                              final ipv6 = _getIpv6(node);

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                color: theme.cardColor,
                                child: ListTile(
                                  isThreeLine: true,
                                  title: Text(node.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Text(node.fqdn, style: const TextStyle(fontFamily: 'monospace')),
                                       const SizedBox(height: 8),
                                       Wrap(
                                        spacing: 8.0,
                                        runSpacing: 8.0,
                                        children: [
                                          _buildActionButton(context, isFr, 'DNS', node.fqdn),
                                          if (ipv4.isNotEmpty) _buildActionButton(context, isFr, 'IPv4', ipv4),
                                          if (ipv6.isNotEmpty) _buildActionButton(context, isFr, 'IPv6', ipv6),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  _buildHelpCard(context, isFr),
                ],
              ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool isFr, String label, String value) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      onSelected: (choice) {
        if (choice == 'copy') {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label ${isFr ? 'copié' : 'copied'}!')));
        } else if (choice == 'share') {
          Share.share(value);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'copy',
          child: ListTile(
            leading: const Icon(Icons.copy),
            title: Text(isFr ? 'Copier' : 'Copy'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
            leading: const Icon(Icons.share),
            title: Text(isFr ? 'Partager' : 'Share'),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, bool isFr) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      color: Theme.of(context).cardColor,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFr ? "Noms DNS Personnalisés" : "Custom DNS Names",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isFr
                  ? "Pour assigner un nom DNS à un service sur votre réseau local (ex: nas.votre.domaine pointant vers 192.168.1.100), vous devez modifier la section 'dns_config.extra_records' dans votre fichier config.yaml sur le serveur Headscale et redémarrer le service. Cette action ne peut pas être effectuée depuis l'application."
                  : "To assign a DNS name to a service on your local network (e.g., nas.your.domain pointing to 192.168.1.100), you must edit the 'dns_config.extra_records' section in your config.yaml file on the Headscale server and restart the service. This action cannot be performed from the application.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
