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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Clés API', style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
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
            padding: const EdgeInsets.all(8.0),
            itemCount: apiKeys.length,
            itemBuilder: (context, index) {
              final apiKey = apiKeys[index];
              return _ApiKeyCard(apiKey: apiKey, onAction: _refreshApiKeys);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewApiKey,
        tooltip: 'Créer une clé API',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _createNewApiKey() async {
    final newApiKey = await context.read<AppProvider>().apiService.createApiKey();
    _refreshApiKeys();
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nouvelle clé API créée'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Veuillez copier cette clé maintenant. Vous ne pourrez pas la voir à nouveau.'),
              const SizedBox(height: 16),
              SelectableText(newApiKey, style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class _ApiKeyCard extends StatelessWidget {
  final ApiKey apiKey;
  final VoidCallback onAction;

  const _ApiKeyCard({required this.apiKey, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text('Prefix: ${apiKey.prefix}',
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${apiKey.id}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Expiration: ${apiKey.expiration?.toLocal() ?? 'Jamais'}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Dernière utilisation: ${apiKey.lastSeen?.toLocal() ?? 'Jamais'}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'expire',
              child: ListTile(leading: Icon(Icons.hourglass_bottom), title: Text('Faire expirer')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), title: Text('Supprimer')),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) async {
    switch (value) {
      case 'expire':
        final confirm = await _showConfirmationDialog(context, 'Faire expirer la clé API ?', 'Voulez-vous vraiment faire expirer la clé API avec le préfixe ${apiKey.prefix} ?');
        if (confirm) {
          await context.read<AppProvider>().apiService.expireApiKey(apiKey.prefix);
          onAction();
        }
        break;
      case 'delete':
        final confirm = await _showConfirmationDialog(context, 'Supprimer la clé API ?', 'Voulez-vous vraiment supprimer la clé API avec le préfixe ${apiKey.prefix} ?');
        if (confirm) {
          await context.read<AppProvider>().apiService.deleteApiKey(apiKey.prefix);
          onAction();
        }
        break;
    }
  }

  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        content: Text(content, style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    ) ?? false;
  }
}
