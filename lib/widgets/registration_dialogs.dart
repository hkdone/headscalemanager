import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';

/// Affiche un dialogue pour guider l'utilisateur dans l'enregistrement d'un appareil.
/// L'utilisateur choisit d'abord entre le mode OIDC et le mode Classique.
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

  return showDialog(
    context: context,
    builder: (dialogContext) {
      final locale = context.watch<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(isFr ? 'Ajouter un Appareil' : 'Add a Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr
                    ? 'Choisissez le mode de connexion de votre serveur Headscale :'
                    : 'Choose your Headscale server connection mode:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // Carte Classique
              _ConnectionModeCard(
                icon: Icons.terminal,
                title: isFr ? 'Connexion Classique' : 'Classic Connection',
                description: isFr
                    ? 'Le client Tailscale affiche une URL avec une clé machine à copier. Pour les serveurs sans OIDC.'
                    : 'Tailscale client shows a URL with a machine key to copy. For servers without OIDC.',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showClassicStep1(context, user, loginServer);
                },
              ),
              const SizedBox(height: 12),
              // Carte OIDC
              _ConnectionModeCard(
                icon: Icons.login,
                title: isFr ? 'Connexion OIDC' : 'OIDC Connection',
                description: isFr
                    ? 'Le navigateur s\'ouvre automatiquement vers un fournisseur d\'identité (Google, GitHub…). Réservé aux admins ayant activé OIDC dans config.yaml.'
                    : 'The browser opens automatically to an identity provider (Google, GitHub…). Only for admins who enabled OIDC in config.yaml.',
                color: Colors.teal,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showOidcStep1(context, user, loginServer);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(isFr ? 'Annuler' : 'Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

/// Carte de sélection du mode de connexion.
class _ConnectionModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ConnectionModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: color, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FLOW CLASSIQUE (3 étapes — inchangé)
// ---------------------------------------------------------------------------

Future<void> _showClassicStep1(
    BuildContext context, User user, String loginServer) async {
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
              ? 'Étape 1/3 : Connecter l\'appareil'
              : 'Step 1/3: Connect Device'),
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
                  height: 200,
                  child: TabBarView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isFr
                                ? 'Exécutez la commande suivante dans le terminal de votre appareil:'
                                : 'Run the following command in your device\'s terminal:'),
                            const SizedBox(height: 16),
                            SelectableText(command,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 14)),
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
                              SelectableText(loginServer,
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 14)),
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
                                      await SharePlus.instance.share(
                                          ShareParams(text: loginServer));
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

// ---------------------------------------------------------------------------
// FLOW OIDC (2 étapes)
// ---------------------------------------------------------------------------

Future<void> _showOidcStep1(
    BuildContext context, User user, String loginServer) async {
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
              ? 'OIDC — Étape 1/2 : Connecter l\'appareil'
              : 'OIDC — Step 1/2: Connect Device'),
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
                  height: 240,
                  child: TabBarView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isFr
                                ? 'Exécutez la commande suivante. Le navigateur s\'ouvrira automatiquement pour la connexion OIDC — aucune clé à copier.'
                                : 'Run the following command. The browser will open automatically for OIDC login — no key to copy.'),
                            const SizedBox(height: 12),
                            SelectableText(command,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 14)),
                            const SizedBox(height: 12),
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
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isFr
                                  ? 'Dans les paramètres du client Tailscale, sélectionnez "Use alternate server" et entrez l\'URL suivante. Le navigateur s\'ouvrira pour la connexion OIDC.'
                                  : 'In Tailscale client settings, select "Use alternate server" and enter the URL below. The browser will open for OIDC login.'),
                              const SizedBox(height: 12),
                              SelectableText(loginServer,
                                  style: const TextStyle(
                                      fontFamily: 'monospace', fontSize: 14)),
                              const SizedBox(height: 12),
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
                                      await SharePlus.instance.share(
                                          ShareParams(text: loginServer));
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
                _showOidcStep2(context, user);
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showOidcStep2(BuildContext context, User user) async {
  return showDialog(
    context: context,
    builder: (dialogContext) {
      final locale = context.watch<AppProvider>().locale;
      final isFr = locale.languageCode == 'fr';
      final theme = Theme.of(context);

      final email = user.email ??
          (user.provider != null && user.provider!.isNotEmpty
              ? user.name
              : null);

      final yamlSnippet = email != null
          ? 'oidc:\n  allowed_users:\n    - $email'
          : 'oidc:\n  allowed_users:\n    - <email@example.com>';

      return AlertDialog(
        title: Text(isFr
            ? 'OIDC — Étape 2/2 : Autoriser l\'utilisateur'
            : 'OIDC — Step 2/2: Authorize User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr
                    ? 'Pour que cet utilisateur puisse se connecter, son adresse email doit être autorisée dans le fichier config.yaml de votre serveur Headscale.'
                    : 'For this user to connect, their email must be allowed in your Headscale server\'s config.yaml file.',
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('config.yaml',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: isFr ? 'Copier' : 'Copy',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: yamlSnippet));
                            if (!context.mounted) return;
                            showSafeSnackBar(context,
                                isFr ? 'Snippet copié !' : 'Snippet copied!');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      yamlSnippet,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.teal, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Une fois connecté, le nœud s\'enregistre automatiquement dans votre Dashboard. Si l\'utilisateur est créé sans nom, l\'application le corrigera automatiquement lors du prochain chargement de l\'écran Utilisateurs.'
                            : 'Once connected, the node registers automatically in your Dashboard. If the user is created without a name, the app will auto-fix it on the next Users screen load.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            child: Text(isFr ? 'Terminé' : 'Done'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      );
    },
  );
}

/// Affiche un dialogue pour la deuxième étape du flow Classique.
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
            ? 'Étape 2/3 : Enregistrer l\'appareil'
            : 'Step 2/3: Register Device'),
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
                ? 'Étape 3/3 : Ajouter des Tags ACL'
                : 'Step 3/3: Add ACL Tags'),
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
