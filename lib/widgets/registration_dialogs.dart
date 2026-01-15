import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
Future<void> showTailscaleUpCommandDialog(
    BuildContext context, User user) async {
  final appProvider = context.read<AppProvider>();
  final serverUrl = appProvider.activeServer?.url;
  if (serverUrl == null) {
    showSafeSnackBar(context, 'Erreur : URL du serveur non configurée.');
    return;
  }

  final String loginServer = serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;
  final String command = 'tailscale up --login-server=$loginServer';

  return showDialog(
    context: context,
    builder: (dialogContext) {
      final locale = context.watch<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      return DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: Text(isFr
              ? 'Étape 1 : Connecter l\'appareil'
              : 'Step 1: Connect Device'),
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
                            Text(isFr
                                ? 'Exécutez la commande suivante dans le terminal de votre appareil:'
                                : 'Run the following command in your device\'s terminal:'),
                            const SizedBox(height: 16),
                            SelectableText(
                              command,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.copy),
                                  label: Text(isFr ? 'Copier' : 'Copy'),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: command));
                                    if (!context.mounted) return;
                                    showSafeSnackBar(
                                        context,
                                        isFr
                                            ? 'Commande copiée !'
                                            : 'Command copied!');
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.share),
                                  label: Text(isFr ? 'Partager' : 'Share'),
                                  onPressed: () {
                                    SharePlus.instance
                                        .share(ShareParams(text: command));
                                  },
                                ),
                              ],
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
                              Text(isFr
                                  ? 'Sur votre appareil, allez dans les paramètres du client Tailscale, sélectionnez "Use alternate server" et entrez l\'URL suivante:'
                                  : 'On your device, go to the Tailscale client settings, select "Use alternate server" and enter the following URL:'),
                              const SizedBox(height: 16),
                              SelectableText(
                                loginServer,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.copy),
                                    label: Text(isFr ? 'Copier' : 'Copy'),
                                    onPressed: () async {
                                      await Clipboard.setData(
                                          ClipboardData(text: loginServer));
                                      if (!context.mounted) return;
                                      showSafeSnackBar(
                                          context,
                                          isFr
                                              ? 'URL copiée !'
                                              : 'URL copied!');
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.share),
                                    label: Text(isFr ? 'Partager' : 'Share'),
                                    onPressed: () async {
                                      await SharePlus.instance
                                          .share(ShareParams(
                                        text: loginServer,
                                      ));
                                    },
                                  ),
                                ],
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
              child: Text(isFr ? 'Fermer' : 'Close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: Text(isFr ? 'Étape suivante' : 'Next Step'),
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
Future<void> showHeadscaleRegisterCommandDialog(
    BuildContext context, User user) async {
  final TextEditingController urlController = TextEditingController();
  final ValueNotifier<String> machineKey = ValueNotifier<String>('');

  return showDialog(
    context: context,
    builder: (dialogContext) {
      final locale = context.watch<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      return AlertDialog(
        title: Text(isFr
            ? 'Étape 2 : Enregistrer l\'appareil'
            : 'Step 2: Register Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isFr
                  ? 'Après avoir suivi l\'étape 1 sur votre appareil, le client Tailscale vous fournira une URL d\'enregistrement unique contenant une clé d\'identification unique. Collez cette URL compléte ou la clé d\'identification seule dans le champ ci-dessous pour enregistrer l\'appareil.'
                  : 'After following step 1 on your device, the Tailscale client will provide you with a unique registration URL containing a unique identification key. Paste this full URL or the identification key alone in the field below to register the device.'),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: isFr
                      ? 'Coller l\'URL du client ici'
                      : 'Paste client URL here',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final trimmedValue = value.trim();
                  final Uri? uri = Uri.tryParse(trimmedValue);

                  // Essaye d'extraire la clé d'une URL complète
                  if (uri != null &&
                      uri.hasScheme &&
                      uri.pathSegments.length >= 2 &&
                      uri.pathSegments[0] == 'register') {
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
            child: Text(isFr ? 'Fermer' : 'Close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ValueListenableBuilder<String>(
            valueListenable: machineKey,
            builder: (ctx, key, child) {
              return ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(
                    isFr ? 'Enregistrer sur le serveur' : 'Register on Server'),
                onPressed: key.isEmpty
                    ? null
                    : () async {
                        try {
                          final newNode = await context
                              .read<AppProvider>()
                              .apiService
                              .registerMachine(key, user.name);
                          if (!context.mounted) return;
                          Navigator.of(dialogContext)
                              .pop(); // Close registration dialog
                          showSafeSnackBar(
                              context,
                              isFr
                                  ? 'Appareil enregistré avec succès.'
                                  : 'Device registered successfully.');
                          showSafeSnackBar(
                              context,
                              isFr
                                  ? 'Un redémarrage du serveur Headscale est recommandé.'
                                  : 'A Headscale server restart is recommended.');
                          // Show the new dialog to add ACL tags
                          _showAddTagsDialog(context, newNode);
                        } catch (e) {
                          showSafeSnackBar(
                              context,
                              isFr
                                  ? 'Erreur lors de l\'enregistrement: $e'
                                  : 'Error during registration: $e');
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
      final locale = context.watch<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isFr
                ? 'Étape 3 : Ajouter des Tags ACL'
                : 'Step 3: Add ACL Tags'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${isFr ? 'Configurez les capacités de' : 'Configure capabilities for'} "${node.name}".'),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Exit Node'),
                  subtitle: Text(isFr
                      ? 'Autoriser ce nœud à être une sortie internet.'
                      : 'Allow this node to be an internet exit.'),
                  value: isExitNode,
                  onChanged: (value) {
                    setState(() {
                      isExitNode = value!;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('LAN Sharer'),
                  subtitle: Text(isFr
                      ? 'Autoriser ce nœud à partager son réseau local.'
                      : 'Allow this node to share its local network.'),
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
                child: Text(isFr ? 'Ignorer' : 'Skip'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              ElevatedButton(
                child: Text(isFr ? 'Appliquer les Tags' : 'Apply Tags'),
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
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Tags appliqués avec succès.'
                            : 'Tags applied successfully.');
                  } catch (e) {
                    showSafeSnackBar(
                        context,
                        isFr
                            ? 'Erreur lors de l\'application des tags: $e'
                            : 'Error applying tags: $e');
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
