import 'package:flutter/material.dart';
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

        return SubnetCommandDialog(
          title: 'Étape 1 : Configurer le nœud de sortie',
          tailscaleCommand: tailscaleCommand,
          linuxInstructions:
              'Sur votre appareil Linux, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :',
          windowsInstructions:
              'Sur votre appareil Windows, assurez-vous que le transfert IP est activé si vous souhaitez acheminer le trafic d\'autres appareils via ce nœud de sortie. Exécutez ensuite la commande Tailscale :',
          mobileInstructions:
              'Sur Android/iOS, la fonctionnalité de nœud de sortie est configurée directement dans les paramètres de l\'application Tailscale. Assurez-vous que l\'appareil est connecté à Tailscale, puis activez "Utiliser comme nœud de sortie" dans les paramètres de l\'application.',
          onConfirm: () async {
            // Logique pour activer le nœud de sortie via l\'API Headscale
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
          confirmButtonText: 'Procéder à la confirmation',
        );
      },
    );
  }
}
