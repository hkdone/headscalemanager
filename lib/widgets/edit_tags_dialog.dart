import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

class EditTagsDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onTagsUpdated;

  const EditTagsDialog({
    super.key,
    required this.node,
    required this.onTagsUpdated,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = _consolidateTags(List.from(widget.node.tags));
  }

  List<String> _consolidateTags(List<String> tags) {
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
    return _currentTags
        .firstWhere((t) => t.contains('-client'), orElse: () => '')
        .replaceFirst('tag:', '');
  }

  bool hasCapabilityTag(String capability) {
    return baseTag.split(';').contains(capability);
  }

  void _updateCapability(String capability, {required bool add}) {
    setState(() {
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
        parts.add(capability);
      } else {
        parts.remove(capability);
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
            showSafeSnackBar(context, isFr ? 'Aucun serveur actif sélectionné.' : 'No active server selected.');
            return;
          }
          final tempRules = await appProvider.storageService.getTemporaryRules(serverId);
          final aclGenerator = NewAclGeneratorService();
          final newPolicyMap = aclGenerator.generatePolicy(
              users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          final newPolicyJson = jsonEncode(newPolicyMap);
          await apiService.setAclPolicy(newPolicyJson);

          showSafeSnackBar(
              context, isFr ? 'ACLs mises à jour !' : 'ACLs updated!');
        }
      }

      // Final actions
      widget.onTagsUpdated();
      Navigator.of(context).pop();
    } catch (e) {
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
              Text(isFr
                  ? 'Aucun tag de base de type "-client" trouvé. La modification guidée n\'est pas disponible.'
                  : 'No base "-client" tag found. Guided editing is not available.')
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
