import 'package:flutter/material.dart';
import 'package:headscalemanager/models/api_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';

class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  late Future<List<ApiKey>> _apiKeysFuture;

  @override
  void initState() {
    super.initState();
    _refreshApiKeys();
  }

  void _refreshApiKeys() {
    setState(() {
      _apiKeysFuture = context.read<AppProvider>().apiService.listApiKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clés API'),
      ),
      body: FutureBuilder<List<ApiKey>>(
        future: _apiKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune clé API trouvée.'));
          }

          final apiKeys = snapshot.data!;

          return ListView.builder(
            itemCount: apiKeys.length,
            itemBuilder: (context, index) {
              final apiKey = apiKeys[index];
              return ListTile(
                title: Text('Prefix: ${apiKey.prefix}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${apiKey.id}'),
                    Text('Expiration: ${apiKey.expiration?.toLocal() ?? 'Jamais'}'),
                    Text('Dernière utilisation: ${apiKey.lastSeen?.toLocal() ?? 'Jamais'}'),
                    Text('Création: ${apiKey.createdAt.toLocal()}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.hourglass_bottom),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Faire expirer la clé API ?'),
                            content: Text('Voulez-vous vraiment faire expirer la clé API avec le préfixe ${apiKey.prefix} ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Expirer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await context.read<AppProvider>().apiService.expireApiKey(apiKey.prefix);
                          _refreshApiKeys();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer la clé API ?'),
                            content: Text('Voulez-vous vraiment supprimer la clé API avec le préfixe ${apiKey.prefix} ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Supprimer'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await context.read<AppProvider>().apiService.deleteApiKey(apiKey.prefix);
                          _refreshApiKeys();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newApiKey = await context.read<AppProvider>().apiService.createApiKey();
          _refreshApiKeys();
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Nouvelle clé API créée'),
              content: SelectableText(newApiKey),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
        tooltip: 'Créer une clé API',
        child: const Icon(Icons.add),
      ),
    );
  }
}