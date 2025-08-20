import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

/// Dialogue pour renommer un nœud.
///
/// Permet à l'utilisateur de saisir un nouveau nom pour le nœud.
/// Valide le nouveau nom et appelle l'API pour renommer le nœud.
class RenameNodeDialog extends StatefulWidget {
  /// Le nœud à renommer.
  final Node node;

  /// Fonction de rappel appelée après le renommage du nœud.
  final VoidCallback onNodeRenamed;

  const RenameNodeDialog({
    super.key,
    required this.node,
    required this.onNodeRenamed,
  });

  @override
  State<RenameNodeDialog> createState() => _RenameNodeDialogState();
}

class _RenameNodeDialogState extends State<RenameNodeDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.node.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renommer l\'appareil'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nouveau nom',
            hintText: 'Entrez le nouveau nom de l\'appareil',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Le nom ne peut pas être vide.';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Renommer'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newName = _nameController.text.trim();
              try {
                await context.read<AppProvider>().apiService.renameNode(widget.node.id, newName);
                widget.onNodeRenamed();
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Appareil renommé avec succès.');
              } catch (e) {
                showSafeSnackBar(context, 'Erreur lors du renommage: $e');
              }
            }
          },
        ),
      ],
    );
  }
}