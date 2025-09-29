import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart';

class PreAuthKeysScreen extends StatefulWidget {
  const PreAuthKeysScreen({super.key});

  @override
  State<PreAuthKeysScreen> createState() => _PreAuthKeysScreenState();
}

class _PreAuthKeysScreenState extends State<PreAuthKeysScreen> {
  late Future<List<PreAuthKey>> _preAuthKeysFuture;
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _preAuthKeysFuture = context.read<AppProvider>().apiService.getPreAuthKeys();
      _usersFuture = context.read<AppProvider>().apiService.getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Clés de Pré-authentification', style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: FutureBuilder<List<PreAuthKey>>(
        future: _preAuthKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}', style: theme.textTheme.bodyMedium));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Aucune clé de pré-authentification trouvée.', style: theme.textTheme.bodyMedium));
          }

          final allKeys = snapshot.data!;
          final activeKeys = allKeys.where((key) {
            final isExpired = key.expiration != null && key.expiration!.isBefore(DateTime.now());
            return !isExpired && !key.used;
          }).toList();

          if (activeKeys.isEmpty) {
            return Center(child: Text('Aucune clé de pré-authentification active.', style: theme.textTheme.bodyMedium));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: activeKeys.length,
            itemBuilder: (context, index) {
              final key = activeKeys[index];
              return _PreAuthKeyCard(apiKey: key, onAction: _refreshData);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewKey,
        tooltip: 'Créer une clé de pré-authentification',
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  

  Future<void> _createNewKey() async {
    final result = await showDialog<PreAuthKey?>( 
      context: context,
      builder: (ctx) => CreatePreAuthKeyDialog(usersFuture: _usersFuture),
    );
    if (result != null && mounted) {
      _refreshData();
      showSafeSnackBar(context, 'Clé de pré-authentification créée.');
      final appProvider = context.read<AppProvider>();
      final serverUrl = await appProvider.storageService.getServerUrl();
      final String loginServer = serverUrl?.endsWith('/') == true ? serverUrl!.substring(0, serverUrl.length - 1) : serverUrl ?? '';
      _showTailscaleUpCommandDialog(context, result, loginServer);
    }
  }

  void _showTailscaleUpCommandDialog(BuildContext context, PreAuthKey key, String loginServer) {
    final theme = Theme.of(context);
    final fullCommand = 'tailscale up --login-server=$loginServer --authkey=${key.key}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande d\'enregistrement', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Copiez et exécutez cette commande sur votre appareil pour vous connecter.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SelectableText(fullCommand, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Expirer la clé', style: theme.textTheme.labelLarge?.copyWith(color: Colors.red)),
            onPressed: () async {
              try {
                final apiService = context.read<AppProvider>().apiService;
                await apiService.expirePreAuthKey(key.user!.id, key.key);
                _refreshData();
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Clé expirée avec succès.');
              } catch (e) {
                showSafeSnackBar(context, 'Erreur lors de l\'expiration de la clé: $e');
              }
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.copy, color: theme.colorScheme.onPrimary), 
            label: Text('Copier', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _PreAuthKeyCard extends StatelessWidget {
  final PreAuthKey apiKey;
  final VoidCallback onAction;

  const _PreAuthKeyCard({required this.apiKey, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text('Clé: ...${apiKey.key.substring(apiKey.key.length - 6)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, fontFamily: 'monospace')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Utilisateur: ${apiKey.user?.name ?? 'N/A'}', style: theme.textTheme.bodyMedium),
            Text('Expiration: ${apiKey.expiration?.toLocal() ?? 'Jamais'}', style: theme.textTheme.bodyMedium),
            Row(
              children: [
                Text('Réutilisable: ${apiKey.reusable ? 'Oui' : 'Non'}', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Text('Éphémère: ${apiKey.ephemeral ? 'Oui' : 'Non'}', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.timer_off, color: Colors.redAccent),
          tooltip: 'Expirer la clé',
          onPressed: () => _expireKey(context),
        ),
        onTap: () => _handleTap(context),
      ),
    );
  }

  Future<void> _expireKey(BuildContext context) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Expirer la clé ?', style: theme.textTheme.titleLarge),
        content: Text('Voulez-vous vraiment faire expirer cette clé ? L\'action est irréversible.', style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text('Annuler', style: theme.textTheme.labelLarge)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Expirer', style: theme.textTheme.labelLarge?.copyWith(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && context.mounted) {
      try {
        await context.read<AppProvider>().apiService.expirePreAuthKey(apiKey.user!.id, apiKey.key);
        showSafeSnackBar(context, 'Clé expirée avec succès.');
        onAction(); // This will trigger the refresh
      } catch (e) {
        showSafeSnackBar(context, 'Erreur lors de l\'expiration de la clé: $e');
      }
    }
  }

  void _handleTap(BuildContext context) async {
    final theme = Theme.of(context);
    final appProvider = context.read<AppProvider>();
    final serverUrl = await appProvider.storageService.getServerUrl();
    final String loginServer = serverUrl?.endsWith('/') == true ? serverUrl!.substring(0, serverUrl.length - 1) : serverUrl ?? '';
    final fullCommand = 'tailscale up --login-server=$loginServer --authkey=${apiKey.key}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commande d\'enregistrement', style: theme.textTheme.titleLarge),
        content: SelectableText(fullCommand, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(context, 'Commande copiée !');
            },
            child: Text('Copier', style: theme.textTheme.labelLarge),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Fermer', style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}
