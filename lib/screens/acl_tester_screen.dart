import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';

class AclTesterScreen extends StatefulWidget {
  const AclTesterScreen({super.key});

  @override
  State<AclTesterScreen> createState() => _AclTesterScreenState();
}

class _AclTesterScreenState extends State<AclTesterScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {};
  final NewAclGeneratorService _newAclGeneratorService =
      NewAclGeneratorService();

  List<Node> _allNodes = [];
  List<String> _allTags = [];
  String? _selectedSourceTag;
  String? _selectedDestinationTag;
  final List<Map<String, dynamic>> _temporaryRules = [];

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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isFr ? 'Testeur ACL' : 'ACL Tester',
            style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: isFr ? 'Générer la Politique' : 'Generate Policy',
            onPressed: () => _generateNewAclPolicy(showSnackbar: true),
          ),
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
    );
  }

  PopupMenuButton<String> _buildActionsMenu() {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

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
        PopupMenuItem<String>(
          value: 'export',
          child: ListTile(
              leading: const Icon(Icons.cloud_upload),
              title:
                  Text(isFr ? 'Exporter vers le serveur' : 'Export to Server')),
        ),
        PopupMenuItem<String>(
          value: 'fetch',
          child: ListTile(
              leading: const Icon(Icons.cloud_download),
              title: Text(isFr ? 'Récupérer du serveur' : 'Fetch from Server')),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
              leading: const Icon(Icons.share),
              title: Text(isFr ? 'Partager en fichier' : 'Share as File')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'reset',
          child: ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.orange),
            title: Text(
                isFr ? 'Autoriser tout (Réinitialiser)' : 'Allow All (Reset)',
                style: const TextStyle(color: Colors.orange)),
          ),
        ),
      ],
    );
  }

  Widget _buildTemporaryRulesSection() {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFr ? 'Autorisations Spécifiques' : 'Specific Permissions',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Créez ici des exceptions pour autoriser la communication entre les appareils de différents utilisateurs.'
                  : 'Create exceptions here to allow communication between devices of different users.',
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
                label: Text(isFr ? 'Ajouter et Appliquer' : 'Add and Apply',
                    style: const TextStyle(color: Colors.white)),
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
                Text(isFr ? 'Règles actives:' : 'Active Rules:',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.delete_sweep,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  tooltip:
                      isFr ? 'Effacer toutes les règles' : 'Clear All Rules',
                  onPressed: _clearTemporaryRules,
                )
              ],
            ),
            Wrap(
              spacing: 8.0,
              children: _temporaryRules.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> rule = entry.value;
                final port = rule['port'] as String?;
                final portString = (port != null && port.isNotEmpty) ? ':${rule['port']}' : '';
                return Chip(
                  label: Text('${rule['src']} <-> ${rule['dst']}$portString'),
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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return DropdownButtonFormField<String>(
      value: selectedTag,
      decoration: _buildInputDecoration(
          label, isFr ? 'Choisir un tag' : 'Choose a tag'),
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
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    if (_selectedSourceTag == null || _selectedDestinationTag == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Veuillez sélectionner un tag source et un tag destination.'
                  : 'Please select a source and a destination tag.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    if (_selectedSourceTag == _selectedDestinationTag) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Le tag source et le tag destination ne peuvent pas être identiques.'
                  : 'Source and destination tags cannot be the same.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    final newRule = <String, dynamic>{
      'src': _selectedSourceTag!,
      'dst': _selectedDestinationTag!,
      'port': '', // Add port support later if needed
    };

    bool ruleExists = _temporaryRules.any((rule) =>
        (rule['src'] == newRule['src'] && rule['dst'] == newRule['dst']) ||
        (rule['src'] == newRule['dst'] && rule['dst'] == newRule['src']));

    if (ruleExists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr ? 'Cette règle existe déjà.' : 'This rule already exists.',
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
        message: isFr
            ? 'Règle ajoutée et politique appliquée avec succès.'
            : 'Rule added and policy applied successfully.');
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

      final locale = context.read<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isFr
                    ? 'Nouvelle politique ACL générée dans le champ de texte.'
                    : 'New ACL policy generated in the text field.',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la génération de la nouvelle politique ACL : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de la génération de la nouvelle politique ACL' : 'Failed to generate new ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeTemporaryRule(int index) async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Confirmer la suppression' : 'Confirm Deletion'),
            content: Text(isFr
                ? 'Cela va supprimer la règle et appliquer immédiatement la nouvelle politique au serveur. Continuer ?'
                : 'This will delete the rule and immediately apply the new policy to the server. Continue?'),
            actions: [
              TextButton(
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: Text(isFr ? 'Confirmer' : 'Confirm',
                      style: const TextStyle(color: Colors.red)),
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
        message: isFr
            ? 'Règle supprimée et politique mise à jour.'
            : 'Rule deleted and policy updated.');
  }

  Future<void> _clearTemporaryRules() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Confirmer la suppression' : 'Confirm Deletion'),
            content: Text(isFr
                ? 'Cela va supprimer TOUTES les règles et appliquer la nouvelle politique au serveur. Continuer ?'
                : 'This will delete ALL rules and apply the new policy to the server. Continue?'),
            actions: [
              TextButton(
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: Text(isFr ? 'Confirmer' : 'Confirm',
                      style: const TextStyle(color: Colors.red)),
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
        message: isFr
            ? 'Toutes les règles ont été supprimées et la politique a été mise à jour.'
            : 'All rules have been deleted and the policy has been updated.');
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    await _generateNewAclPolicy(showSnackbar: false);
    await _exportAclPolicyToServer(
        showConfirmation: false, successMessage: message);
  }

  Future<void> _exportAclPolicyToServer(
      {bool showConfirmation = true, String? successMessage}) async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    if (showConfirmation) {
      final bool confirm = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                    isFr ? 'Confirmer l\'exportation' : 'Confirm Export',
                    style: Theme.of(context).textTheme.titleLarge),
                content: Text(
                    isFr
                        ? 'Vous allez appliquer la politique ACL définie dans le champ de texte sur votre serveur. Êtes-vous sûr ?'
                        : 'You are about to apply the ACL policy defined in the text field to your server. Are you sure?',
                    style: Theme.of(context).textTheme.bodyMedium),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(isFr ? 'Annuler' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(isFr ? 'Confirmer' : 'Confirm',
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
                      (isFr
                          ? 'Politique ACL exportée avec succès vers le serveur.'
                          : 'ACL policy successfully exported to the server.'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de l\'exportation de la politique ACL' : 'Failed to export ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAclPolicyFromServer() async {
    setState(() => _isLoading = true);
    try {
      final apiService = context.read<AppProvider>().apiService;
      final aclJsonString = await apiService.getAclPolicy();
      _currentAclPolicy = json.decode(aclJsonString);
      _updateAclControllerText();
      final locale = context.read<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isFr
                      ? 'Politique ACL récupérée du serveur.'
                      : 'ACL policy fetched from the server.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération de la politique ACL du serveur : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de la récupération de la politique ACL' : 'Failed to fetch ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _shareAclFile() async {
    try {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String aclJsonString = encoder.convert(_currentAclPolicy);

      final locale = context.read<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      if (aclJsonString.isEmpty || aclJsonString == encoder.convert({})) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isFr
                      ? 'Le contenu ACL est vide. Générez d\'abord une politique.'
                      : 'ACL content is empty. Generate a policy first.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl_new.json');
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)],
          text: isFr
              ? 'Voici votre nouvelle politique ACL Headscale.'
              : 'Here is your new Headscale ACL policy.');
    } catch (e) {
      debugPrint('Erreur lors du partage du fichier ACL : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec du partage du fichier ACL' : 'Failed to share ACL file'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _resetAclPolicy() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                  isFr ? 'Confirmer la réinitialisation' : 'Confirm Reset',
                  style: Theme.of(context).textTheme.titleLarge),
              content: Text(
                  isFr
                      ? 'Vous allez remplacer la politique actuelle par une politique qui autorise TOUT le trafic entre TOUS les appareils. Êtes-vous sûr ?'
                      : 'You are about to replace the current policy with one that allows ALL traffic between ALL devices. Are you sure?',
                  style: Theme.of(context).textTheme.bodyMedium),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(isFr ? 'Confirmer' : 'Confirm',
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

    setState(() {
      _temporaryRules.clear();
    });
    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);

    await _exportAclPolicyToServer(
        showConfirmation: false,
        successMessage: isFr
            ? 'Politique réinitialisée : tout le trafic est maintenant autorisé.'
            : 'Policy reset: all traffic is now allowed.');
  }
}
