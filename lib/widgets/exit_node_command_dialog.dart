import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

/// Dialogue pour configurer un nœud comme nœud de sortie.
///
/// Affiche les commandes Tailscale nécessaires et les instructions spécifiques
/// à la plateforme pour activer la fonctionnalité de nœud de sortie.
class ExitNodeCommandDialog extends StatefulWidget {
  /// Le nœud à configurer comme nœud de sortie.
  final Node node;

  /// Fonction de rappel appelée après la confirmation de l'activation du nœud de sortie.
  final VoidCallback onExitNodeEnabled;

  const ExitNodeCommandDialog({
    super.key,
    required this.node,
    required this.onExitNodeEnabled,
  });

  @override
  State<ExitNodeCommandDialog> createState() => _ExitNodeCommandDialogState();
}

class _ExitNodeCommandDialogState extends State<ExitNodeCommandDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final serverUrl = appProvider.activeServer?.url;

    if (serverUrl == null) {
      return AlertDialog(
        title: Text(isFr ? 'Erreur' : 'Error'),
        content: Text(isFr
            ? 'URL du serveur non configurée.'
            : 'Server URL not configured.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isFr ? 'Fermer' : 'Close'),
          ),
        ],
      );
    }

    final String loginServer = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final String tailscaleCommand =
        'tailscale up --advertise-exit-node --login-server=$loginServer';

    return AlertDialog(
      // Changed from SubnetCommandDialog to AlertDialog
      title: Text(isFr
          ? 'Étape 1 : Configurer le nœud de sortie'
          : 'Step 1: Configure Exit Node'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Linux'),
                Tab(text: 'Windows'),
                Tab(text: 'Mobile'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Instructions Linux
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFr
                            ? 'Sur votre appareil Linux, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :'
                            : 'On your Linux device, ensure IP forwarding is enabled if you want to route traffic from other devices through this exit node. Then run the Tailscale command:'),
                        const SizedBox(height: 8),
                        const SelectableText(
                            'sudo sysctl -w net.ipv4.ip_forward=1',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          tailscaleCommand,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Instructions Windows
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFr
                            ? 'Sur votre appareil Windows, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :'
                            : 'On your Windows device, ensure IP forwarding is enabled if you want to route traffic from other devices through this exit node. Then run the Tailscale command:'),
                        const SizedBox(height: 8),
                        const SelectableText(
                            '# Activer le transfert IP (PowerShell en tant qu\'administrateur)\nSet-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled',
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 14)),
                        const SizedBox(height: 8),
                        SelectableText(
                          tailscaleCommand,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  // Instructions mobiles
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(isFr
                          ? 'Sur votre appareil mobile (Android/iOS), allez dans les paramètres du client Tailscale, sélectionnez l\'option "Exit nodes", puis activez l\'option "Run as exit node". Aucune ligne de commande n\'est nécessaire.'
                          : 'On your mobile device (Android/iOS), go to the Tailscale client settings, select the "Exit nodes" option, then enable the "Run as exit node" option. No command line is necessary.'),
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(isFr
              ? 'Copier la commande Tailscale'
              : 'Copy Tailscale Command'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: tailscaleCommand));
            showSafeSnackBar(
                context,
                isFr
                    ? 'Commande Tailscale copiée dans le presse-papiers !'
                    : 'Tailscale command copied to clipboard!');
          },
        ),
        ElevatedButton(
          child: Text(isFr
              ? 'Procéder à la confirmation'
              : 'Proceed to Confirmation'),
          onPressed: () async {
            Navigator.of(context)
                .pop(); // Fermer la boîte de dialogue actuelle
            final List<String> combinedRoutes =
                List.from(widget.node.sharedRoutes);
            if (!combinedRoutes.contains('0.0.0.0/0')) {
              combinedRoutes.add('0.0.0.0/0');
            }
            if (!combinedRoutes.contains('::/0')) {
              combinedRoutes.add('::/0');
            }
            try {
              await appProvider.apiService
                  .setNodeRoutes(widget.node.id, combinedRoutes);
              showSafeSnackBar(context,
                  isFr ? 'Nœud de sortie activé.' : 'Exit node enabled.');
              widget
                  .onExitNodeEnabled(); // Appelle le callback pour rafraîchir
            } catch (e) {
              debugPrint(
                  'Erreur lors de l\'activation du nœud de sortie : $e');
              showSafeSnackBar(
                  context,
                  isFr
                      ? 'Échec de l\'activation du nœud de sortie : $e'
                      : 'Failed to enable exit node: $e');
            }
          },
        ),
      ],
    );
  }
}
