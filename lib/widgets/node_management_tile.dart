import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/node_detail_screen.dart';

class NodeManagementTile extends StatelessWidget {
  final Node node;
  final VoidCallback onNodeUpdate;

  const NodeManagementTile({super.key, required this.node, required this.onNodeUpdate});

  Future<void> _runAction(BuildContext context, Future<void> Function() action,
      String successMessage) async {
    try {
      await action();
      showSafeSnackBar(context, successMessage);
      onNodeUpdate();
    } catch (e) {
      print('Action échouée : $e');
      showSafeSnackBar(context, 'Erreur : $e');
    }
  }

  void _showSubnetCommandDialog(BuildContext context, String subnetCidr,
      String loginServer, Node node, AppProvider provider) {
    final String tailscaleCommand = 'tailscale up --advertise-routes=$subnetCidr --login-server=$loginServer';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return DefaultTabController(
          length: 3, // Linux, Windows, Mobile
          child: AlertDialog(
            title: const Text('Étape 1 : Configurer le routage de sous-réseau'),
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
                                  'Sur votre appareil Linux, activez le transfert IP et le NAT, puis exécutez la commande Tailscale :'),
                              const SizedBox(height: 8),
                              const SelectableText(
                                  'sudo sysctl -w net.ipv4.ip_forward=1\nsudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE', // Note : La chaîne originale contenait \n, ce qui est correct pour un littéral de chaîne Dart représentant un saut de ligne.
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
                                  'Sur votre appareil Windows, activez le transfert IP et le NAT (partage de connexion Internet), puis exécutez la commande Tailscale :'),
                              const SizedBox(height: 8),
                              const SelectableText(
                                  '# Activer le transfert IP (PowerShell en tant qu\'administrateur)\nSet-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled\n\n# Activer le NAT (partage de connexion Internet) - nécessite une configuration GUI ou PowerShell plus complexe\n# Pour un NAT simple, vous pouvez utiliser `netsh routing ip nat install` et configurer les interfaces.',
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
                                  'Sur Android/iOS, le routage de sous-réseau est configuré directement dans les paramètres de l\'application Tailscale. Assurez-vous que l\'appareil est connecté à Tailscale, puis activez "Annoncer les routes" pour les sous-réseaux souhaités dans les paramètres de l\'application.'),
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
                onPressed: () => Navigator.of(dialogContext).pop(),
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
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Fermer la boîte de dialogue actuelle
                  _runAction(context,
                          () =>
                          provider.apiService.setNodeRoutes(
                          node.id, [subnetCidr]),
                      'Route de sous-réseau activée.'
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameNodeDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final newNameController = TextEditingController(text: node.name);
    final provider = context.read<AppProvider>();

    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Renommer l\'appareil'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: newNameController,
                decoration: const InputDecoration(labelText: 'Nouveau nom d\'appareil'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un nouveau nom';
                  }
                  return null;
                },
              ),
            ),
            actions: <Widget>[
              TextButton(child: const Text('Annuler'),
                  onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                child: const Text('Renommer'),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final newName = newNameController.text.toLowerCase();
                    Navigator.of(ctx).pop();
                    _runAction(context,
                            () =>
                            provider.apiService.renameNode(node.id, newName),
                        'Appareil renommé avec succès.'
                    );
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showMoveNodeDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<User>>(
          future: provider.apiService.getUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Déplacer l\'appareil'),
                content: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Erreur'),
                content: Text('Échec du chargement des utilisateurs : ${snapshot.error}'),
                actions: [
                  TextButton(child: const Text('Fermer'),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return AlertDialog(
                title: const Text('Déplacer l\'appareil'),
                content: const Text(
                    'Aucun autre utilisateur disponible pour déplacer l\'appareil.'),
                actions: [
                  TextButton(child: const Text('Fermer'),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              );
            }

            final users = snapshot.data!;
            User? selectedUser = users.isNotEmpty ? users.first : null;

            return AlertDialog(
              title: const Text('Déplacer l\'appareil'),
              content: DropdownButtonFormField<User>(
                value: selectedUser,
                items: users.map((user) {
                  return DropdownMenuItem<User>(
                    value: user,
                    child: Text(user.name),
                  );
                }).toList(),
                onChanged: (user) {
                  selectedUser = user;
                },
                decoration: const InputDecoration(
                  labelText: 'Sélectionner un utilisateur',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: <Widget>[
                TextButton(child: const Text('Annuler'),
                    onPressed: () => Navigator.of(ctx).pop()),
                TextButton(
                  child: const Text('Déplacer'),
                  onPressed: () {
                    if (selectedUser != null) {
                      Navigator.of(ctx).pop();
                      _runAction(context,
                              () =>
                              provider.apiService.moveNode(node.id,
                                  selectedUser!.name),
                          'Appareil déplacé avec succès.'
                      );
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

  void _showSubnetDialog(BuildContext context, AppProvider provider) {
    final formKey = GlobalKey<FormState>();
    final subnetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Partager le sous-réseau local'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Entrez le sous-réseau à annoncer (par exemple, 192.168.1.0/24).\n\nNote : L\'appareil doit être configuré pour annoncer cette route.'),
                const SizedBox(height: 16),
                Form(
                  key: formKey,
                  child: TextFormField(
                    controller: subnetController,
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
              TextButton(child: const Text('Annuler'),
                  onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                child: const Text('Partager'),
                onPressed: () async { // Rendre asynchrone
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(); // Fermer la boîte de dialogue de saisie du sous-réseau
                    final appProvider = context.read<AppProvider>();
                    final serverUrl = await appProvider.storageService
                        .getServerUrl();
                    if (serverUrl == null) {
                      showSafeSnackBar(
                          context, 'Erreur : URL du serveur non configurée.');
                      return;
                    }
                    final String loginServer = serverUrl.endsWith('/')
                        ? serverUrl.substring(0, serverUrl.length - 1)
                        : serverUrl;

                    _showSubnetCommandDialog(
                        context, subnetController.text, loginServer, node,
                        provider);
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showExitNodeCommandDialog(BuildContext context, Node node, AppProvider provider) async {
    final appProvider = context.read<AppProvider>();
    final serverUrl = await appProvider.storageService.getServerUrl();
    if (serverUrl == null) {
      showSafeSnackBar(context, 'Erreur : URL du serveur non configurée.');
      return;
    }
    final String loginServer = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    final String tailscaleCommand = 'tailscale up --advertise-exit-node --login-server=$loginServer';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return DefaultTabController(
          length: 3, // Linux, Windows, Mobile
          child: AlertDialog(
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
                                  'sudo sysctl -w net.ipv4.ip_forward=1', // Note: The original string had \n, which is correct for a Dart string literal representing a newline.
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
                                  '# Activer le transfert IP (PowerShell en tant qu\'administrateur)\nSet-NetIPInterface -InterfaceAlias "Ethernet" -Forwarding Enabled', // Note: The original string had \n, which is correct for a Dart string literal representing a newline.
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
                onPressed: () => Navigator.of(dialogContext).pop(),
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
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Fermer la boîte de dialogue actuelle
                  final List<String> combinedRoutes = List.from(node.advertisedRoutes);
                  if (!combinedRoutes.contains('0.0.0.0/0')) {
                    combinedRoutes.add('0.0.0.0/0');
                  }
                  if (!combinedRoutes.contains('::/0')) {
                    combinedRoutes.add('::/0');
                  }
                  _runAction(context,
                          () =>
                          provider.apiService.setNodeRoutes(
                          node.id, combinedRoutes),
                      'Nœud de sortie activé.'
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool get _isExitNode => node.advertisedRoutes.contains('0.0.0.0/0') || node.advertisedRoutes.contains('::/0');

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => NodeDetailScreen(node: node)));
        },
        leading: Icon(
            Icons.circle, color: node.online ? Colors.green : Colors.grey,
            size: 18),
        title: Row(
          children: [
            Text(node.name),
            if (_isExitNode)
              const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(Icons.exit_to_app, size: 18, color: Colors.blueGrey),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.ipAddresses.join(', ')),
            Text('Dernière connexion : ${node.lastSeen.toLocal()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) {
            switch (value) {
              case 'rename':
                _showRenameNodeDialog(context);
                break;
              case 'move':
                _showMoveNodeDialog(context, provider);
                break;
              case 'enable_exit_node':
                _showExitNodeCommandDialog(context, node, provider);
                break;
              case 'disable_exit_node':
                _runAction(context,
                        () => provider.apiService.setNodeRoutes(node.id, []),
                    'Nœud de sortie désactivé.'
                );
                break;
              case 'share_subnet':
                _showSubnetDialog(context, provider);
                break;
              case 'disable_subnet': // Nouveau cas
                _runAction(context,
                  () => provider.apiService.setNodeRoutes(node.id, []),
                  'Routes de sous-réseau désactivées.'
                );
                break;
              case 'delete_device':
                showDialog(
                  context: context,
                  builder: (dialogCtx) =>
                      AlertDialog(
                        title: const Text('Supprimer l\'appareil ?'),
                        content: Text(
                            'Êtes-vous sûr de vouloir supprimer ${node.name} ?'),
                        actions: <Widget>[
                          TextButton(child: const Text('Annuler'),
                              onPressed: () => Navigator.of(dialogCtx).pop()),
                          TextButton(
                            child: const Text(
                                'Confirmer', style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              Navigator.of(dialogCtx).pop();
                              _runAction(context,
                                      () =>
                                      provider.apiService.deleteNode(node.id),
                                  'Appareil supprimé.'
                              );
                            },
                          ),
                        ],
                      ),
                );
                break;
            }
          },
          itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'rename',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Renommer l\'appareil'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'move',
              child: ListTile(
                leading: Icon(Icons.move_up),
                title: Text('Déplacer l\'appareil'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'enable_exit_node',
              child: ListTile(
                leading: Icon(Icons.exit_to_app),
                title: Text('Activer le nœud de sortie'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'disable_exit_node',
              child: ListTile(
                leading: Icon(Icons.remove_circle_outline),
                title: Text('Désactiver le nœud de sortie'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'share_subnet',
              child: ListTile(
                leading: Icon(Icons.router_outlined),
                title: Text('Partager le sous-réseau local'),
              ),
            ),
            const PopupMenuItem<String>( // Nouvel élément
              value: 'disable_subnet',
              child: ListTile(
                leading: Icon(Icons.router_outlined), // Réutilisation de l\'icône pour l\'instant
                title: Text('Désactiver les routes de sous-réseau'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'delete_device',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Supprimer l\'appareil'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}