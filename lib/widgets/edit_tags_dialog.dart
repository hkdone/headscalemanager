import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

/// Dialogue pour modifier les tags d'un nœud.
///
/// Permet à l'utilisateur de saisir des tags sous forme de liste séparée par des virgules.
/// Valide le format des tags et met à jour les tags via l'API.
class EditTagsDialog extends StatefulWidget {
  /// Le nœud dont les tags doivent être modifiés.
  final Node node;

  const EditTagsDialog({
    super.key,
    required this.node,
  });

  @override
  State<EditTagsDialog> createState() => _EditTagsDialogState();
}

class _EditTagsDialogState extends State<EditTagsDialog> {
  final TextEditingController _tagsController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // remove "tag:" prefix before displaying
    _tagsController.text = widget.node.tags.map((t) => t.startsWith('tag:') ? t.substring(4) : t).join(', ');
  }

  @override
  void dispose() {
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiProvider = Provider.of<AppProvider>(context, listen: false);
    return AlertDialog(
      title: const Text('Modifier les tags'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _tagsController,
          decoration: const InputDecoration(
            hintText: 'Tags (minuscules, sans chiffres/espaces/spéciaux, séparés par des virgules)',
            labelText: 'Tags',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return null; // Empty is valid (clears tags)
            }
            final rawTags = value.split(',').map((t) => t.trim()).toList();
            final RegExp validTagPattern = RegExp(r'^[a-z]+$'); // Validation des tags Headscale

            List<String> invalidTagsExamples = [];
            bool allTagsValid = true;

            for (String tag in rawTags) {
              if (tag.isNotEmpty) {
                if (!validTagPattern.hasMatch(tag)) {
                  allTagsValid = false;
                  if (invalidTagsExamples.length < 3) {
                    invalidTagsExamples.add(tag);
                  }
                }
              }
            }

            if (!allTagsValid) {
              return 'Tags invalides : ${invalidTagsExamples.join(", ")}. Uniquement lettres minuscules, sans chiffres, espaces ou caractères spéciaux.';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(), // Pop with null
        ),
        TextButton(
          child: const Text('Sauvegarder'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final tagsString = _tagsController.text.trim();
              final newTagsList = tagsString.isNotEmpty
                  ? tagsString.split(',').map((t) => 'tag:${t.trim()}').where((t) => t.length > 4).toList()
                  : <String>[];

              try {
                await apiProvider.apiService.setTags(widget.node.id, newTagsList);
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Tags mis à jour avec succès.');
              } catch (e) {
                showSafeSnackBar(context, 'Erreur lors de la mise à jour des tags: $e');
              }
            }
          },
        ),
      ],
    );
  }
}