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
              // Étape 2 : Vérification des collisions
              final existingUsers = await appProvider.apiService.getUsers();
              final normalizedNewName = normalizeUserName(finalName);

              bool collision = false;
              String suggestedName = '';

              for (var existingUser in existingUsers) {
                if (existingUser.name.toLowerCase() ==
                        finalName.toLowerCase() ||
                    normalizeUserName(existingUser.name) == normalizedNewName) {
                  collision = true;
                  // Suggestion de nom simple
                  suggestedName = '${name}1';
                  break;
                }
              }

              if (collision && context.mounted) {
                final bool? proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(isFr ? 'Conflit détecté' : 'Conflict detected'),
                    content: Text(isFr
                        ? 'Un utilisateur avec ce nom ou générant le même tag existe déjà. Voulez-vous essayer avec "$suggestedName" ?'
                        : 'A user with this name or generating the same tag already exists. Would you like to try with "$suggestedName" ?'),
                    actions: [
                      TextButton(
                        child: Text(isFr ? 'Annuler' : 'Cancel'),
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                      TextButton(
                        child: Text(isFr
                            ? 'Utiliser $suggestedName'
                            : 'Use $suggestedName'),
                        onPressed: () {
                          _nameController.text = suggestedName;
                          Navigator.of(ctx).pop(true);
                        },
                      ),
                    ],
                  ),
                );
                if (proceed != true) return;
                // Si on a changé le nom, on relance la logique de création avec le nouveau nom au prochain clic ou on peut boucler ici.
                // Pour faire simple, on s'arrête là et l'utilisateur reclique sur "Créer" après la mise à jour du texte.
                return;
              }

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
