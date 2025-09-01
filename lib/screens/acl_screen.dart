import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/acl_generator_service.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _accentColor = Colors.blue;

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
    setState(() => _isLoading = true);
    await _fetchNodes();
    final storage = context.read<AppProvider>().storageService;
    final loadedRules = await storage.getTemporaryRules();
    setState(() {
      _temporaryRules.addAll(loadedRules);
    });
    await _generateAclPolicy(showSnackbar: false);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
    } catch (e) {
      debugPrint('Error fetching nodes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch nodes: $e')),
        );
      }
    }
  }

  void _updateAclControllerText() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(_currentAclPolicy);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Gestion des ACLs', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
        actions: [
          _buildActionsMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    _buildTemporaryRulesSection(),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aclController,
                      maxLines: 20, // Donne une bonne taille de départ
                      minLines: 5,  // Et une taille minimale
                      decoration: _buildInputDecoration('Politique ACL', '').copyWith(filled: true, fillColor: Colors.white),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generateAclPolicy(showSnackbar: true),
        label: const Text('Générer la politique'),
        icon: const Icon(Icons.settings_backup_restore),
        backgroundColor: _accentColor,
      ),
    );
  }

  PopupMenuButton<String> _buildActionsMenu() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'export':
            _exportAclPolicyToServer();
            break;
          case 'fetch':
            _fetchAclPolicyFromServer();
            break;
          case 'share':
            _shareAclFile();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'export',
          child: ListTile(leading: Icon(Icons.cloud_upload), title: Text('Exporter vers le serveur')),
        ),
        const PopupMenuItem<String>(
          value: 'fetch',
          child: ListTile(leading: Icon(Icons.cloud_download), title: Text('Récupérer du serveur')),
        ),
        const PopupMenuItem<String>(
          value: 'share',
          child: ListTile(leading: Icon(Icons.share), title: Text('Partager en fichier')),
        ),
      ],
    );
  }

  Widget _buildTemporaryRulesSection() {
    final sourceUser = _selectedSourceNode?.user;
    List<Node> destinationNodes = _allNodes;
    if (sourceUser != null) {
      destinationNodes = _allNodes.where((node) => node.user != sourceUser).toList();
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autorisations Spécifiques', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: _primaryTextColor, fontSize: 20)),
            const SizedBox(height: 8),
            const Text(
              'Créez ici des exceptions pour autoriser la communication entre les appareils de différents utilisateurs.',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNodeDropdown(
                    'Source',
                    _selectedSourceNode,
                    _allNodes,
                    (node) {
                      setState(() {
                        _selectedSourceNode = node;
                        // Si le nouveau nœud source a le même utilisateur que la destination, réinitialiser la destination.
                        if (node != null && _selectedDestinationNode != null && node.user == _selectedDestinationNode!.user) {
                          _selectedDestinationNode = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNodeDropdown(
                    'Destination',
                    _selectedDestinationNode,
                    destinationNodes,
                    (node) => setState(() => _selectedDestinationNode = node),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addTemporaryRule,
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: const Text('Ajouter et Appliquer', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Règles actives:', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _primaryTextColor)),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.grey),
                  tooltip: 'Effacer toutes les règles',
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
                  backgroundColor: _accentColor.withAlpha(25),
                  deleteIconColor: _accentColor,
                  labelStyle: const TextStyle(color: _accentColor),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(String label, Node? selectedNode, List<Node> nodes, ValueChanged<Node?> onChanged) {
    return DropdownButtonFormField<Node>(
      value: selectedNode,
      decoration: _buildInputDecoration(label, 'Choisir un nœud'),
      items: nodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _backgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addTemporaryRule() async {
    if (_temporaryRules.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous ne pouvez ajouter qu\'une seule autorisation à la fois.')));
      return;
    }

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

    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(message: 'Règle ajoutée et politique appliquée avec succès.');
  }

  Future<void> _removeTemporaryRule(int index) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Cela va supprimer la règle et appliquer immédiatement la nouvelle politique au serveur. Continuer ?'),
        actions: [
          TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Confirmer', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.removeAt(index);
    });

    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(message: 'Règle supprimée et politique mise à jour.');
  }

  Future<void> _clearTemporaryRules() async {
     final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Cela va supprimer TOUTES les règles et appliquer la nouvelle politique au serveur. Continuer ?'),
        actions: [
          TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Confirmer', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ) ?? false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.clear();
    });
    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(message: 'Toutes les règles ont été supprimées et la politique a été mise à jour.');
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    await _generateAclPolicy(showSnackbar: false);
    await _exportAclPolicyToServer(showConfirmation: false, successMessage: message);
  }

  Future<void> _exportAclPolicyToServer({bool showConfirmation = true, String? successMessage}) async {
    if (showConfirmation) {
      final bool confirm = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmer l\'exportation'),
            content: const Text(
                'Vous allez appliquer la politique ACL définie dans le champ de texte sur votre serveur. Êtes-vous sûr ?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirmer', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ) ?? false;

      if (!confirm) return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      await apiService.setAclPolicy(_aclController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage ?? 'Politique ACL exportée avec succès vers le serveur.')),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'exportation de la politique ACL : $e')),
        );
      }
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
      // On ne vide plus les règles temporaires, on les garde
      _updateAclControllerText();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Politique ACL récupérée du serveur.')),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la politique ACL du serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la récupération de la politique ACL : $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAclPolicy({bool showSnackbar = true}) async {
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
        temporaryRules: _temporaryRules,
      );

      _updateAclControllerText();

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Politique ACL générée dans le champ de texte.'),
                SizedBox(height: 4),
                Text('Utilisez le menu (⋮) pour l\'exporter.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la génération de la politique ACL : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la génération de la politique ACL : $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du partage du fichier ACL : $e')),
        );
      }
    }
  }
}
