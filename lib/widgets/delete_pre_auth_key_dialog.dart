import 'package:flutter/material.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint

/// Dialogue de confirmation pour la suppression d'une clé de pré-authentification.
///
/// Affiche un message de confirmation et, si l'utilisateur confirme,
/// supprime la clé via l'API Headscale.
class DeletePreAuthKeyDialog extends StatelessWidget {
  /// La clé de pré-authentification à supprimer.
  final PreAuthKey preAuthKey;

  /// Fonction de rappel appelée après la suppression réussie de la clé.
  final VoidCallback onKeyDeleted;

  const DeletePreAuthKeyDialog({
    super.key,
    required this.preAuthKey,
    required this.onKeyDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Supprimer la clé ?' : 'Delete key?'),
      content: Text(isFr
          ? 'Êtes-vous sûr de vouloir supprimer la clé ${preAuthKey.key} ?'
          : 'Are you sure you want to delete the key ${preAuthKey.key}?'),
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
              await provider.apiService
                  .expirePreAuthKey(preAuthKey.user!.id, preAuthKey.key);
              Navigator.of(context).pop(); // Ferme le dialogue de confirmation
              onKeyDeleted(); // Appelle le callback pour rafraîchir la liste
              showSafeSnackBar(context,
                  isFr ? 'Clé expirée avec succès.' : 'Key expired successfully.');
            } catch (e) {
              debugPrint('Erreur lors de l\'expiration de la clé : $e');
              Navigator.of(context).pop();
              showSafeSnackBar(
                  context,
                  isFr
                      ? 'Échec de l\'expiration de la clé : $e'
                      : 'Failed to expire key: $e');
            }
          },
        ),
      ],
    );
  }
}
