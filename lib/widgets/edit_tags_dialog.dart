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
    _currentTags = List.from(widget.node.tags);
  }

  String get baseTag {
    return _currentTags
        .firstWhere((t) => t.endsWith('-client'), orElse: () => '')
        .replaceFirst('tag:', '');
  }

  bool hasCapabilityTag(String capability) {
    return baseTag.contains(';$capability');
  }

  void _addCapability(String capability) {
    final base = baseTag;
    if (base.isNotEmpty && !base.contains(';$capability')) {
      setState(() {
        final oldTag = 'tag:$base';
        final newTag = 'tag:$base;$capability';
        _currentTags.remove(oldTag);
        _currentTags.add(newTag);
      });
    }
  }

  void _removeCapability(String capability) {
    final base = baseTag;
    if (base.isNotEmpty && base.contains(';$capability')) {
      setState(() {
        final oldTag = 'tag:$base';
        final newTag = 'tag:${base.replaceAll(';$capability', '')}';
        _currentTags.remove(oldTag);
        _currentTags.add(newTag);
      });
    }
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
          showSafeSnackBar(context, isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');
          final allUsers = await apiService.getUsers();
          final allNodes = await apiService.getNodes();
          final tempRules = await context.read<AppProvider>().storageService.getTemporaryRules();
          final aclGenerator = NewAclGeneratorService();
          final newPolicyMap = aclGenerator.generatePolicy(
              users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          final newPolicyJson = jsonEncode(newPolicyMap);
          await apiService.setAclPolicy(newPolicyJson);

          showSafeSnackBar(context, isFr ? 'ACLs mises à jour !' : 'ACLs updated!');
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
              children: _currentTags.map((tag) => Chip(label: Text(tag))).toList(),
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
                  label: Text(isFr ? 'Retirer ;exit-node' : 'Remove ;exit-node'),
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
                  label: Text(isFr ? 'Retirer ;lan-sharer' : 'Remove ;lan-sharer'),
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
