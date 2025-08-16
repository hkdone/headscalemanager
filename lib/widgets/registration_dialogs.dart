import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

Future<void> showTailscaleUpCommandDialog(BuildContext context, User user) async { // Fonction renommée
  final appProvider = context.read<AppProvider>();
  final serverUrl = await appProvider.storageService.getServerUrl();
  if (serverUrl == null) {
    showSafeSnackBar(context, 'Erreur : URL du serveur non configurée.');
    return;
  }

  final String loginServer = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
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
          ElevatedButton( // Nouveau bouton pour l'étape suivante
            child: const Text('Étape suivante : Enregistrer la clé'),
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Fermer la boîte de dialogue actuelle
              showHeadscaleRegisterCommandDialog(context, user); // Ouvrir la nouvelle boîte de dialogue
            },
          ),
        ],
      );
    },
  );
}

// Nouvelle fonction pour l'étape 2
Future<void> showHeadscaleRegisterCommandDialog(BuildContext context, User user) async {
  final TextEditingController urlController = TextEditingController();
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
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL d\'enregistrement Web',
                border: OutlineInputBorder(),
              ),
              onChanged: (url) {
                // Analyser l'URL et générer la commande
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
              if (generatedCommand.value.startsWith('headscale')) { // Copier uniquement si la commande est valide
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