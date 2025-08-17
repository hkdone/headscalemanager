import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Dialogue pour créer un nouvel utilisateur Headscale.
///
/// Permet à l'utilisateur de saisir un nom d'utilisateur. Le dialogue gère
/// la logique d'ajout du suffixe de domaine et l'appel à l'API Headscale.
class CreateUserDialog extends StatefulWidget {
  /// Fonction de rappel appelée après la création réussie de l'utilisateur.
  final VoidCallback onUserCreated;

  const CreateUserDialog({super.key, required this.onUserCreated});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();

    return AlertDialog(
      title: const Text('Créer un utilisateur'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(hintText: "Nom de l'utilisateur"),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Créer'),
          onPressed: () async {
            final String name = _nameController.text.trim();
            final serverUrl = await appProvider.storageService.getServerUrl();
            final String? baseDomain = serverUrl?.extractBaseDomain();

            String suffix = '';
            if (baseDomain != null && baseDomain.isNotEmpty) {
              suffix = '@$baseDomain';
            } else {
              // Fallback if base domain cannot be extracted
              suffix = '@headscale.local'; // A generic fallback
            }

            if (name.isNotEmpty) {
              String finalName = name;
              if (!name.contains('@')) { // Only append suffix if no @ is present
                finalName = '$name$suffix';
              }

              try {
                await appProvider.apiService.createUser(finalName);
                Navigator.of(context).pop(); // Close the dialog
                widget.onUserCreated(); // Call the callback to refresh user list
              } catch (e) {
                debugPrint('Erreur lors de la création de l\'utilisateur : $e');
                if (!mounted) return;
                Navigator.of(context).pop(); // Close the dialog even on error
                showSafeSnackBar(context, 'Échec de la création de l\'utilisateur : $e');
              }
            }
          },
        ),
      ],
    );
  }
}
