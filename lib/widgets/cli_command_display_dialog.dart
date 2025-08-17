import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:headscalemanager/utils/snack_bar_utils.dart'; // For showSafeSnackBar

/// Dialogue pour afficher une commande CLI générée et permettre de la copier.
///
/// Ce dialogue est utilisé pour présenter à l'utilisateur une commande à exécuter
/// manuellement (par exemple, sur un serveur Headscale) et offre une option
/// pour copier cette commande dans le presse-papiers.
class CliCommandDisplayDialog extends StatelessWidget {
  /// La commande CLI à afficher.
  final String command;

  const CliCommandDisplayDialog({super.key, required this.command});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Commande CLI'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            const Text(
                'Veuillez copier cette commande et l\'exécuter dans votre terminal où la CLI `headscale` est configurée.'),
            const SizedBox(height: 16),
            SelectableText(
              command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Fermer'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copier la commande CLI'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: command));
            showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
            Navigator.of(context).pop(); // Ferme le dialogue après copie
          },
        ),
      ],
    );
  }
}
