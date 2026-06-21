import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/utils/json_utils.dart';
import 'package:headscalemanager/services/acl_puzzle_service.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/string_utils.dart'; // For normalizeUserName

void _showEntityRenameDialog(BuildContext context, PuzzleEntity entity, VoidCallback onSaved) {
  final appProvider = context.read<AppProvider>();
  final isFr = appProvider.locale.languageCode == 'fr';
  final currentAlias = appProvider.getEntityAlias(entity.value) ?? '';
  final controller = TextEditingController(text: currentAlias);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isFr ? 'Renommer l\'entité' : 'Rename Entity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isFr ? "Valeur d'origine" : "Original Value"}: ${entity.value}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: isFr ? 'Nom personnalisé (Alias)' : 'Custom Name (Alias)',
              hintText: entity.displayLabel,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await appProvider.setEntityAlias(entity.value, controller.text);
            onSaved();
            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          },
          child: Text(isFr ? 'Enregistrer' : 'Save'),
        ),
      ],
    ),
  );
}

String _wrapTextForWrapping(String text) {
  return text
      .replaceAll(':', ':\u{200B}')
      .replaceAll('-', '-\u{200B}')
      .replaceAll('@', '@\u{200B}')
      .replaceAll('.', '.\u{200B}')
      .replaceAll('/', '/\u{200B}');
}

String _getEntityLabel(BuildContext context, PuzzleEntity entity) {
  final alias = context.watch<AppProvider>().getEntityAlias(entity.value);
  if (alias != null && alias.isNotEmpty) {
    return _wrapTextForWrapping(alias);
  }
  return _wrapTextForWrapping(entity.displayLabel);
}

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
      useSafeArea: true,
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
    final appProvider = context.read<AppProvider>();
    
    // Clean up obsolete lan-sharer tags before ACL generation
    final cleanedNodes = await _cleanupObsoleteLanSharerTags(_nodes);
    
    // 1. Generate Base Policy (Infrastructure)
    final basePolicy =
        _baseGenerator.generatePolicy(
          users: _users,
          nodes: cleanedNodes,
          taildriveShares: appProvider.taildriveShares,
          serverVersion: appProvider.serverVersion,
        );

    // 2. Merge with Puzzle Rules
    final finalPolicy = _puzzleService.convertPuzzleToJson(
      rules: _puzzleRules,
      basePolicy: basePolicy,
    );

    // 3. Export to Server
    try {
      if (!mounted) return;
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

  List<PuzzleRule> get _displayedRules {
    final visualOrder = context.read<AppProvider>().puzzleVisualOrder;
    final list = List<PuzzleRule>.from(_puzzleRules);
    list.sort((a, b) {
      final indexA = visualOrder.indexOf(a.signature);
      final indexB = visualOrder.indexOf(b.signature);
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      } else if (indexA != -1) {
        return -1;
      } else if (indexB != -1) {
        return 1;
      } else {
        return _puzzleRules.indexOf(a).compareTo(_puzzleRules.indexOf(b));
      }
    });
    return list;
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final displayed = _displayedRules;
    final item = displayed.removeAt(oldIndex);
    displayed.insert(newIndex, item);

    // Save visual order of signatures
    final newOrder = displayed.map((r) => r.signature).toList();
    await context.read<AppProvider>().setPuzzleVisualOrder(newOrder);
    setState(() {});
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
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _displayedRules.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final rule = _displayedRules[index];
                      return _PuzzleBlockCard(
                        key: ValueKey(rule.id),
                        rule: rule,
                        onDelete: () {
                          final originalIndex =
                              _puzzleRules.indexWhere((r) => r.id == rule.id);
                          if (originalIndex != -1) {
                            _deleteRule(originalIndex);
                          }
                        },
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

  List<String> _removeCapabilities(List<String> tags,
      {bool removeExitNode = false, bool removeLanSharer = false}) {
    List<String> newTags = List.from(tags);
    int clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex != -1) {
      final oldClientTag = newTags[clientTagIndex];
      final parts = oldClientTag
          .replaceFirst('tag:', '')
          .split(';')
          .where((p) => p.isNotEmpty)
          .toSet();

      if (removeExitNode) parts.remove('exit-node');
      if (removeLanSharer) parts.remove('lan-sharer');

      final clientPart =
          parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
      if (clientPart.isEmpty) return newTags;

      final otherParts = parts.where((p) => p != clientPart).toList()..sort();

      final newClientTagBuilder = StringBuffer('tag:$clientPart');
      if (otherParts.isNotEmpty) {
        newClientTagBuilder.write(';${otherParts.join(';')}');
      }
      newTags[clientTagIndex] = newClientTagBuilder.toString();
    } else {
      if (removeExitNode) newTags.remove('tag:exit-node');
      if (removeLanSharer) newTags.remove('tag:lan-sharer');
    }
    return newTags;
  }

  /// Clean up obsolete lan-sharer tags from nodes that no longer have shared routes
  /// This prevents orphaned route warnings and VPN disconnections
  Future<List<Node>> _cleanupObsoleteLanSharerTags(List<Node> nodes) async {
    if (!mounted) return nodes;
    final appProvider = context.read<AppProvider>();
    final apiService = appProvider.apiService;
    
    // Find nodes with lan-sharer tags but no shared routes
    final nodesToCleanup = nodes.where((node) {
      final hasLanSharerTag = node.tags.any((tag) => 
        tag.contains(';lan-sharer') || 
        tag == 'tag:lan-sharer' ||
        (tag.startsWith('tag:') && tag.contains('lan-sharer'))
      );
      return hasLanSharerTag && node.sharedRoutes.isEmpty;
    }).toList();
    
    // Clean up each affected node
    for (final node in nodesToCleanup) {
      final newTags = _removeCapabilities(List.from(node.tags), removeLanSharer: true);
      await apiService.setTags(node.id, newTags);
    }
    
    // Return refreshed nodes list
    return await apiService.getNodes();
  }
}

