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
  bool _isHelpCardExpanded = false;
  Map<String, String> _customDnsRecords = {}; // nodeId -> alias

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final apiService = appProvider.apiService;
      final serverId = appProvider.activeServer?.id;

      final nodes = await apiService.getNodes();

      Map<String, String> customRecords = {};
      if (serverId != null) {
        customRecords =
            await appProvider.storageService.getCustomDnsRecords(serverId);
      }

      if (mounted) {
        setState(() {
          _nodes = nodes;
          _filteredNodes = _applyFilter(nodes, _searchQuery);
          _isLoading = false;
          _customDnsRecords = customRecords;
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
            content: Text(
                '${isFr ? 'Erreur lors de la récupération' : 'Error fetching data'}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<Node> _applyFilter(List<Node> nodes, String query) {
    if (query.isEmpty) return nodes;
    final queryLower = query.toLowerCase();
    return nodes.where((node) {
      final customAlias = _customDnsRecords[node.id]?.toLowerCase() ?? '';
      return node.name.toLowerCase().contains(queryLower) ||
          node.fqdn.toLowerCase().contains(queryLower) ||
          customAlias.contains(queryLower) ||
          node.ipAddresses.any((ip) => ip.contains(queryLower));
    }).toList();
  }

  void _filterNodes(String query) {
    setState(() {
      _searchQuery = query;
      _filteredNodes = _applyFilter(_nodes, query);
    });
  }

  Future<void> _saveCustomRecord(String nodeId, String alias) async {
    final appProvider = context.read<AppProvider>();
    final serverId = appProvider.activeServer?.id;
    if (serverId == null) return;

    if (alias.trim().isEmpty) {
      _customDnsRecords.remove(nodeId);
    } else {
      _customDnsRecords[nodeId] = alias.trim();
    }

    await appProvider.storageService
        .saveCustomDnsRecords(serverId, _customDnsRecords);
    _filterNodes(_searchQuery); // Re-apply filter to update view
  }

  String _getIpv4(Node node) =>
      node.ipAddresses.firstWhere((ip) => !ip.contains(':'), orElse: () => '');
  String _getIpv6(Node node) =>
      node.ipAddresses.firstWhere((ip) => ip.contains(':'), orElse: () => '');

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
        child: Column(
          children: [
            _buildWarningBanner(context, isFr),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: isFr
                      ? 'Rechercher par nom, FQDN, alias ou IP'
                      : 'Search by name, FQDN, alias, or IP',
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNodes.isEmpty
                      ? Center(
                          child: Text(
                              isFr ? 'Aucun nœud trouvé' : 'No nodes found'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredNodes.length,
                          itemBuilder: (context, index) {
                            final node = _filteredNodes[index];
                            final ipv4 = _getIpv4(node);
                            final ipv6 = _getIpv6(node);
                            final customAlias = _customDnsRecords[node.id];

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              color: theme.cardColor,
                              child: ListTile(
                                isThreeLine: true,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(node.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    if (customAlias != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: theme
                                                .colorScheme.tertiaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Row(
                                          children: [
                                            Icon(Icons.bookmark,
                                                size: 12,
                                                color: theme.colorScheme
                                                    .onTertiaryContainer),
                                            const SizedBox(width: 4),
                                            Text(
                                              customAlias,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                      color: theme.colorScheme
                                                          .onTertiaryContainer,
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(node.fqdn,
                                        style: const TextStyle(
                                            fontFamily: 'monospace')),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _buildActionButton(
                                            context, isFr, 'DNS', node.fqdn),
                                        if (ipv4.isNotEmpty)
                                          _buildActionButton(
                                              context, isFr, 'IPv4', ipv4),
                                        if (ipv6.isNotEmpty)
                                          _buildActionButton(
                                              context, isFr, 'IPv6', ipv6),
                                        IconButton(
                                            onPressed: () =>
                                                _showEditAliasDialog(
                                                    context, node, customAlias),
                                            tooltip: isFr
                                                ? 'Ajouter/Modifier un alias DNS (Mémo local)'
                                                : 'Add/Edit DNS Alias (Local Memo)',
                                            icon: Icon(Icons.edit_note,
                                                color:
                                                    theme.colorScheme.primary)),
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

  Widget _buildWarningBanner(BuildContext context, bool isFr) {
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.2),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isFr
                  ? "Les noms affichés sont estimés. Les configurations serveur (MagicDNS/Extra Records) ne sont pas visibles ici mais fonctionnent correctement."
                  : "Displayed names are estimated. Server-side custom MagicDNS/Extra Records are not visible here but work correctly.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAliasDialog(
      BuildContext context, Node node, String? currentAlias) {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    final controller = TextEditingController(text: currentAlias);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFr ? 'Alias DNS (Mémo Local)' : 'DNS Alias (Local Memo)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFr
                  ? "Cet alias est uniquement sauvegardé localement sur cet appareil pour votre référence. Assurez-vous d'ajouter cet enregistrement dans le fichier 'config.yaml' de votre serveur Headscale pour qu'il soit effectif sur le réseau."
                  : "This alias is only saved locally on this device for your reference. Make sure to add this record to your Headscale server's 'config.yaml' for it to work on the network.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: isFr ? 'Nom DNS personnalisé' : 'Custom DNS Name',
                hintText: 'ex: nas.home',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveCustomRecord(node.id, controller.text);
              Navigator.pop(context);
            },
            child: Text(isFr ? 'Sauvegarder' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, bool isFr, String label, String value) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      onSelected: (choice) {
        if (choice == 'copy') {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label ${isFr ? 'copié' : 'copied'}!')));
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
          style: TextStyle(
              color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, bool isFr) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ExpansionTile(
        initiallyExpanded: _isHelpCardExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _isHelpCardExpanded = expanded;
          });
        },
        title: Text(
          isFr ? "Noms DNS Personnalisés" : "Custom DNS Names",
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: theme.dividerColor),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(color: theme.dividerColor),
        ),
        backgroundColor: theme.cardColor,
        collapsedBackgroundColor: theme.cardColor,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              isFr
                  ? "Pour assigner un nom DNS à un service sur votre réseau local (ex: nas.votre.domaine pointant vers 192.168.1.100), vous devez modifier la section 'dns_config.extra_records' dans votre fichier config.yaml sur le serveur Headscale et redémarrer le service. Cette action ne peut pas être effectuée depuis l'application."
                  : "To assign a DNS name to a service on your local network (e.g., nas.your.domain pointing to 192.168.1.100), you must edit the 'dns_config.extra_records' section in your config.yaml file on the Headscale server and restart the service. This action cannot be performed from the application.",
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
