import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';

class EditTagsDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onTagsUpdated;
  final String? fallbackUser;

  const EditTagsDialog({
    super.key,
    required this.node,
    required this.onTagsUpdated,
    this.fallbackUser,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    // In legacy mode, we consolidate tags on load to present them cleanly.
    // In standard mode, we treat tags as they are.
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;
    if (useStandardEngine) {
      _currentTags = List.from(widget.node.tags);
    } else {
      _currentTags = _consolidateTags(List.from(widget.node.tags));
    }
  }

  List<String> _consolidateTags(List<String> tags) {
    // Only used in Legacy Mode
    final clientTagIndex = tags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex == -1) {
      return tags;
    }

    final clientTag = tags[clientTagIndex];
    final clientTagParts = clientTag
        .replaceFirst('tag:', '')
        .split(';')
        .where((p) => p.isNotEmpty)
        .toSet();

    final otherTags = <String>[];

    for (int i = 0; i < tags.length; i++) {
      if (i == clientTagIndex) continue;
      final tag = tags[i];
      final cleanTag = tag.replaceFirst('tag:', '');

      if (cleanTag == 'exit-node' || cleanTag == 'lan-sharer') {
        clientTagParts.add(cleanTag);
      } else {
        otherTags.add(tag);
      }
    }

    final clientPart = clientTagParts.firstWhere((p) => p.contains('-client'),
        orElse: () => '');
    if (clientPart.isEmpty) return tags;

    final capabilities = clientTagParts.where((p) => p != clientPart).toList()
      ..sort();

    final newClientTagBuilder = StringBuffer('tag:$clientPart');
    if (capabilities.isNotEmpty) {
      newClientTagBuilder.write(';${capabilities.join(';')}');
    }

    return [newClientTagBuilder.toString(), ...otherTags.toSet()];
  }

  String get baseTag {
    // Finds the "main" user tag, e.g. tag:bob-client
    return _currentTags
        .firstWhere((t) => t.contains('-client') && !t.contains(';'),
            orElse: () => _currentTags.firstWhere((t) => t.contains('-client'),
                orElse: () => ''))
        .split(';')
        .first // In case of legacy tag, take the first part
        .replaceFirst('tag:', '');
  }

  bool hasCapabilityTag(String capability) {
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;
    if (useStandardEngine) {
      // Check for explicit tag:user-capability
      final userBase = baseTag.replaceAll('-client', ''); // e.g. 'bob'
      return _currentTags.contains('tag:$userBase-$capability');
    } else {
      // Legacy check inside fused tag
      final clientTag = _currentTags.firstWhere((t) => t.contains('-client'),
          orElse: () => '');
      return clientTag.split(';').contains(capability);
    }
  }

  void _updateCapability(String capability, {required bool add}) {
    final useStandardEngine = context.read<AppProvider>().useStandardAclEngine;

    setState(() {
      if (useStandardEngine) {
        // STANDARD MODE: Add/Remove separate tags
        final userBase = baseTag.replaceAll('-client', '');
        final capabilityTag = 'tag:$userBase-$capability'.toLowerCase();

        if (add) {
          if (!_currentTags.contains(capabilityTag)) {
            _currentTags.add(capabilityTag);
          }
        } else {
          _currentTags.remove(capabilityTag);
        }
      } else {
        // LEGACY MODE: Merge into semicolon tag
        final clientTagIndex =
            _currentTags.indexWhere((t) => t.contains('-client'));
        if (clientTagIndex == -1) return;

        final oldClientTag = _currentTags[clientTagIndex];
        final parts = oldClientTag
            .replaceFirst('tag:', '')
            .split(';')
            .where((p) => p.isNotEmpty)
            .toSet();

        if (add) {
          parts.add(capability.toLowerCase());
        } else {
          parts.remove(capability.toLowerCase());
        }

        final clientPart =
            parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
        if (clientPart.isEmpty) return;

        final otherParts = parts.where((p) => p != clientPart).toList()..sort();

        final newClientTagBuilder = StringBuffer('tag:$clientPart');
        if (otherParts.isNotEmpty) {
          newClientTagBuilder.write(';${otherParts.join(';')}');
        }

        _currentTags[clientTagIndex] = newClientTagBuilder.toString();
      }
    });
  }

  void _addCapability(String capability) {
    _updateCapability(capability, add: true);
  }

  void _removeCapability(String capability) {
    _updateCapability(capability, add: false);
  }

  Future<void> _handleSave() async {
    final apiService = context.read<AppProvider>().apiService;
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';

    try {
      // Save tags first
      await apiService.setTags(widget.node.id, _currentTags);
      if (!mounted) return;
      showSafeSnackBar(context, isFr ? 'Tags mis à jour.' : 'Tags updated.');

      // Check for ACL mode
      bool aclMode = true;
      try {
        await apiService.getAclPolicy();
      } catch (e) {
        aclMode = false;
      }

      if (aclMode && mounted) {
        // Ask for ACL update
        final bool? updateAcls = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isFr ? 'Mettre à jour les ACLs ?' : 'Update ACLs?'),
            content: Text(isFr
                ? 'Voulez-vous régénérer et appliquer la politique ACL pour que ces changements prennent effet ?'
                : 'Do you want to regenerate and apply the ACL policy for these changes to take effect?'),
            actions: [
              TextButton(
                child: Text(isFr ? 'Non' : 'No'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text(isFr ? 'Oui' : 'Yes'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (updateAcls == true && mounted) {
          showSafeSnackBar(
              context, isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');
          final appProvider = context.read<AppProvider>();
          final allUsers = await apiService.getUsers();
          final allNodes = await apiService.getNodes();
          final serverId = appProvider.activeServer?.id;
          if (serverId == null) {
            if (!mounted) return;
            showSafeSnackBar(
                context,
                isFr
                    ? 'Aucun serveur actif sélectionné.'
                    : 'No active server selected.');
            return;
          }
          final tempRules =
              await appProvider.storageService.getTemporaryRules(serverId);

          Map<String, dynamic> newPolicyMap;
          if (appProvider.useStandardAclEngine) {
            // Use New Standard Engine
            final aclGenerator = StandardAclGeneratorService();
            newPolicyMap = aclGenerator.generatePolicy(
                users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          } else {
            // Use Legacy Engine
            final aclGenerator = NewAclGeneratorService();
            newPolicyMap = aclGenerator.generatePolicy(
                users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          }

          final newPolicyJson = jsonEncode(newPolicyMap);
          await apiService.setAclPolicy(newPolicyJson);

          if (!mounted) return;
          showSafeSnackBar(
              context, isFr ? 'ACLs mises à jour !' : 'ACLs updated!');
        }
      }

      // Final actions
      widget.onTagsUpdated();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      showSafeSnackBar(context, isFr ? 'Échec: $e' : 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    final clientTag = baseTag;
    final hasExitNode = hasCapabilityTag('exit-node');
    final hasLanSharer = hasCapabilityTag('lan-sharer');

    return AlertDialog(
      title: Text(isFr ? 'Modifier les tags' : 'Edit tags'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFr
                          ? 'Note : Avec Headscale v0.26+, les tags sont stricts. Un appareil ne peut plus être "dé-tagué" une fois tagué.'
                          : 'Note: With Headscale v0.26+, tags are strict. A device cannot be "un-tagged" once tagged.',
                      style: const TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            Text(isFr ? 'Tags Actuels' : 'Current Tags',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children:
                  _currentTags.map((tag) => Chip(label: Text(tag))).toList(),
            ),
            const SizedBox(height: 24),
            Text(isFr ? 'Suggestions' : 'Suggestions',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (clientTag.isNotEmpty) ...[
              if (!hasExitNode)
                ElevatedButton.icon(
                  onPressed: () => _addCapability('exit-node'),
                  icon: const Icon(Icons.add),
                  label: Text(isFr ? 'Ajouter ;exit-node' : 'Add ;exit-node'),
                ),
              if (hasExitNode)
                ElevatedButton.icon(
                  onPressed: () => _removeCapability('exit-node'),
                  icon: const Icon(Icons.remove),
                  label:
                      Text(isFr ? 'Retirer ;exit-node' : 'Remove ;exit-node'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              const SizedBox(height: 8),
              if (!hasLanSharer)
                ElevatedButton.icon(
                  onPressed: () => _addCapability('lan-sharer'),
                  icon: const Icon(Icons.add),
                  label: Text(isFr ? 'Ajouter ;lan-sharer' : 'Add ;lan-sharer'),
                ),
              if (hasLanSharer)
                ElevatedButton.icon(
                  onPressed: () => _removeCapability('lan-sharer'),
                  icon: const Icon(Icons.remove),
                  label:
                      Text(isFr ? 'Retirer ;lan-sharer' : 'Remove ;lan-sharer'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
            ] else ...[
              Text(
                  isFr
                      ? 'Aucun tag trouvé. Pour intégrer cet appareil aux ACLs, il doit avoir un tag d\'identité.'
                      : 'No tags found. To include this device in ACLs, it must have an identity tag.',
                  style: const TextStyle(color: Colors.orange)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  // Auto-generate tag based on User Name
                  String rawName = widget.node.user;
                  // Si le nom du noeud est invalide (ex: N/A sur OIDC), on utilise le fallback (nom de l'utilisateur parent)
                  if (rawName == 'N/A' || rawName.isEmpty) {
                    rawName = widget.fallbackUser ?? 'user';
                  }

                  // Optimize: supports email-style names (jean@domain.com -> jean)
                  // normalizeUserName vient de string_utils.dart
                  String userName = normalizeUserName(rawName);
                  if (userName.isEmpty) userName = 'user';

                  final defaultTag = 'tag:$userName-client';

                  setState(() {
                    _currentTags.add(defaultTag);
                  });
                },
                icon: const Icon(Icons.auto_fix_high),
                label: Builder(builder: (context) {
                  // Calculer le nom affiché sur le bouton dynamiquement pour que l'utilisateur voit ce qu'il va obtenir
                  String rawName = widget.node.user;
                  if (rawName == 'N/A' || rawName.isEmpty) {
                    rawName = widget.fallbackUser ?? 'user';
                  }
                  String userName = normalizeUserName(rawName);
                  if (userName.isEmpty) userName = 'user';

                  return Text(isFr
                      ? 'Initialiser le Tag (tag:$userName-client)'
                      : 'Initialize Tag (tag:$userName-client)');
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleSave,
          child: Text(isFr ? 'Sauvegarder' : 'Save'),
        ),
      ],
    );
  }
}
