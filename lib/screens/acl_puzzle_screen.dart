import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/utils/json_utils.dart';
import 'package:headscalemanager/services/acl_puzzle_service.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart'; // For normalizeUserName

class AclPuzzleScreen extends StatefulWidget {
  const AclPuzzleScreen({super.key});

  @override
  State<AclPuzzleScreen> createState() => _AclPuzzleScreenState();
}

class _AclPuzzleScreenState extends State<AclPuzzleScreen> {
  final List<PuzzleRule> _puzzleRules = [];
  bool _isLoading = true;
  final AclPuzzleService _puzzleService = AclPuzzleService();
  final NewAclGeneratorService _baseGenerator = NewAclGeneratorService();

  // Cached data for Entity Selection
  List<User> _users = [];
  List<Node> _nodes = [];
  final List<PuzzleEntity> _availableEntities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final isFr = appProvider.locale.languageCode == 'fr';

      final users = await apiService.getUsers();
      final nodes = await apiService.getNodes();

      // Load current policy
      Map<String, dynamic> currentPolicy = {};
      try {
        final policyString = await apiService.getAclPolicy();
        if (policyString.isNotEmpty) {
          try {
            currentPolicy =
                json.decode(JsonUtils.cleanJsonComments(policyString));
          } catch (e) {
            debugPrint('Error parsing ACL policy JSON: $e');
            // Optionally show error to user or handle HuJSON if needed
          }
        }
      } catch (e) {
        // Ignore if no policy exists or error
        debugPrint('Error loading ACL policy: $e');
      }

