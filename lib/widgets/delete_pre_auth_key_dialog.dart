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

    return AlertDialog(
      title: const Text('Supprimer la clé ?'),
      content: Text('Êtes-vous sûr de vouloir supprimer la clé ${preAuthKey.key} ?'),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          onPressed: () async {
            try {
              await provider.apiService.expirePreAuthKey(preAuthKey.user!.id,preAuthKey.key);
              Navigator.of(context).pop(); // Ferme le dialogue de confirmation
              onKeyDeleted(); // Appelle le callback pour rafraîchir la liste
              showSafeSnackBar(context, 'Clé expirée avec succès.');
            } catch (e) {
              debugPrint('Erreur lors de l\'expiration de la clé : $e');
              Navigator.of(context).pop();
              showSafeSnackBar(context, 'Échec de l\'expiration de la clé : $e');
            }
          },
        ),
      ],
    );
  }
}