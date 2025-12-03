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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isFr ? 'Clés API' : 'API Keys',
            style: Theme.of(context).appBarTheme.titleTextStyle),
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
            return Center(
                child: Text('${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(
                    isFr ? 'Aucune clé API trouvée.' : 'No API key found.'));
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
        tooltip: isFr ? 'Créer une clé API' : 'Create API Key',
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _createNewApiKey() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    // Calculer la date d'expiration à 6 mois à partir de maintenant
    final expirationDate =
        DateTime.now().add(const Duration(days: 182)); // Environ 6 mois

    final newApiKey = await context
        .read<AppProvider>()
        .apiService
        .createApiKey(expiration: expirationDate);
    _refreshApiKeys();
    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isFr ? 'Nouvelle clé API créée' : 'New API Key Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isFr
                  ? 'Veuillez copier cette clé maintenant. Vous ne pourrez pas la voir à nouveau.'
                  : 'Please copy this key now. You will not be able to see it again.'),
              const SizedBox(height: 16),
              SelectableText(newApiKey,
                  style: const TextStyle(fontFamily: 'monospace')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isFr ? 'OK' : 'OK'),
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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text('Prefix: ${apiKey.prefix}',
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${apiKey.id}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
                '${isFr ? 'Expiration' : 'Expiration'}: ${apiKey.expiration?.toLocal() ?? (isFr ? 'Jamais' : 'Never')}',
                style: Theme.of(context).textTheme.bodySmall),
            Text(
                '${isFr ? 'Dernière utilisation' : 'Last Seen'}: ${apiKey.lastSeen?.toLocal() ?? (isFr ? 'Jamais' : 'Never')}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'expire',
              child: ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: Text(isFr ? 'Faire expirer' : 'Expire')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                  leading: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(isFr ? 'Supprimer' : 'Delete')),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String value) async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    switch (value) {
      case 'expire':
        final confirm = await _showConfirmationDialog(
            context,
            isFr ? 'Faire expirer la clé API ?' : 'Expire API Key?',
            isFr
                ? 'Voulez-vous vraiment faire expirer la clé API avec le préfixe ${apiKey.prefix} ?'
                : 'Do you really want to expire the API key with prefix ${apiKey.prefix}?');
        if (confirm) {
          await context
              .read<AppProvider>()
              .apiService
              .expireApiKey(apiKey.prefix);
          onAction();
        }
        break;
      case 'delete':
        final confirm = await _showConfirmationDialog(
            context,
            isFr ? 'Supprimer la clé API ?' : 'Delete API Key?',
            isFr
                ? 'Voulez-vous vraiment supprimer la clé API avec le préfixe ${apiKey.prefix} ?'
                : 'Do you really want to delete the API key with prefix ${apiKey.prefix}?');
        if (confirm) {
          await context
              .read<AppProvider>()
              .apiService
              .deleteApiKey(apiKey.prefix);
          onAction();
        }
        break;
    }
  }

  Future<bool> _showConfirmationDialog(
      BuildContext context, String title, String content) async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, style: Theme.of(context).textTheme.titleLarge),
            content:
                Text(content, style: Theme.of(context).textTheme.bodyMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(isFr ? 'Annuler' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isFr ? 'Confirmer' : 'Confirm',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}
