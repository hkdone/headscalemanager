import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
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
  final TextEditingController _subnetController = TextEditingController();

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
      content: Column(
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
      actions: <Widget>[
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Partager'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(); // Fermer la boîte de dialogue de saisie du sous-réseau
              final serverUrl = await appProvider.storageService.getServerUrl();
              if (serverUrl == null) {
                showSafeSnackBar(
                    context, 'Erreur : URL du serveur non configurée.');
                return;
              }
              final String loginServer = serverUrl.endsWith('/')
                  ? serverUrl.substring(0, serverUrl.length - 1)
                  : serverUrl;

              // Affiche le dialogue de commande Tailscale pour le sous-réseau.
              showDialog(
                context: context,
                builder: (ctx) => SubnetCommandDialog(
                  title: 'Étape 1 : Configurer le routage de sous-réseau',
                  tailscaleCommand: 'tailscale up --advertise-routes=${_subnetController.text} --login-server=$loginServer',
                  linuxInstructions: 'Sur votre appareil Linux, activez le transfert IP et le NAT, puis exécutez la commande Tailscale :',
                  windowsInstructions: 'Sur votre appareil Windows, activez le transfert IP et le NAT (partage de connexion Internet), puis exécutez la commande Tailscale :',
                  mobileInstructions: 'Sur Android/iOS, le routage de sous-réseau est configuré directement dans les paramètres de l\'application Tailscale. Assurez-vous que l\'appareil est connecté à Tailscale, puis activez \