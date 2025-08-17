import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Dialogue pour modifier les tags d'un nœud.
///
/// Permet à l'utilisateur de saisir des tags sous forme de liste séparée par des virgules.
/// Valide le format des tags et génère une commande CLI pour appliquer les changements.
class EditTagsDialog extends StatefulWidget {
  /// Le nœud dont les tags doivent être modifiés.
  final Node node;

  // Removed onCliCommandGenerated as it's no longer needed.
  // The dialog now returns the command directly via Navigator.pop.

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
    _tagsController.text = widget.node.tags.join(', ');
  }

  @override
  void dispose() {
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: const Text('Générer Commande CLI'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final tagsString = _tagsController.text.trim();
              final newTagsList = tagsString.isNotEmpty
                  ? tagsString.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
                  : <String>[];

              // Construire la commande CLI
              // headscale nodes tag -i <identifiant> -t tag:<tag1> -t tag:<tag2> ...
              String cliCommand = 'headscale nodes tag -i ${widget.node.id}';
              if (newTagsList.isNotEmpty) {
                for (final tag in newTagsList) {
                  cliCommand += ' -t "tag:$tag"';
                }
              }
              // Si newTagsList est vide, aucun drapeau -t n'est ajouté, ce qui efface les tags existants.
              debugPrint('Generated CLI Command: $cliCommand'); // Impression de diagnostic

              // Pop avec la commande générée
              Navigator.of(context).pop(cliCommand);
            }
          },
        ),
      ],
    );
  }
}