import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:headscalemanager/utils/snack_bar_utils.dart'; // For showSafeSnackBar

/// Dialogue pour afficher une commande Tailscale et des instructions spécifiques à la plateforme.
///
/// Ce dialogue est utilisé pour guider l'utilisateur sur la manière de configurer
/// le routage de sous-réseau ou le nœud de sortie sur différentes plateformes
/// (Linux, Windows, Mobile) en fournissant la commande Tailscale pertinente.
class SubnetCommandDialog extends StatelessWidget {
  /// Le titre du dialogue (ex: "Configurer le routage de sous-réseau").
  final String title;

  /// La commande Tailscale à afficher.
  final String tailscaleCommand;

  /// Instructions spécifiques pour Linux.
  final String linuxInstructions;

  /// Instructions spécifiques pour Windows.
  final String windowsInstructions;

  /// Instructions spécifiques pour Mobile.
  final String mobileInstructions;

  /// Fonction de rappel optionnelle pour l'action de confirmation.
  final VoidCallback? onConfirm;

  /// Texte du bouton de confirmation optionnel.
  final String? confirmButtonText;

  const SubnetCommandDialog({
    super.key,
    required this.title,
    required this.tailscaleCommand,
    required this.linuxInstructions,
    required this.windowsInstructions,
    required this.mobileInstructions,
    this.onConfirm,
    this.confirmButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Linux, Windows, Mobile
      child: AlertDialog(
        title: Text(title),
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
                          Text(linuxInstructions),
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
                          Text(windowsInstructions),
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
                          Text(mobileInstructions),
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
          if (onConfirm != null)
            ElevatedButton(
              child: Text(confirmButtonText ?? 'Procéder à la confirmation'),
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue actuelle
                onConfirm!(); // Exécuter l'action de confirmation
              },
            ),
        ],
      ),
    );
  }
}