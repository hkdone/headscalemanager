import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:headscalemanager/services/acl_generator_service.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {};
  final AclGeneratorService _aclGeneratorService = AclGeneratorService();

  // State for temporary rules UI
  List<Node> _allNodes = [];
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final List<Map<String, String>> _temporaryRules = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _loadAcl();
    await _fetchNodes();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
    } catch (e) {
      debugPrint('Error fetching nodes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch nodes: $e')),
      );
    }
  }

  void _updateAclControllerText() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(_currentAclPolicy);
    setState(() {});
  }

  void _loadAcl() {
    _currentAclPolicy = {
      'acls': [],
      'groups': {},
      'tagOwners': {},
      'autoApprovers': {'routes': <String, List<String>>{}, 'exitNodes': <String>[]},
      'tests': [],
      'hosts': {},
    };
    _updateAclControllerText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildTemporaryRulesSection(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _aclController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Politique ACL',
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children:
         [
          FloatingActionButton(
            onPressed: _shareAclFile,
            heroTag: 'shareAclFile',
            tooltip: 'Partager le fichier ACL',
            child: const Icon(Icons.share),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _generateAclPolicy,
            heroTag: 'generateAcl',
            tooltip: 'Générer la politique ACL',
            child: const Icon(Icons.settings_backup_restore),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _fetchAclPolicyFromServer,
            heroTag: 'fetchAclFromServer',
            tooltip: 'Récupérer la politique ACL du serveur',
            child: const Icon(Icons.cloud_download),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _exportAclPolicyToServer,
            heroTag: 'exportAclToServer',
            tooltip: 'Exporter la politique ACL vers le serveur',
            child: const Icon(Icons.cloud_upload),
          ),
        ],
      ),
    );
  }

  Widget _buildTemporaryRulesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autorisations Temporaires', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildNodeDropdown('Source', _selectedSourceNode, (node) => setState(() => _selectedSourceNode = node))),
                const SizedBox(width: 10),
                Expanded(child: _buildNodeDropdown('Destination', _selectedDestinationNode, (node) => setState(() => _selectedDestinationNode = node))),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addTemporaryRule,
                icon: const Icon(Icons.add_link),
                label: const Text('Ajouter la règle'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Règles actives:', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Effacer toutes les règles temporaires',
                  onPressed: _clearTemporaryRules,
                )
              ],
            ),
            Wrap(
              spacing: 8.0,
              children: _temporaryRules.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, String> rule = entry.value;
                return Chip(
                  label: Text('${rule['src']} <-> ${rule['dst']}'),
                  onDeleted: () => _removeTemporaryRule(idx),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(String label, Node? selectedNode, ValueChanged<Node?> onChanged) {
    return DropdownButtonFormField<Node>(
      value: selectedNode,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: _allNodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  void _addTemporaryRule() {
    if (_selectedSourceNode == null || _selectedDestinationNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un nœud source et un nœud destination.')));
      return;
    }
    if (_selectedSourceNode!.id == _selectedDestinationNode!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La source et la destination ne peuvent pas être identiques.')));
      return;
    }
    if (_selectedSourceNode!.tags.isEmpty || _selectedDestinationNode!.tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les deux nœuds doivent avoir au moins un tag.')));
      return;
    }

    final newRule = {
      'src': _selectedSourceNode!.tags.first,
      'dst': _selectedDestinationNode!.tags.first,
    };

    bool ruleExists = _temporaryRules.any((rule) => 
        (rule['src'] == newRule['src'] && rule['dst'] == newRule['dst']) ||
        (rule['src'] == newRule['dst'] && rule['dst'] == newRule['src']));

    if (ruleExists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cette règle existe déjà.')));
      return;
    }

    setState(() {
      _temporaryRules.add(newRule);
    });
  }

  void _removeTemporaryRule(int index) {
    setState(() {
      _temporaryRules.removeAt(index);
    });
  }

  void _clearTemporaryRules() {
    setState(() {
      _temporaryRules.clear();
    });
  }

  Future<void> _exportAclPolicyToServer() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer l\'exportation manuelle'),
          content: const Text(
              'Vous allez exporter le contenu du champ de texte vers le serveur. Assurez-vous que le JSON est valide. Continuer ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      final aclMap = json.decode(_aclController.text);
      await apiService.setAclPolicy(aclMap);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL exportée avec succès vers le serveur.')),
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'exportation de la politique ACL : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAclPolicyFromServer() async {
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      final aclJsonString = await apiService.getAclPolicy();
      _currentAclPolicy = json.decode(aclJsonString);
      _temporaryRules.clear(); // Clear local rules when fetching from server
      _updateAclControllerText();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL récupérée du serveur.')),
      );
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la politique ACL du serveur : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la récupération de la politique ACL : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAclPolicy() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      final users = await apiService.getUsers();
      final nodes = _allNodes.isNotEmpty ? _allNodes : await apiService.getNodes();
      if (_allNodes.isEmpty) _allNodes = nodes;

      _currentAclPolicy = _aclGeneratorService.generateAclPolicy(
        users: users,
        nodes: nodes,
        temporaryRules: _temporaryRules, // Pass temporary rules to the service
      );

      _updateAclControllerText();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL générée dans le champ de texte.')),
      );
    } catch (e) {
      debugPrint('Erreur lors de la génération de la politique ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération de la politique ACL : $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareAclFile() async {
    try {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String aclJsonString = encoder.convert(_currentAclPolicy);

      if (aclJsonString.isEmpty || aclJsonString == encoder.convert({})) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le contenu ACL est vide. Générez d\'abord une politique.')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl.json');
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Voici votre politique ACL Headscale.');
    } catch (e) {
      debugPrint('Erreur lors du partage du fichier ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du partage du fichier ACL : $e')),
      );
    }
  }
}
