import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/tag_capability_helper.dart';
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

  const ShareSubnetDialog(
      {super.key, required this.node, required this.onSubnetShared});

  @override
  State<ShareSubnetDialog> createState() => _ShareSubnetDialogState();
}

class _ShareSubnetDialogState extends State<ShareSubnetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _subnetController =
      TextEditingController(text: '192.168.1.0/24');

  @override
  void dispose() {
    _subnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.read<AppProvider>();
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title:
          Text(isFr ? 'Partager le sous-réseau local' : 'Share Local Subnet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isFr
                ? 'Entrez le sous-réseau à annoncer (par exemple, 192.168.1.0/24).\n\nNote : L\'appareil doit être configuré pour annoncer cette route.'
                : 'Enter the subnet to advertise (e.g., 192.168.1.0/24).\n\nNote: The device must be configured to advertise this route.'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _subnetController,
                decoration: InputDecoration(
                    labelText: isFr
                        ? 'Sous-réseau (format CIDR)'
                        : 'Subnet (CIDR format)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isFr
                        ? 'Veuillez entrer un sous-réseau'
                        : 'Please enter a subnet';
                  }
                  final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}');
                  if (!regex.hasMatch(value)) {
                    return isFr
                        ? 'Format CIDR invalide'
                        : 'Invalid CIDR format';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(isFr ? 'Partager' : 'Share'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final String newSubnet = _subnetController.text;

              try {
                // 1. Update Tags (add lan-sharer capability)
                final List<String> currentTags = List.from(widget.node.tags);
                final List<String> newTags = TagCapabilityHelper.addCapabilities(
                  currentTags,
                  engineMode: appProvider.aclEngineMode,
                  normalizedUser: widget.node.getNormalizedOwner(),
                  addLanSharer: true,
                );

                if (newTags.length != currentTags.length ||
                    !newTags.asMap().entries.every(
                        (e) => currentTags[e.key] == e.value)) {
                  await appProvider.apiService.setTags(widget.node.id, newTags);
                }

                // 2. Set Routes
                final List<String> combinedRoutes =
                    List.from(widget.node.sharedRoutes);
                if (!combinedRoutes.contains(newSubnet)) {
                  combinedRoutes.add(newSubnet);
                }

                await appProvider.apiService
                    .setNodeRoutes(widget.node.id, combinedRoutes);

                // 3. Update ACLs if in ACL Mode
                bool aclMode = true;
                String? rawServerPolicy;
                try {
                  rawServerPolicy = await appProvider.apiService.getAclPolicy();
                } catch (e) {
                  aclMode = false;
                }

                if (aclMode) {
                  if (context.mounted) {
                    showSafeSnackBar(context,
                        isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');
                  }
                  // Regenerate Policy
                  final allUsers = await appProvider.apiService.getUsers();
                  final allNodes = await appProvider.apiService.getNodes();
                  final serverId = appProvider.activeServer?.id;

                  if (serverId != null) {
                    final tempRules = await appProvider.storageService
                        .getTemporaryRules(serverId);

                    final aclOrchestrator = AclPolicyOrchestrator();
                    final newPolicyMap = aclOrchestrator.generatePolicy(
                      engineMode: appProvider.aclEngineMode,
                      users: allUsers,
                      nodes: allNodes,
                      temporaryRules: tempRules,
                      taildriveShares: appProvider.taildriveShares,
                      serverVersion: appProvider.serverVersion,
                      includeUntaggedNodes: appProvider.includeUntaggedNodes,
                    );

                    await PolicyPreserver.applyPreservingPolicy(
                      apiService: appProvider.apiService,
                      generatedPolicy: newPolicyMap,
                      rawServerPolicy: rawServerPolicy,
                    );
                  }
                }

                if (context.mounted) {
                  showSafeSnackBar(
                      context,
                      isFr
                          ? 'Route de sous-réseau activée.'
                          : 'Subnet route enabled.');
                }
                widget.onSubnetShared();

                if (!context.mounted) return;
                Navigator.of(context).pop();

                final serverUrl = appProvider.activeServer?.url;
                final String loginServer = serverUrl?.endsWith('/') == true
                    ? serverUrl!.substring(0, serverUrl.length - 1)
                    : serverUrl ?? '';

                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (ctx) => SubnetCommandDialog(
                    title: isFr
                        ? 'Sur le client : Configurer le routage de sous-réseau'
                        : 'On the client: Configure subnet routing',
                    tailscaleCommand:
                        'tailscale up --advertise-routes=$newSubnet --login-server=$loginServer',
                    linuxInstructions: isFr
                        ? 'Sur votre appareil Linux, activez le transfert IP et le NAT, puis exécutez la commande Tailscale :'
                        : 'On your Linux device, enable IP forwarding and NAT, then run the Tailscale command:',
                    windowsInstructions: isFr
                        ? 'Sur votre appareil Windows, activez le transfert IP et le NAT (partage de connexion Internet), puis exécutez la commande Tailscale :'
                        : 'On your Windows device, enable IP forwarding and NAT (Internet Connection Sharing), then run the Tailscale command:',
                    mobileInstructions: isFr
                        ? 'Sur votre appareil mobile (Android/iOS), allez dans les paramètres du client Tailscale et activez l\'option "Allow LAN access".'
                        : 'On your mobile device (Android/iOS), go to the Tailscale client settings and enable the "Allow LAN access" option.',
                  ),
                );
              } catch (e) {
                debugPrint(
                    'Erreur lors de l\'activation de la route de sous-réseau : $e');
                if (!mounted) return;
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Échec de l\'activation de la route de sous-réseau : $e'
                        : 'Failed to enable subnet route: $e');
              }
            }
          },
        ),
      ],
    );
  }
}
