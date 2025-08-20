import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

/// Affiche un dialogue pour guider l'utilisateur dans l'enregistrement d'un appareil
/// en fournissant la commande `tailscale up` ou l'URL du serveur.
///
/// Cette fonction est la première étape du processus d'enregistrement d'un appareil.
/// Elle présente des onglets pour différents systèmes d'exploitation.
Future<void> showTailscaleUpCommandDialog(BuildContext context, User user) async {
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
      return DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: const Text('Étape 1 : Connecter l\'appareil'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Windows/Linux/macOS'),
                    Tab(text: 'iOS/Android'),
                  ],
                ),
                SizedBox(
                  height: 200, // Adjust height as needed
                  child: TabBarView(
                    children: [
                      // Tab for Windows/Linux/macOS
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Exécutez la commande suivante dans le terminal de votre appareil:'),
                            const SizedBox(height: 16),
                            SelectableText(
                              command,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.copy),
                              label: const Text('Copier la commande'),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: command));
                                showSafeSnackBar(context, 'Commande copiée !');
                              },
                            ),
                          ],
                        ),
                      ),
                      // Tab for iOS/Android
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                  'Sur votre appareil, allez dans les paramètres du client Tailscale, sélectionnez "Use alternate server" et entrez l\'URL suivante:'),
                              const SizedBox(height: 16),
                              SelectableText(
                                loginServer,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.copy),
                                label: const Text('Copier l\'URL'),
                                onPressed: () async {
                                  await Clipboard.setData(ClipboardData(text: loginServer));
                                  showSafeSnackBar(context, 'URL copiée !');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Fermer'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Étape suivante'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showHeadscaleRegisterCommandDialog(context, user);
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Affiche un dialogue pour la deuxième étape de l'enregistrement de l'appareil.
///
/// Guide l'utilisateur pour coller le lien web obtenu du client Tailscale
/// et génère la commande `headscale nodes register` à exécuter sur le serveur.
Future<void> showHeadscaleRegisterCommandDialog(BuildContext context, User user) async {
  final TextEditingController urlController = TextEditingController();
  final ValueNotifier<String> machineKey = ValueNotifier<String>('');

  return showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Étape 2 : Enregistrer l\'appareil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Après avoir suivi l\'étape 1 sur votre appareil, le client Tailscale vous fournira une URL d\'enregistrement unique. Collez cette URL ci-dessous pour enregistrer l\'appareil.'),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Coller l\'URL du client ici',
                  border: OutlineInputBorder(),
                ),
                onChanged: (url) {
                  final Uri? uri = Uri.tryParse(url);
                  if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'register') {
                    machineKey.value = uri.pathSegments[1];
                  } else {
                    machineKey.value = '';
                  }
                },
              ),
            ],
          ),
        ),

              actions: [
          TextButton(
            child: const Text('Fermer'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ValueListenableBuilder<String>(
            valueListenable: machineKey,
            builder: (ctx, key, child) {
              return ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer sur le serveur'),
                onPressed: key.isEmpty
                    ? null
                    : () async {
                        try {
                          await context.read<AppProvider>().apiService.registerMachine(key, user.name);
                          Navigator.of(dialogContext).pop();
                          showSafeSnackBar(context, 'Appareil enregistré avec succès.');
                        } catch (e) {
                          showSafeSnackBar(context, 'Erreur lors de l\'enregistrement: $e');
                        }
                      },
              );
            },
          ),
        ],
      );
    },
  );
}

