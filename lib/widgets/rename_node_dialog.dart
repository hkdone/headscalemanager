import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Dialogue pour renommer un nœud Headscale.
///
/// Permet à l'utilisateur de saisir un nouveau nom pour le nœud.
class RenameNodeDialog extends StatefulWidget {
  /// Le nœud à renommer.
  final Node node;

  /// Fonction de rappel appelée après le renommage réussi du nœud.
  final VoidCallback onNodeRenamed;

  const RenameNodeDialog({super.key, required this.node, required this.onNodeRenamed});

  @override
  State<RenameNodeDialog> createState() => _RenameNodeDialogState();
}

class _RenameNodeDialogState extends State<RenameNodeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newNameController.text = widget.node.name;
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return AlertDialog(
      title: const Text('Renommer l\'appareil'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _newNameController,
          decoration: const InputDecoration(
            labelText: 'Nouveau nom d\'appareil',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer un nouveau nom';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Renommer'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newName = _newNameController.text.toLowerCase();
              try {
                await provider.apiService.renameNode(widget.node.id, newName);
                Navigator.of(context).pop(); // Ferme le dialogue
                widget.onNodeRenamed(); // Appelle le callback pour rafraîchir la liste
                showSafeSnackBar(context, 'Appareil renommé avec succès.');
              } catch (e) {
                debugPrint('Erreur lors du renommage de l\'appareil : $e');
                if (!mounted) return;
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Échec du renommage de l\'appareil : $e');
              }
            }
          },
        ),
      ],
    );
  }
}
