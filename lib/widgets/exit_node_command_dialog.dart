import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:headscalemanager/widgets/subnet_command_dialog.dart'; // Reusing the generic command dialog

/// Dialogue pour configurer un nœud comme nœud de sortie.
///
/// Affiche les commandes Tailscale nécessaires et les instructions spécifiques
/// à la plateforme pour activer la fonctionnalité de nœud de sortie.
class ExitNodeCommandDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();

    return FutureBuilder<String?>(
      future: appProvider.storageService.getServerUrl(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(
            title: Text('Chargement...'),
            content: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          debugPrint('Erreur lors de la récupération de l\'URL du serveur : ${snapshot.error}');
          return AlertDialog(
            title: const Text('Erreur'),
            content: const Text('URL du serveur non configurée.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        }

        final serverUrl = snapshot.data!;
        final String loginServer = serverUrl.endsWith('/')
            ? serverUrl.substring(0, serverUrl.length - 1)
            : serverUrl;
        final String tailscaleCommand =
            'tailscale up --advertise-exit-node --login-server=$loginServer';

        return AlertDialog( // Changed from SubnetCommandDialog to AlertDialog
          title: const Text('Étape 1 : Configurer le nœud de sortie'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Linux'),
                    Tab(text: 'Windows'),
                    Tab(text: 'Mobile'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Instructions Linux
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Sur votre appareil Linux, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :'),
                            const SizedBox(height: 8),
                            const SelectableText(
                                'sudo sysctl -w net.ipv4.ip_forward=1',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
                            const SizedBox(height: 8),
                            SelectableText(
                              tailscaleCommand,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // Instructions Windows
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Sur votre appareil Windows, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :'),
                            const SizedBox(height: 8),
                            const SelectableText(
                                '# Activer le transfert IP (PowerShell en tant qu\'administrateur)\nSet-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled',
                                style: TextStyle(fontFamily: 'monospace', fontSize: 14)),
                            const SizedBox(height: 8),
                            SelectableText(
                              tailscaleCommand,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      // Instructions mobiles
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                                'Sur Android/iOS, la fonctionnalité de nœud de sortie est configurée directement dans les paramètres de l\'application Tailscale. Assurez-vous que l\'appareil est connecté à Tailscale, puis activez "Utiliser comme nœud de sortie" dans les paramètres de l\'application.'),
                            const SizedBox(height: 8),
                            SelectableText(
                              tailscaleCommand,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                            ),
                          ],
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
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Copier la commande Tailscale'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: tailscaleCommand));
                showSafeSnackBar(context, 'Commande Tailscale copiée dans le presse-papiers !');
              },
            ),
            ElevatedButton(
              child: const Text('Procéder à la confirmation'),
              onPressed: () async {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue actuelle
                final List<String> combinedRoutes = List.from(node.advertisedRoutes);
                if (!combinedRoutes.contains('0.0.0.0/0')) {
                  combinedRoutes.add('0.0.0.0/0');
                }
                if (!combinedRoutes.contains('::/0')) {
                  combinedRoutes.add('::/0');
                }
                try {
                  await appProvider.apiService.setNodeRoutes(node.id, combinedRoutes);
                  showSafeSnackBar(context, 'Nœud de sortie activé.');
                  onExitNodeEnabled(); // Appelle le callback pour rafraîchir
                } catch (e) {
                  debugPrint('Erreur lors de l\'activation du nœud de sortie : $e');
                  showSafeSnackBar(context, 'Échec de l\'activation du nœud de sortie : $e');
                }
              },
            ),
          ],
        );
      },
    );
  }
}