import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

/// Affiche un dialogue pour guider l'utilisateur dans l'enregistrement d'un appareil
/// en fournissant la commande `tailscale up`.
///
/// Cette fonction est la première étape du processus d'enregistrement d'un appareil.
/// Elle génère une commande `tailscale up` que l'utilisateur doit exécuter sur
/// l'appareil client.
///
/// [context] : Le contexte de construction du widget.
/// [user] : L'utilisateur sous lequel l'appareil sera enregistré.
Future<void> showTailscaleUpCommandDialog(BuildContext context, User user) async {
  final appProvider = context.read<AppProvider>();
  final serverUrl = await appProvider.storageService.getServerUrl();
  if (serverUrl == null) {
    showSafeSnackBar(context, 'Erreur : URL du serveur non configurée.');
    return;
  }

  // Construit l'URL du serveur de connexion, en supprimant le slash final si présent.
  final String loginServer = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
  // Construit la commande Tailscale à exécuter sur l'appareil client.
  final String command = 'tailscale up --login-server=$loginServer';

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Étape 1 : Exécuter sur l\'appareil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Copiez la commande ci-dessous et exécutez-la sur l\'appareil que vous souhaitez enregistrer. Ensuite, fournissez le lien web généré à cette application pour l\'étape suivante.'),
            const SizedBox(height: 16),
            // Affiche la commande Tailscale, rendue sélectionnable pour la copie.
            SelectableText(
              command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Fermer'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('Copier la commande'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: command));
              showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
            },
          ),
          // Bouton pour passer à la deuxième étape du processus d'enregistrement.
          ElevatedButton(
            child: const Text('Étape suivante : Enregistrer la clé'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Ferme la boîte de dialogue actuelle.
              showHeadscaleRegisterCommandDialog(context, user); // Ouvre la nouvelle boîte de dialogue.
            },
          ),
        ],
      );
    },
  );
}

/// Affiche un dialogue pour guider l'utilisateur dans l'enregistrement de la clé
/// générée par l'appareil sur le serveur Headscale.
///
/// Cette fonction est la deuxième étape du processus d'enregistrement d'un appareil.
/// Elle demande à l'utilisateur de coller le lien web obtenu de l'appareil client
/// et génère la commande `headscale nodes register` correspondante.
///
/// [context] : Le contexte de construction du widget.
/// [user] : L'utilisateur sous lequel l'appareil sera enregistré.
Future<void> showHeadscaleRegisterCommandDialog(BuildContext context, User user) async {
  final TextEditingController urlController = TextEditingController();
  // Notifier de valeur pour la commande générée, mis à jour dynamiquement.
  final ValueNotifier<String> generatedCommand = ValueNotifier<String>('');

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Étape 2 : Enregistrer la clé sur Headscale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collez le lien web généré par l\'appareil ici :'),
            const SizedBox(height: 8),
            // Champ de texte pour coller l\'URL d\'enregistrement.
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL d\'enregistrement Web',
                border: OutlineInputBorder(),
              ),
              onChanged: (url) {
                // Analyse l\'URL pour extraire la clé et générer la commande Headscale.
                final Uri? uri = Uri.tryParse(url);
                if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'register') {
                  final String key = uri.pathSegments[1];
                  generatedCommand.value = 'headscale nodes register --user ${user.name} --key $key';
                } else {
                  generatedCommand.value = 'Format d\'URL invalide';
                }
              },
            ),
            const SizedBox(height: 16),
            // Affiche la commande Headscale générée, mise à jour en temps réel.
            ValueListenableBuilder<String>(
              valueListenable: generatedCommand,
              builder: (ctx, cmd, child) {
                return SelectableText(
                  cmd,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Fermer'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('Copier la commande'),
            onPressed: () async {
              // Copie la commande uniquement si elle est valide.
              if (generatedCommand.value.startsWith('headscale')) {
                await Clipboard.setData(ClipboardData(text: generatedCommand.value));
                showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
              } else {
                showSafeSnackBar(context, 'Impossible de copier une commande invalide.');
              }
            },
          ),
        ],
      );
    },
  );
}