class _PuzzleBlockCard extends StatefulWidget {
  final PuzzleRule rule;
  final VoidCallback onDelete;
  final AclPuzzleService service;

  const _PuzzleBlockCard(
      {super.key, required this.rule, required this.onDelete, required this.service});

  @override
  State<_PuzzleBlockCard> createState() => _PuzzleBlockCardState();
}

class _PuzzleBlockCardState extends State<_PuzzleBlockCard> {
  bool _showCode = false;

  IconData? _getCustomIcon(String? key) {
    if (key == null) return null;
    for (var cat in puzzleIconsPalette.values) {
      if (cat.containsKey(key)) {
        return cat[key];
      }
    }
    return null;
  }

  void _showBlockCustomizerDialog(BuildContext context, String signature) {
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';
    final meta = appProvider.getBlockMeta(signature) ?? {};
    final nameController = TextEditingController(text: meta['name'] ?? '');
    String? selectedIcon = meta['iconKey'];
    String? selectedImagePath = meta['imagePath'];
    String? selectedColorHex = meta['colorHex'];

    final List<Map<String, String>> availableColors = [
      {'name': isFr ? 'Bleu Royal' : 'Royal Blue', 'hex': '#1E88E5'},
      {'name': isFr ? 'Violet Profond' : 'Deep Purple', 'hex': '#6A1B9A'},
      {'name': isFr ? 'Vert Forêt' : 'Forest Green', 'hex': '#2E7D32'},
      {'name': isFr ? 'Orange Flamboyant' : 'Sunset Orange', 'hex': '#D84315'},
      {'name': isFr ? 'Teal Profond' : 'Deep Teal', 'hex': '#00695C'},
      {'name': isFr ? 'Bleu Ardoise' : 'Slate Blue', 'hex': '#2C5E8A'},
      {'name': isFr ? 'Rose Crimson' : 'Crimson Rose', 'hex': '#C2185B'},
      {'name': isFr ? 'Indigo Impérial' : 'Imperial Indigo', 'hex': '#1A237E'},
      {'name': isFr ? 'Rouge Rubis' : 'Ruby Red', 'hex': '#B71C1C'},
      {'name': isFr ? 'Gris Anthracite' : 'Charcoal Grey', 'hex': '#37474F'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (stCtx, setModalState) {
            return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(stCtx).viewInsets.bottom + MediaQuery.of(stCtx).padding.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            height: MediaQuery.of(stCtx).size.height * 0.85,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isFr ? 'Personnaliser le bloc de règle' : 'Customize Rule Block',
                    style: Theme.of(stCtx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Nom du bloc' : 'Block Name',
                      hintText: isFr ? 'Ex: Accès Web Invités' : 'Ex: Guest Web Access',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // --- SECTION PHOTO ---
                  Text(
                    isFr ? 'Illustration (Photo)' : 'Illustration (Photo)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: selectedImagePath != null && selectedImagePath!.isNotEmpty && File(selectedImagePath!).existsSync()
                            ? FileImage(File(selectedImagePath!))
                            : null,
                        child: selectedImagePath == null || selectedImagePath!.isEmpty || !File(selectedImagePath!).existsSync()
                            ? const Icon(Icons.image, size: 30, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final image = await picker.pickImage(source: ImageSource.gallery);
                                if (image != null) {
                                  final appDir = await getApplicationDocumentsDirectory();
                                  final fileName = 'puzzle_${DateTime.now().millisecondsSinceEpoch}.png';
                                  final savedFile = await File(image.path).copy('${appDir.path}/$fileName');
                                  
                                  setModalState(() {
                                    selectedImagePath = savedFile.path;
                                  });
                                }
                              },
                              icon: const Icon(Icons.photo_library),
                              label: Text(isFr ? 'Choisir une photo' : 'Choose Photo'),
                            ),
                            if (selectedImagePath != null && selectedImagePath!.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    selectedImagePath = null;
                                  });
                                },
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: Text(
                                  isFr ? 'Supprimer la photo' : 'Remove Photo',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      )
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // --- SECTION COULEUR DE L'EN-TÊTE ---
                  Text(
                    isFr ? 'Couleur de l\'en-tête' : 'Header Color',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: availableColors.map((colorMap) {
                      final hex = colorMap['hex']!;
                      final name = colorMap['name']!;
                      final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                      final isSelected = selectedColorHex == hex;
                      
                      return Tooltip(
                        message: name,
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedColorHex = isSelected ? null : hex;
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Theme.of(stCtx).colorScheme.primary : Colors.grey[300]!,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withAlpha(77),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // --- SECTION PALETTE D'ICÔNES ---
                  Text(
                    isFr ? 'Sélectionner une icône (Palette riche)' : 'Select an Icon (Rich Palette)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  
                  // Grille classée par catégories
                  ...puzzleIconsPalette.entries.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Text(
                            category.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(stCtx).colorScheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: category.value.length,
                          itemBuilder: (context, index) {
                            final key = category.value.keys.elementAt(index);
                            final icon = category.value[key]!;
                            final isIconSelected = selectedIcon == key;
                            
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedIcon = isIconSelected ? null : key;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isIconSelected
                                      ? Theme.of(stCtx).colorScheme.primary.withAlpha(51)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isIconSelected
                                        ? Theme.of(stCtx).colorScheme.primary
                                        : Colors.grey[300]!,
                                    width: isIconSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  color: isIconSelected
                                      ? Theme.of(stCtx).colorScheme.primary
                                      : Colors.grey[700],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            appProvider.deleteBlockMeta(signature);
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                          child: Text(isFr ? 'Réinitialiser' : 'Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await appProvider.setBlockMeta(
                              signature,
                              name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : '',
                              iconKey: selectedIcon ?? '',
                              imagePath: selectedImagePath ?? '',
                              colorHex: selectedColorHex ?? '',
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              setState(() {});
                            }
                          },
                          child: Text(isFr ? 'Enregistrer' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    final appProvider = context.watch<AppProvider>();

    final sig = widget.rule.signature;
    final meta = appProvider.getBlockMeta(sig);
    final customName = meta?['name'] as String?;
    final iconKey = meta?['iconKey'] as String?;
    final imagePath = meta?['imagePath'] as String?;
    final colorHex = meta?['colorHex'] as String?;

    IconData? customIcon = _getCustomIcon(iconKey);

    Color? customHeaderColor;
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        customHeaderColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (e) {
        debugPrint('Error parsing colorHex: $e');
      }
    }

    final hasCustomHeader = (customName != null && customName.isNotEmpty) ||
        (iconKey != null && iconKey.isNotEmpty) ||
        (imagePath != null && imagePath.isNotEmpty) ||
        (colorHex != null && colorHex.isNotEmpty);

    final String displayName = (customName != null && customName.isNotEmpty)
        ? customName
        : (isFr ? 'Règle non nommée' : 'Unnamed Rule');

    final isCustomColor = customHeaderColor != null;
    final isLight = isCustomColor ? customHeaderColor.computeLuminance() > 0.5 : true;

    final Color headerTextColor = isCustomColor
        ? (isLight ? Colors.black87 : Colors.white)
        : theme.colorScheme.onSurface;

    final Color headerActionIconColor = isCustomColor
        ? (isLight ? Colors.black87 : Colors.white)
        : theme.colorScheme.onSurface;

    final Color avatarBgColor = isCustomColor
        ? (isLight ? Colors.black.withAlpha(26) : Colors.white.withAlpha(51))
        : (customIcon != null
            ? theme.colorScheme.primary.withAlpha(51)
            : theme.colorScheme.secondary.withAlpha(26));

    final Color avatarIconColor = isCustomColor
        ? (isLight ? Colors.black87 : Colors.white)
        : (customIcon != null
            ? theme.colorScheme.primary
            : theme.colorScheme.secondary);

    final headerDecoration = isCustomColor
        ? BoxDecoration(
            color: customHeaderColor,
            border: Border(
              bottom: BorderSide(
                color: isLight ? Colors.black.withAlpha(26) : Colors.white.withAlpha(26),
              ),
            ),
          )
        : BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withAlpha(51),
                theme.colorScheme.primary.withAlpha(13),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.primary.withAlpha(38),
              ),
            ),
          );

    Map<String, dynamic> singleRuleJson = {
      'action': widget.rule.action,
      'src': widget.rule.sources.map((e) => e.value).toList(),
      'dst': widget.rule.destinations
          .map((e) => '${e.value}${e.value.contains(':') ? '' : ':*'}')
          .toList(),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête personnalisé si défini
          if (hasCustomHeader)
            GestureDetector(
              onTap: () => _showBlockCustomizerDialog(context, sig),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: headerDecoration,
                child: Row(
                  children: [
                    if (imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync())
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: FileImage(File(imagePath)),
                      )
                    else if (customIcon != null)
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarBgColor,
                        child: Icon(customIcon, color: avatarIconColor, size: 20),
                      )
                    else
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarBgColor,
                        child: Icon(Icons.extension, color: avatarIconColor, size: 20),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: headerTextColor,
                        ),
                        softWrap: true,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.tune, size: 20, color: headerActionIconColor),
                      tooltip: isFr ? 'Personnaliser le bloc' : 'Customize block',
                      onPressed: () => _showBlockCustomizerDialog(context, sig),
                    ),
                  ],
                ),
              ),
            )
          else
            // Header par défaut minimal avec bouton de personnalisation
            GestureDetector(
              onTap: () => _showBlockCustomizerDialog(context, sig),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFr ? 'Règle non nommée' : 'Unnamed Rule',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, size: 18, color: Colors.grey),
                      tooltip: isFr ? 'Nommer ou illustrer le bloc' : 'Name or illustrate block',
                      onPressed: () => _showBlockCustomizerDialog(context, sig),
                    ),
                  ],
                ),
              ),
            ),

          // Partie visuelle interactive
          InkWell(
            onTap: () => _showDetailsDialog(context, isFr),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Sources
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.rule.sources
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Tooltip(
                                  message: isFr 
                                      ? 'Valeur: ${e.value}\n(Cliquer pour renommer)' 
                                      : 'Value: ${e.value}\n(Click to rename)',
                                  child: InkWell(
                                    onTap: () {
                                      _showEntityRenameDialog(context, e, () {
                                        setState(() {});
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withAlpha(60),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.primary.withAlpha(40),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getIconForType(e.type),
                                            size: 14,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getEntityLabel(context, e),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onPrimaryContainer,
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  // Flèche directionnelle
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_forward, color: Colors.green, size: 20),
                        const SizedBox(height: 2),
                        Text(
                          isFr ? 'AUTOR.' : 'ALLOW',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Destinations
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.rule.destinations
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Tooltip(
                                  message: isFr 
                                      ? 'Valeur: ${e.value}\n(Cliquer pour renommer)' 
                                      : 'Value: ${e.value}\n(Click to rename)',
                                  child: InkWell(
                                    onTap: () {
                                      _showEntityRenameDialog(context, e, () {
                                        setState(() {});
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer.withAlpha(60),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.colorScheme.secondary.withAlpha(40),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _getIconForType(e.type),
                                            size: 14,
                                            color: theme.colorScheme.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _getEntityLabel(context, e),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSecondaryContainer,
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: widget.onDelete,
                  )
                ],
              ),
            ),
          ),

          // Aperçu Code JSON
          InkWell(
            onTap: () {
              setState(() {
                _showCode = !_showCode;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                        fontSize: 11,
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
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: Text(
                const JsonEncoder.withIndent('  ').convert(singleRuleJson),
                style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.lightGreenAccent,
                    fontSize: 11),
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
                    label: Text(_getEntityLabel(context, e)),
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
            final alias = context.watch<AppProvider>().getEntityAlias(entity.value);
            final hasAlias = alias != null && alias.isNotEmpty;
            
            return ListTile(
              leading: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedList.add(entity);
                    } else {
                      selectedList.removeWhere((e) => e.id == entity.id);
                    }
                  });
                },
              ),
              title: Row(
                children: [
                  Icon(_getIconForType(entity.type), size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _wrapTextForWrapping(hasAlias ? alias : entity.displayLabel),
                      style: TextStyle(
                        fontWeight: hasAlias ? FontWeight.bold : FontWeight.normal,
                        color: hasAlias ? Theme.of(context).colorScheme.primary : null,
                      ),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                hasAlias 
                    ? '${entity.value} • ${isFr ? "Cliquer sur le crayon pour modifier" : "Click pencil to edit"}'
                    : (isFr ? "Cliquer sur le crayon pour donner un nom" : "Click pencil to name"),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: isFr ? 'Modifier le nom' : 'Edit name',
                onPressed: () {
                  _showEntityRenameDialog(context, entity, () {
                    setState(() {});
                  });
                },
              ),
              onTap: () {
                setState(() {
                  if (!isSelected) {
                    selectedList.add(entity);
                  } else {
                    selectedList.removeWhere((e) => e.id == entity.id);
                  }
                });
              },
              onLongPress: () {
                _showEntityRenameDialog(context, entity, () {
                  setState(() {});
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
