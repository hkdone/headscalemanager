import 'package:flutter/material.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/add_edit_server_screen.dart';
import 'package:provider/provider.dart';

class ServerListTile extends StatelessWidget {
  final Server server;

  const ServerListTile({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final activeServer = appProvider.activeServer;
    final isFr = appProvider.locale.languageCode == 'fr';
    final bool isActive = activeServer?.id == server.id;

    return Card(
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        title: Text(server.name),
        subtitle: Text(
          '${server.url}${server.version != null ? ' (v${server.version})' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isActive)
              TextButton(
                onPressed: () {
                  appProvider.switchServer(server.id);
                },
                child: Text(isFr ? 'Activer' : 'Set Active'),
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddEditServerScreen(server: server),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: appProvider.servers.length > 1
                  ? () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                              isFr ? 'Supprimer le serveur' : 'Delete Server'),
                          content: Text(
                            isFr
                                ? 'Êtes-vous sûr de vouloir supprimer ce serveur ?'
                                : 'Are you sure you want to delete this server?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(isFr ? 'Annuler' : 'Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(isFr ? 'Supprimer' : 'Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        appProvider.deleteServer(server.id);
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
