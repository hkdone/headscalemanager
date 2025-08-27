import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint
import 'package:headscalemanager/widgets/subnet_command_dialog.dart'; // Import the new dialog

/// Dialogue pour partager un sous-réseau local via un nœud Headscale.
///
/// Permet à l'utilisateur de saisir un sous-réseau au format CIDR et génère
/// la commande Tailscale correspondante pour annoncer cette route.
class ShareSubnetDialog extends StatefulWidget {
  /// Le nœud via lequel le sous-réseau sera partagé.
  final Node node;

  /// Fonction de rappel appelée après la confirmation du partage du sous-réseau.
  final VoidCallback onSubnetShared;

  const ShareSubnetDialog({super.key, required this.node, required this.onSubnetShared});

  @override
  State<ShareSubnetDialog> createState() => _ShareSubnetDialogState();
}

class _ShareSubnetDialogState extends State<ShareSubnetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subnetController = TextEditingController(text: '192.168.1.0/24');

  @override
  void dispose() {
    _subnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();

    return AlertDialog(
      title: const Text('Partager le sous-réseau local'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Entrez le sous-réseau à annoncer (par exemple, 192.168.1.0/24).\n\nNote : L\'appareil doit être configuré pour annoncer cette route.'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _subnetController,
                decoration: const InputDecoration(
                    labelText: 'Sous-réseau (format CIDR)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un sous-réseau';
                  }
                  final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}');
                  if (!regex.hasMatch(value)) return 'Format CIDR invalide';
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Partager'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final String newSubnet = _subnetController.text;
              final List<String> combinedRoutes = List.from(widget.node.sharedRoutes);

              if (!combinedRoutes.contains(newSubnet)) {
                combinedRoutes.add(newSubnet);
              }

              try {
                await appProvider.apiService.setNodeRoutes(widget.node.id, combinedRoutes);
                showSafeSnackBar(context, 'Route de sous-réseau activée.');
                widget.onSubnetShared(); // Appelle le callback pour rafraîchir

                // Fermer la boîte de dialogue de saisie du sous-réseau
                Navigator.of(context).pop();

                // Afficher le dialogue de commande Tailscale pour le sous-réseau.
                final serverUrl = await appProvider.storageService.getServerUrl();
                final String loginServer = serverUrl?.endsWith('/') == true
                    ? serverUrl!.substring(0, serverUrl.length - 1)
                    : serverUrl ?? '';

                showDialog(
                  context: context,
                  builder: (ctx) => SubnetCommandDialog(
                    title: 'Sur le client : Configurer le routage de sous-réseau',
                    tailscaleCommand: 'tailscale up --advertise-routes=$newSubnet --login-server=$loginServer',
                    linuxInstructions: 'Sur votre appareil Linux, activez le transfert IP et le NAT, puis exécutez la commande Tailscale :',
                    windowsInstructions: 'Sur votre appareil Windows, activez le transfert IP et le NAT (partage de connexion Internet), puis exécutez la commande Tailscale :',
                    mobileInstructions: 'Sur votre appareil mobile (Android/iOS), allez dans les paramètres du client Tailscale et activez l\'option "Allow LAN access".',
                  ),
                );
              } catch (e) {
                debugPrint('Erreur lors de l\'activation de la route de sous-réseau : $e');
                if (!mounted) return;
                Navigator.of(context).pop(); // Fermer la boîte de dialogue même en cas d'erreur
                showSafeSnackBar(context, 'Échec de l\'activation de la route de sous-réseau : $e');
              }
            }
          },
        ),
      ],
    );
  }
}
