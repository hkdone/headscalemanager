import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
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
                  'Après avoir suivi l\'étape 1 sur votre appareil, le client Tailscale vous fournira une URL d\'enregistrement unique contenant une clé d\'identification unique. Collez cette URL compléte ou la clé d\'identification seule dans le champ ci-dessous pour enregistrer l\'appareil.'),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Coller l\'URL du client ici',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final trimmedValue = value.trim();
                  final Uri? uri = Uri.tryParse(trimmedValue);

                  // Essaye d'extraire la clé d'une URL complète
                  if (uri != null && uri.hasScheme && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'register') {
                    machineKey.value = uri.pathSegments[1];
                  } else {
                    // Sinon, suppose que l'entrée est la clé elle-même
                    machineKey.value = trimmedValue;
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
                          final newNode = await context.read<AppProvider>().apiService.registerMachine(key, user.name);
                          Navigator.of(dialogContext).pop(); // Close registration dialog
                          showSafeSnackBar(context, 'Appareil enregistré avec succès.');
                          // Show the new dialog to add ACL tags
                          _showAddTagsDialog(context, newNode);
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

/// Affiche un dialogue pour ajouter des tags ACL à un nœud nouvellement enregistré.
Future<void> _showAddTagsDialog(BuildContext context, Node node) async {
  bool isExitNode = false;
  bool isLanSharer = false;

  return showDialog(
    context: context,
    barrierDismissible: false, // User must make a choice
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Étape 3 : Ajouter des Tags ACL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configurez les capacités de "${node.name}".'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Exit Node'),
                  subtitle: const Text('Autoriser ce nœud à être une sortie internet.'),
                  value: isExitNode,
                  onChanged: (value) {
                    setState(() {
                      isExitNode = value!;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('LAN Sharer'),
                  subtitle: const Text('Autoriser ce nœud à partager son réseau local.'),
                  value: isLanSharer,
                  onChanged: (value) {
                    setState(() {
                      isLanSharer = value!;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Ignorer'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: const Text('Appliquer les Tags'),
                onPressed: () async {
                  final provider = context.read<AppProvider>();
                  String baseTag = 'tag:${normalizeUserName(node.user)}-client';
                  if (isExitNode) {
                    baseTag += ';exit-node';
                  }
                  if (isLanSharer) {
                    baseTag += ';lan-sharer';
                  }

                  try {
                    await provider.apiService.setTags(node.id, [baseTag]);
                    Navigator.of(dialogContext).pop();
                    showSafeSnackBar(context, 'Tags appliqués avec succès.');
                  } catch (e) {
                    showSafeSnackBar(context, 'Erreur lors de l\'application des tags: $e');
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
