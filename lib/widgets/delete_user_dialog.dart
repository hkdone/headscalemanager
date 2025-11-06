import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint

/// Dialogue de confirmation pour la suppression d'un utilisateur.
///
/// Affiche un message de confirmation et, si l'utilisateur confirme,
/// supprime l'utilisateur via l'API Headscale.
class DeleteUserDialog extends StatelessWidget {
  /// L'utilisateur à supprimer.
  final User user;

  /// Fonction de rappel appelée après la suppression réussie de l'utilisateur.
  final VoidCallback onUserDeleted;

  const DeleteUserDialog({
    super.key,
    required this.user,
    required this.onUserDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Supprimer l\'utilisateur ?' : 'Delete user?'),
      content: Text(isFr
          ? 'Êtes-vous sûr de vouloir supprimer ${user.name} ?\n\nNote : La suppression échouera si l\'utilisateur possède encore des appareils.'
          : 'Are you sure you want to delete ${user.name}?\n\nNote: Deletion will fail if the user still owns devices.'),
      actions: [
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(isFr ? 'Supprimer' : 'Delete',
              style: const TextStyle(color: Colors.red)),
          onPressed: () async {
            try {
              await provider.apiService.deleteUser(user.id);
              Navigator.of(context).pop(); // Ferme le dialogue de confirmation
              onUserDeleted(); // Appelle le callback pour rafraîchir la liste
              showSafeSnackBar(
                  context,
                  isFr
                      ? 'Utilisateur ${user.name} supprimé.'
                      : 'User ${user.name} deleted.');
            } catch (e) {
              debugPrint('Erreur lors de la suppression de l\'utilisateur : $e');
              Navigator.of(context).pop();
              showSafeSnackBar(
                  context,
                  isFr
                      ? 'Échec de la suppression de l\'utilisateur : $e'
                      : 'Failed to delete user: $e');
            }
          },
        ),
      ],
    );
  }
}
