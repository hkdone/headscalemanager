import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {};
  final NewAclGeneratorService _newAclGeneratorService =
      NewAclGeneratorService();

  List<Node> _allNodes = [];
  List<String> _allTags = [];
  String? _selectedSourceTag;
  String? _selectedDestinationTag;
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
    await _generateNewAclPolicy(showSnackbar: false);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
      final Set<String> tags = {};
      for (var node in _allNodes) {
        tags.addAll(node.tags);
      }
      _allTags = tags.toList()..sort();
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Gestion des ACLs',
            style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
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
                      minLines: 5, // Et une taille minimale
                      decoration: _buildInputDecoration('Politique ACL', '')
                          .copyWith(
                              filled: true,
                              fillColor: Theme.of(context).cardColor),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _generateNewAclPolicy(showSnackbar: true),
        label: const Text('Générer la Politique'),
        icon: const Icon(Icons.settings_backup_restore),
        backgroundColor: Theme.of(context).colorScheme.primary,
        heroTag: 'generate_policy_fab',
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
          case 'reset':
            _resetAclPolicy();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'export',
          child: ListTile(
              leading: Icon(Icons.cloud_upload),
              title: Text('Exporter vers le serveur')),
        ),
        const PopupMenuItem<String>(
          value: 'fetch',
          child: ListTile(
              leading: Icon(Icons.cloud_download),
              title: Text('Récupérer du serveur')),
        ),
        const PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
              leading: Icon(Icons.share), title: Text('Partager en fichier')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'reset',
          child: ListTile(
            leading: Icon(Icons.lock_open, color: Colors.orange),
            title: Text('Autoriser tout (Réinitialiser)',
                style: TextStyle(color: Colors.orange)),
          ),
        ),
      ],
    );
  }

  Widget _buildTemporaryRulesSection() {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Autorisations Spécifiques',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'Créez ici des exceptions pour autoriser la communication entre les appareils de différents utilisateurs.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTagDropdown(
                    'Source (Tag)',
                    _selectedSourceTag,
                    _allTags,
                    (tag) {
                      setState(() {
                        _selectedSourceTag = tag;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTagDropdown(
                    'Destination (Tag)',
                    _selectedDestinationTag,
                    _allTags, // Using _allTags for destination as well for simplicity
                    (tag) => setState(() => _selectedDestinationTag = tag),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addTemporaryRule,
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: const Text('Ajouter et Appliquer',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Règles actives:',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.delete_sweep,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
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
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withAlpha(25),
                  deleteIconColor: Theme.of(context).colorScheme.primary,
                  labelStyle:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<String> _buildTagDropdown(String label,
      String? selectedTag, List<String> tags, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: selectedTag,
      decoration: _buildInputDecoration(label, 'Choisir un tag'),
      items: tags.map((String tag) {
        return DropdownMenuItem<String>(
          value: tag,
          child: Text(tag, overflow: TextOverflow.ellipsis),
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
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addTemporaryRule() async {
    if (_selectedSourceTag == null || _selectedDestinationTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Veuillez sélectionner un tag source et un tag destination.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    if (_selectedSourceTag == _selectedDestinationTag) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Le tag source et le tag destination ne peuvent pas être identiques.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    final newRule = {
      'src': _selectedSourceTag!,
      'dst': _selectedDestinationTag!,
    };

    bool ruleExists = _temporaryRules.any((rule) =>
        (rule['src'] == newRule['src'] && rule['dst'] == newRule['dst']) ||
        (rule['src'] == newRule['dst'] && rule['dst'] == newRule['src']));

    if (ruleExists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cette règle existe déjà.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    setState(() {
      _temporaryRules.add(newRule);
    });

    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(
        message: 'Règle ajoutée et politique appliquée avec succès.');
  }

  Future<void> _generateNewAclPolicy({bool showSnackbar = true}) async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      final users = await apiService.getUsers();
      final nodes =
          _allNodes.isNotEmpty ? _allNodes : await apiService.getNodes();
      if (_allNodes.isEmpty) _allNodes = nodes;

      _currentAclPolicy = _newAclGeneratorService.generatePolicy(
        users: users,
        nodes: nodes,
        temporaryRules: _temporaryRules,
      );

      _updateAclControllerText();

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Politique ACL avancée générée dans le champ de texte.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 4),
                Text('Utilisez le menu (⋮) pour l\'exporter.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.7),
                        fontSize: 12)),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la génération de la politique ACL avancée : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Échec de la génération de la politique ACL avancée : $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeTemporaryRule(int index) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
                'Cela va supprimer la règle et appliquer immédiatement la nouvelle politique au serveur. Continuer ?'),
            actions: [
              TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: const Text('Confirmer',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.removeAt(index);
    });

    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(
        message: 'Règle supprimée et politique mise à jour.');
  }

  Future<void> _clearTemporaryRules() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text(
                'Cela va supprimer TOUTES les règles et appliquer la nouvelle politique au serveur. Continuer ?'),
            actions: [
              TextButton(
                  child: const Text('Annuler'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: const Text('Confirmer',
                      style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.clear();
    });
    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(
        message:
            'Toutes les règles ont été supprimées et la politique a été mise à jour.');
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    await _generateNewAclPolicy(showSnackbar: false);
    await _exportAclPolicyToServer(
        showConfirmation: false, successMessage: message);
  }

  Future<void> _exportAclPolicyToServer(
      {bool showConfirmation = true, String? successMessage}) async {
    if (showConfirmation) {
      final bool confirm = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Confirmer l\'exportation',
                    style: Theme.of(context).textTheme.titleLarge),
                content: Text(
                    'Vous allez appliquer la politique ACL définie dans le champ de texte sur votre serveur. Êtes-vous sûr ?',
                    style: Theme.of(context).textTheme.bodyMedium),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Confirmer',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!confirm) return;
    }

    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      await apiService.setAclPolicy(_aclController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  successMessage ??
                      'Politique ACL exportée avec succès vers le serveur.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Échec de l\'exportation de la politique ACL : $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
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
          SnackBar(
              content: Text('Politique ACL récupérée du serveur.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération de la politique ACL du serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Échec de la récupération de la politique ACL : $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
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
          SnackBar(
              content: Text(
                  'Le contenu ACL est vide. Générez d\'abord une politique.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl.json');
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Voici votre politique ACL Headscale.');
    } catch (e) {
      debugPrint('Erreur lors du partage du fichier ACL : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Échec du partage du fichier ACL : $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _resetAclPolicy() async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirmer la réinitialisation',
                  style: Theme.of(context).textTheme.titleLarge),
              content: Text(
                  'Vous allez remplacer la politique actuelle par une politique qui autorise TOUT le trafic entre TOUS les appareils. Êtes-vous sûr ?',
                  style: Theme.of(context).textTheme.bodyMedium),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Confirmer',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirm || !mounted) return;

    const defaultPolicy = {
      "acls": [
        {
          "action": "accept",
          "src": ["*"],
          "dst": ["*:*"]
        }
      ]
    };

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(defaultPolicy);

    // Also clear temporary rules as they are now irrelevant
    setState(() {
      _temporaryRules.clear();
    });
    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);

    await _exportAclPolicyToServer(
        showConfirmation: false,
        successMessage:
            'Politique réinitialisée : tout le trafic est maintenant autorisé.');
  }
}