      setState(() {
        _users = users;
        _nodes = nodes;
        _buildAvailableEntities(isFr);

        // Parse existing policy
        if (currentPolicy.isNotEmpty) {
          _puzzleRules.clear();
          _puzzleRules.addAll(_puzzleService.parseJsonToPuzzle(
            jsonPolicy: currentPolicy,
            availableEntities: _availableEntities,
          ));
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _buildAvailableEntities(bool isFr) {
    _availableEntities.clear();

    // 1. Groups & Tag Owners (Implicit from Users)
    for (var user in _users) {
      // Group Entity
      _availableEntities.add(PuzzleEntity(
        id: 'group:${user.name}',
        type: PuzzleEntityType.group,
        value: 'group:${user.name}',
        displayLabel: isFr ? 'Groupe: ${user.name}' : 'Group: ${user.name}',
      ));

      // User Tag Entity (e.g. tag:tom-client)
      final normUser = normalizeUserName(user.name);
      _availableEntities.add(PuzzleEntity(
        id: 'tag:$normUser-client',
        type: PuzzleEntityType.tag,
        value: 'tag:$normUser-client',
        displayLabel: 'Tag: $normUser-client',
      ));
    }

    // 2. Special Tags (Exit Nodes, etc.) from Nodes
    final Set<String> specialTags = {};
    for (var node in _nodes) {
      for (var tag in node.tags) {
        specialTags.add(tag);
      }
    }
    for (var tag in specialTags) {
      // Avoid duplicates if already added by user logic above
      if (!_availableEntities.any((e) => e.value == tag)) {
        _availableEntities.add(PuzzleEntity(
            id: tag,
            type: PuzzleEntityType.tag,
            value: tag,
            displayLabel: 'Tag: $tag'));
      }
    }

    // 3. Internet
    _availableEntities.add(PuzzleEntity(
      id: 'autogroup:internet',
      type: PuzzleEntityType.internet,
      value: 'autogroup:internet',
      displayLabel: isFr ? 'Internet (Monde)' : 'Internet (World)',
    ));

    // 4. LAN Subnets (extracted from nodes routes)
    final Set<String> routes = {};
    for (var node in _nodes) {
      for (var route in node.sharedRoutes) {
        if (route != '0.0.0.0/0' && route != '::/0') {
          routes.add(route);
        }
      }
    }
    for (var route in routes) {
      _availableEntities.add(PuzzleEntity(
        id: route,
        type: PuzzleEntityType.cidr,
        value: route,
        displayLabel: isFr ? 'Sous-réseau: $route' : 'Subnet: $route',
      ));
    }
  }

  void _addRule() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RuleEditorDialog(
        availableEntities: _availableEntities,
        existingRules: _puzzleRules,
        onSave: (rule) {
          setState(() {
            _puzzleRules.add(rule);
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _deleteRule(int index) {
    setState(() {
      _puzzleRules.removeAt(index);
    });
  }

  Future<void> _applyPolicy() async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    // 1. Generate Base Policy (Infrastructure)
    final basePolicy =
        _baseGenerator.generatePolicy(users: _users, nodes: _nodes);

    // 2. Merge with Puzzle Rules
    final finalPolicy = _puzzleService.convertPuzzleToJson(
      rules: _puzzleRules,
      basePolicy: basePolicy,
    );

    // 3. Export to Server
    try {
      final appProvider = context.read<AppProvider>();
      final String jsonPolicy =
          const JsonEncoder.withIndent('  ').convert(finalPolicy);
      await appProvider.apiService.setAclPolicy(jsonPolicy);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFr
              ? 'Politique ACL (Puzzle) appliquée avec succès !'
              : 'ACL Puzzle Policy applied successfully!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFr
              ? 'Erreur lors de l\'application : $e'
              : 'Error applying policy: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isFr ? 'Constructeur ACL (Puzzle)' : 'ACL Builder (Puzzle)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: isFr ? 'Tout effacer' : 'Clear all',
            onPressed: () {
              setState(() {
                _puzzleRules.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: isFr ? 'Appliquer au serveur' : 'Apply to server',
            onPressed: _applyPolicy,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _puzzleRules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.extension_off,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          isFr
                              ? 'Aucune pièce de puzzle'
                              : 'No puzzle pieces yet',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFr
                              ? 'Appuyez sur + pour commencer'
                              : 'Tap + to start building',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _puzzleRules.length,
                    itemBuilder: (context, index) {
                      final rule = _puzzleRules[index];
                      return _PuzzleBlockCard(
                        rule: rule,
                        onDelete: () => _deleteRule(index),
                        service:
                            _puzzleService, // Pass service for code preview
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRule,
        icon: const Icon(Icons.add),
        label: Text(isFr ? 'Ajouter une pièce' : 'Add Piece'),
      ),
    );
  }
}

class _PuzzleBlockCard extends StatefulWidget {
  final PuzzleRule rule;
  final VoidCallback onDelete;
  final AclPuzzleService service;

  const _PuzzleBlockCard(
      {required this.rule, required this.onDelete, required this.service});

  @override
  State<_PuzzleBlockCard> createState() => _PuzzleBlockCardState();
}

class _PuzzleBlockCardState extends State<_PuzzleBlockCard> {
  bool _showCode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    // Generate preview JSON snippet for this single rule
    // We wrap it in a dummy map to simulate the convert process for just this rule
    Map<String, dynamic> singleRuleJson = {
      'action': widget.rule.action,
      'src': widget.rule.sources.map((e) => e.value).toList(),
      'dst': widget.rule.destinations
          .map((e) => '${e.value}${e.value.contains(':') ? '' : ':*'}')
          .toList(),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        children: [
          // Visual Part
          InkWell(
            onTap: () => _showDetailsDialog(context, isFr),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Sources
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: widget.rule.sources
                          .map((e) => Chip(
                                label: Text(e.displayLabel,
                                    style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(_getIconForType(e.type), size: 14),
                              ))
                          .toList(),
                    ),
                  ),
                  // Arrow / Action
                  Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          const Icon(Icons.arrow_forward, color: Colors.green),
                          Text(isFr ? 'AUTOR.' : 'ALLOW',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green))
                        ],
                      )),
                  // Destinations
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: widget.rule.destinations
                          .map((e) => Chip(
                                label: Text(e.displayLabel,
                                    style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                avatar: Icon(_getIconForType(e.type), size: 14),
                              ))
                          .toList(),
                    ),
                  ),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: widget.onDelete)
                ],
              ),
            ),
          ),

          // Educational Part (Code Preview)
          InkWell(
            onTap: () {
              setState(() {
                _showCode = !_showCode;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_showCode ? Icons.expand_less : Icons.code,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    isFr
                        ? (_showCode ? 'Masquer le code' : 'Voir le code JSON')
                        : (_showCode ? 'Hide code' : 'View JSON code'),
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          if (_showCode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.black87,
              child: Text(
                const JsonEncoder.withIndent('  ').convert(singleRuleJson),
                style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.lightGreenAccent,
                    fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForType(PuzzleEntityType type) {
    switch (type) {
      case PuzzleEntityType.user:
        return Icons.person;
      case PuzzleEntityType.group:
        return Icons.group;
      case PuzzleEntityType.tag:
        return Icons.label;
      case PuzzleEntityType.host:
        return Icons.computer;
      case PuzzleEntityType.cidr:
        return Icons.dns;
      case PuzzleEntityType.internet:
        return Icons.public;
    }
  }

  void _showDetailsDialog(BuildContext context, bool isFr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Détails de la règle' : 'Rule Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailSection(ctx, isFr ? 'SOURCES' : 'SOURCES',
                  widget.rule.sources, Colors.blue),
              const Divider(),
              Center(
                child: Chip(
                  label: Text(isFr ? 'ACTION: AUTORISER' : 'ACTION: ALLOW',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.green.withAlpha(51),
                  avatar: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ),
              const Divider(),
              _buildDetailSection(ctx, isFr ? 'DESTINATIONS' : 'DESTINATIONS',
                  widget.rule.destinations, Colors.orange),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          )
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title,
      List<PuzzleEntity> entities, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children: entities
              .map((e) => Chip(
                    avatar: Icon(_getIconForType(e.type), size: 16),
                    label: Text(e.displayLabel),
                    backgroundColor: color.withAlpha(26),
                    side: BorderSide(color: color.withAlpha(77)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _RuleEditorDialog extends StatefulWidget {
  final List<PuzzleEntity> availableEntities;
  final List<PuzzleRule> existingRules;
  final Function(PuzzleRule) onSave;

  const _RuleEditorDialog(
      {required this.availableEntities,
      required this.existingRules,
      required this.onSave});

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final List<PuzzleEntity> _selectedSources = [];
  final List<PuzzleEntity> _selectedDestinations = [];
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    // A simple wizard-like bottom sheet
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _currentStep == 0
                  ? (isFr ? 'Étape 1: QUI ? (Source)' : 'Step 1: WHO? (Source)')
                  : (isFr
                      ? 'Étape 2: VERS QUOI ? (Destination)'
                      : 'Step 2: TO WHAT? (Destination)'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildEntityList(
                  _currentStep == 0 ? _selectedSources : _selectedDestinations,
                  isFr),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: Text(isFr ? 'Précédent' : 'Back'),
                  )
                else
                  const SizedBox(),
                ElevatedButton(
                  onPressed: () {
                    if (_currentStep == 0) {
                      if (_selectedSources.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isFr
                                ? 'Veuillez sélectionner au moins une source.'
                                : 'Please select at least one source.'),
                            backgroundColor: Colors.orange));
                        return;
                      }
                      setState(() => _currentStep++);
                    } else {
                      if (_selectedDestinations.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(isFr
                                ? 'Veuillez sélectionner au moins une destination.'
                                : 'Please select at least one destination.'),
                            backgroundColor: Colors.orange));
                        return;
                      }
                      widget.onSave(PuzzleRule(
                          sources: List.from(_selectedSources),
                          destinations: List.from(_selectedDestinations)));
                    }
                  },
                  child: Text(_currentStep == 0
                      ? (isFr ? 'Suivant' : 'Next')
                      : (isFr ? 'Ajouter la pièce' : 'Add Piece')),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEntityList(List<PuzzleEntity> selectedList, bool isFr) {
    // Group entities by type for better UI
    final grouped = <PuzzleEntityType, List<PuzzleEntity>>{};

    // Smart Filtering Logic for Step 2 (Destinations)
    Set<String> excludedIds = {};
    if (_currentStep == 1) {
      for (var rule in widget.existingRules) {
        // If the rule has *any* of the currently selected sources
        bool sharesSource = rule.sources.any((ruleSrc) => _selectedSources
            .any((selectedSrc) => selectedSrc.value == ruleSrc.value));

        if (sharesSource) {
          // Then we should exclude all destinations of this rule
          for (var dst in rule.destinations) {
            excludedIds.add(dst.value);
            // Also handle implicit :* logic if needed, but value matching should suffice
            // given how we parse and store them.
          }
        }
      }
    }

    for (var e in widget.availableEntities) {
      // Step 0: Skip Internet/CIDR for sources usually
      if (e.type == PuzzleEntityType.internet && _currentStep == 0) continue;

      // Step 1: Filter out already configured destinations
      if (_currentStep == 1 && excludedIds.contains(e.value)) continue;

      grouped.putIfAbsent(e.type, () => []).add(e);
    }

    if (grouped.isEmpty) {
      return Center(
          child: Text(isFr
              ? 'Aucune destination disponible (déjà configuré ?)'
              : 'No available destinations (already configured?)'));
    }

    return ListView(
      children: grouped.entries.map((entry) {
        return ExpansionTile(
          initiallyExpanded: true,
          title: Text(_getLocalizedEntityType(entry.key, isFr)),
          children: entry.value.map((entity) {
            final isSelected = selectedList.any((e) => e.id == entity.id);
            return CheckboxListTile(
              value: isSelected,
              title: Text(entity.displayLabel),
              secondary: Icon(_getIconForType(entity.type)),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    selectedList.add(entity);
                  } else {
                    selectedList.removeWhere((e) => e.id == entity.id);
                  }
                });
              },
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  String _getLocalizedEntityType(PuzzleEntityType type, bool isFr) {
    if (!isFr) return type.toString().split('.').last.toUpperCase();
    switch (type) {
      case PuzzleEntityType.user:
        return 'UTILISATEUR';
      case PuzzleEntityType.group:
        return 'GROUPE';
      case PuzzleEntityType.tag:
        return 'TAG';
      case PuzzleEntityType.host:
        return 'HÔTE';
      case PuzzleEntityType.cidr:
        return 'RÉSEAU (CIDR)';
      case PuzzleEntityType.internet:
        return 'INTERNET';
    }
  }

  IconData _getIconForType(PuzzleEntityType type) {
    switch (type) {
      case PuzzleEntityType.user:
        return Icons.person;
      case PuzzleEntityType.group:
        return Icons.group;
      case PuzzleEntityType.tag:
        return Icons.label;
      case PuzzleEntityType.host:
        return Icons.computer;
      case PuzzleEntityType.cidr:
        return Icons.dns;
      case PuzzleEntityType.internet:
        return Icons.public;
    }
  }
}
