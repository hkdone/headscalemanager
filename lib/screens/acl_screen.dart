import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/widgets/shared_routes_access_dialog.dart';
import 'package:headscalemanager/utils/ip_utils.dart';

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
  List<Node> _destinationNodes = [];
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final _portController = TextEditingController();
  final List<Map<String, dynamic>> _temporaryRules = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    // No need for listen: false here as it's in initState
    final storage = context.read<AppProvider>().storageService;
    await _fetchNodes();
    final loadedRules = await storage.getTemporaryRules();
    if (mounted) {
      setState(() {
        _temporaryRules.addAll(loadedRules);
      });
      await _generateNewAclPolicy(showSnackbar: false);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
      _destinationNodes = List.from(_allNodes);
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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isFr ? 'Gestion des ACLs' : 'ACL Management',
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
                      maxLines: 20,
                      minLines: 5,
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _generateNewAclPolicy(showSnackbar: true),
            label: Text(isFr
                ? 'Générer Politique Standard'
                : 'Generate Standard Policy'),
            icon: const Icon(Icons.settings_backup_restore),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            heroTag: 'generate_policy_fab',
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  PopupMenuButton<String> _buildActionsMenu() {
    // This is inside build, so watch is fine. The onSelected callback is the issue.
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return PopupMenuButton<String>(
      onSelected: (value) {
        // We use context.read inside the callbacks
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildNodeDropdown(
                    'Source (Node)',
                    _selectedSourceNode,
                    _allNodes,
                    (node) {
                      setState(() {
                        _selectedSourceNode = node;
                        _selectedDestinationNode = null;
                        if (node != null) {
                          _destinationNodes = _allNodes
                              .where((n) => n.user != node.user)
                              .toList();
                        } else {
                          _destinationNodes = List.from(_allNodes);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _buildNodeDropdown(
                    'Destination (Node)',
                    _selectedDestinationNode,
                    _destinationNodes,
                    (node) => setState(() => _selectedDestinationNode = node),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Port', 'ex: 443'),
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
              runSpacing: 4.0,
              children: _temporaryRules.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> rule = entry.value;
                final src = rule['src'] as String;
                final dst = rule['dst'] as String;
                final port = rule['port'] as String?;

                final srcNodeName = _getNodeNameFromIpOrSubnet(src);
                final dstNodeName = _getNodeNameFromIpOrSubnet(dst);

                final label =
                    '$srcNodeName -> $dstNodeName:${port != null && port.isNotEmpty ? port : '*'}';

                return Chip(
                  label: Text(label, overflow: TextOverflow.ellipsis),
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

  String _getNodeNameFromIpOrSubnet(String ipOrSubnet) {
    try {
      return _allNodes
          .firstWhere((node) =>
              node.ipAddresses.contains(ipOrSubnet) ||
              node.sharedRoutes.contains(ipOrSubnet))
          .name;
    } catch (e) {
      return ipOrSubnet;
    }
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(String label,
      Node? selectedNode, List<Node> nodes, ValueChanged<Node?> onChanged) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return DropdownButtonFormField<Node>(
      value: selectedNode,
      decoration: _buildInputDecoration(
          label, isFr ? 'Choisir un nœud' : 'Choose a node'),
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
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  bool _ruleExists(Map<String, dynamic> newRule) {
    return _temporaryRules.any((rule) {
      final bool srcMatch = rule['src'] == newRule['src'];
      final bool dstMatch = rule['dst'] == newRule['dst'];
      final bool portMatch = (rule['port'] ?? '') == (newRule['port'] ?? '');
      return srcMatch && dstMatch && portMatch;
    });
  }

  Future<void> _addTemporaryRule() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    if (_selectedSourceNode == null || _selectedDestinationNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Veuillez sélectionner un nœud source et un nœud destination.'
                  : 'Please select a source and a destination node.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    if (_selectedSourceNode!.ipAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Le nœud source doit avoir au moins une adresse IP.'
                  : 'Source node must have at least one IP address.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    final sourceIp = _selectedSourceNode!.ipAddresses.first;

    List<Map<String, dynamic>> newRulesToAdd = [];

    final sharedLanRoutes = _selectedDestinationNode!.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();

    if (sharedLanRoutes.isNotEmpty) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SharedRoutesAccessDialog(
          destinationNode: _selectedDestinationNode!,
        ),
      );

      // Debug: Afficher le résultat reçu du dialogue
      debugPrint('DEBUG: Résultat reçu du dialogue: $result');

      if (result == null) {
        debugPrint('DEBUG: Résultat est null, arrêt du processus');
        return;
      }

      try {
        final choice = result['choice'] as RouteAccessChoice;
        final rules = result['rules'] as Map<String, dynamic>;

        // Debug: Afficher le choix et les règles extraites
        debugPrint('DEBUG: Choix extrait: $choice');
        debugPrint('DEBUG: Règles extraites: $rules');
      } catch (e) {
        debugPrint('DEBUG: Erreur lors de l\'extraction du choix/règles: $e');
        debugPrint(
            'DEBUG: Type de result[\'choice\']: ${result['choice'].runtimeType}');
        return;
      }

      final choice = result['choice'] as RouteAccessChoice;
      final rules = result['rules'] as Map<String, dynamic>;

      if (choice == RouteAccessChoice.none) {
        // Fallback: add rule for the node itself if subnet access is denied
        if (_selectedDestinationNode!.ipAddresses.isNotEmpty) {
          final destinationIp = _selectedDestinationNode!.ipAddresses.first;
          final port = _portController.text.trim();
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': destinationIp,
            'port': port.isEmpty ? '*' : port,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isFr
                ? 'Accès au sous-réseau non configuré et le nœud n\'a pas d\'IP pour une règle de base.'
                : 'Subnet access not configured and the node has no IP for a fallback rule.'),
          ));
          return;
        }
      } else if (choice == RouteAccessChoice.full) {
        for (var route in sharedLanRoutes) {
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': route,
            'port': '*',
          });
        }
      } else if (choice == RouteAccessChoice.custom) {
        rules.forEach((route, ruleDetails) {
          final startIp = (ruleDetails['startIp'] as String).trim();
          final endIp = (ruleDetails['endIp'] as String).trim();
          final ports = (ruleDetails['ports'] as String).trim();

          if (startIp.isEmpty) return;

          String dst;
          if (endIp.isNotEmpty) {
            final range = IpUtils.generateIpRange(startIp, endIp);
            dst = range.join(',');
          } else {
            dst = startIp;
          }

          if (dst.isNotEmpty) {
            newRulesToAdd.add({
              'src': sourceIp,
              'dst': dst,
              'port': ports.isEmpty ? '*' : ports,
            });
          }
        });
      }
    } else {
      if (_selectedDestinationNode!.ipAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isFr
                    ? 'Le nœud destination doit avoir au moins une adresse IP.'
                    : 'Destination node must have at least one IP address.',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      final destinationIp = _selectedDestinationNode!.ipAddresses.first;

      if (sourceIp == destinationIp) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isFr
                    ? 'Les nœuds source et destination ne peuvent pas être identiques.'
                    : 'Source and destination nodes cannot be the same.',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      final port = _portController.text.trim();
      newRulesToAdd.add({
        'src': sourceIp,
        'dst': destinationIp,
        'port': port,
      });
    }

    int addedCount = 0;

    // Debug: Afficher les règles à ajouter
    debugPrint('DEBUG: Nombre de règles à ajouter: ${newRulesToAdd.length}');
    for (var rule in newRulesToAdd) {
      debugPrint('DEBUG: Règle à ajouter: $rule');
    }

    for (var newRule in newRulesToAdd) {
      if (!_ruleExists(newRule)) {
        setState(() {
          _temporaryRules.add(newRule);
          addedCount++;
        });
        debugPrint('DEBUG: Règle ajoutée: $newRule');
      } else {
        debugPrint('DEBUG: Règle ignorée (existe déjà): $newRule');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${isFr ? 'Règle ignorée car elle existe déjà:' : 'Skipped existing rule:'} ${newRule['dst']}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer));
      }
    }

    debugPrint('DEBUG: Nombre de règles ajoutées: $addedCount');

    if (addedCount > 0) {
      final storage = context.read<AppProvider>().storageService;
      await storage.saveTemporaryRules(_temporaryRules);
      await _generateAndExportPolicy(
          message: isFr
              ? '$addedCount règle(s) ajoutée(s) et politique appliquée.'
              : '$addedCount rule(s) added and policy applied.');
    } else {
      // Debug: Afficher un message si aucune règle n'a été ajoutée
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr ? 'Aucune règle n\'a été ajoutée.' : 'No rules were added.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _generateNewAclPolicy({bool showSnackbar = true}) async {
    if (!mounted) return;
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

      final locale = appProvider.locale;
      final isFr = locale.languageCode == 'fr';

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isFr
                        ? 'Politique ACL avancée générée dans le champ de texte.'
                        : 'Advanced ACL policy generated in the text field.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 4),
                Text(
                    isFr
                        ? 'Utilisez le menu (⋮) pour l\'exporter.'
                        : 'Use the menu (⋮) to export it.',
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
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de la génération de la politique ACL avancée' : 'Failed to generate advanced ACL policy'}: $e',
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final aclJsonString = await apiService.getAclPolicy();
      _currentAclPolicy = json.decode(aclJsonString);
      _updateAclControllerText();
      final locale = appProvider.locale;
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
    if (!mounted) return;
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
      final file = File('${directory.path}/acl.json');
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Voici votre politique ACL Headscale.');
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
    if (!mounted) return;
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
