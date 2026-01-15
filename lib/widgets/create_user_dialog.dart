import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint

/// Dialogue pour créer un nouvel utilisateur Headscale.
///
/// Permet à l'utilisateur de saisir un nom d'utilisateur. Le dialogue gère
/// la logique d'ajout du suffixe de domaine et l'appel à l'API Headscale.
class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Créer un utilisateur' : 'Create user'),
      content: TextField(
        controller: _nameController,
        decoration: InputDecoration(
            hintText: isFr ? 'Nom de l\'utilisateur' : 'Username'),
      ),
      actions: [
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(isFr ? 'Créer' : 'Create'),
          onPressed: () async {
            final String name = _nameController.text.trim();
            if (name.isEmpty) {
              Navigator.of(context).pop(false);
              return;
            }

            final serverUrl = appProvider.activeServer?.url;
            final String? baseDomain = serverUrl?.extractBaseDomain();

            String suffix = '';
            if (baseDomain != null && baseDomain.isNotEmpty) {
              suffix = '@$baseDomain';
            } else {
              suffix = '@headscale.local'; // A generic fallback
            }

            String finalName = name;
            if (!name.contains('@')) {
              finalName = '$name$suffix';
            }

            try {
              await appProvider.apiService.createUser(finalName);
              if (context.mounted) {
                Navigator.of(context).pop(true); // Success
              }
            } catch (e) {
              debugPrint('Erreur lors de la création de l\'utilisateur : $e');
              if (context.mounted) {
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Échec de la création de l\'utilisateur : $e'
                        : 'Failed to create user: $e');
                Navigator.of(context).pop(false); // Failure
              }
            }
          },
        ),
      ],
    );
  }
}
