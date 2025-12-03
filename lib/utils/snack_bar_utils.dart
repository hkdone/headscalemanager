import 'package:flutter/material.dart';

/// Fonction utilitaire pour afficher un SnackBar en toute sécurité.
///
/// Cette fonction vérifie si le [BuildContext] est toujours monté avant d'afficher
/// le [SnackBar], évitant ainsi les erreurs potentielles si le widget a été
/// retiré de l'arborescence.
///
/// Le [SnackBar] est configuré avec un comportement flottant, une marge et
/// des bords arrondis pour une apparence cohérente dans toute l'application.
///
/// [context] : Le contexte de construction du widget.
/// [message] : Le message à afficher dans le [SnackBar].
void showSafeSnackBar(BuildContext context, String message) {
  // Vérifie si le contexte est toujours monté pour éviter les erreurs.
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior
            .floating, // Le SnackBar flotte au-dessus du contenu.
        margin: const EdgeInsets.all(12), // Marge autour du SnackBar.
        shape: RoundedRectangleBorder(
          // Forme du SnackBar avec des bords arrondis.
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
