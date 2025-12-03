import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Importation pour le QR code

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
      _preAuthKeysFuture =
          context.read<AppProvider>().apiService.getPreAuthKeys();
      _usersFuture = context.read<AppProvider>().apiService.getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
            isFr ? 'Clés de Pré-authentification' : 'Pre-authentication Keys',
            style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: FutureBuilder<List<PreAuthKey>>(
        future: _preAuthKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}',
                    style: theme.textTheme.bodyMedium));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Text(
                    isFr
                        ? 'Aucune clé de pré-authentification trouvée.'
                        : 'No pre-authentication keys found.',
                    style: theme.textTheme.bodyMedium));
          }

          final allKeys = snapshot.data!;
          final activeKeys = allKeys.where((key) {
            final isExpired = key.expiration != null &&
                key.expiration!.isBefore(DateTime.now());
            return !isExpired && !key.used;
          }).toList();

          if (activeKeys.isEmpty) {
            return Center(
                child: Text(
                    isFr
                        ? 'Aucune clé de pré-authentification active.'
                        : 'No active pre-authentication keys.',
                    style: theme.textTheme.bodyMedium));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: activeKeys.length,
            itemBuilder: (context, index) {
              final key = activeKeys[index];
              return _PreAuthKeyCard(
                apiKey: key,
                onAction: _refreshData,
                onShowQrCode: _showQrCodeDialog, // Passer la fonction ici
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewKey,
        tooltip: isFr
            ? 'Créer une clé de pré-authentification'
            : 'Create a pre-authentication key',
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Future<void> _createNewKey() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final result = await showDialog<PreAuthKey?>(
      context: context,
      builder: (ctx) => CreatePreAuthKeyDialog(usersFuture: _usersFuture),
    );
    if (result != null && mounted) {
      _refreshData();
      showSafeSnackBar(
          context,
          isFr
              ? 'Clé de pré-authentification créée.'
              : 'Pre-authentication key created.');
      final appProvider = context.read<AppProvider>();
      final serverUrl = await appProvider.storageService.getServerUrl();
      final String loginServer = serverUrl?.endsWith('/') == true
          ? serverUrl!.substring(0, serverUrl.length - 1)
          : serverUrl ?? '';
      _showTailscaleUpCommandDialog(context, result, loginServer);
    }
  }

  void _showTailscaleUpCommandDialog(
      BuildContext context, PreAuthKey key, String loginServer) {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final fullCommand =
        'tailscale up --login-server=$loginServer --authkey=${key.key}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            isFr ? 'Commande d\'enregistrement' : 'Registration Command',
            style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isFr
                    ? 'Copiez et exécutez cette commande sur votre appareil pour vous connecter.'
                    : 'Copy and run this command on your device to connect.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SelectableText(fullCommand,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            child: Text(isFr ? 'Expirer la clé' : 'Expire Key',
                style: theme.textTheme.labelLarge?.copyWith(color: Colors.red)),
            onPressed: () async {
              try {
                final apiService = context.read<AppProvider>().apiService;
                await apiService.expirePreAuthKey(key.user!.id, key.key);
                _refreshData();
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Clé expirée avec succès.'
                        : 'Key expired successfully.');
              } catch (e) {
                showSafeSnackBar(context,
                    '${isFr ? 'Erreur lors de l\'expiration de la clé' : 'Error expiring key'}: $e');
              }
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code, color: theme.colorScheme.onPrimary),
            label: Text('QR Code',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () {
              Navigator.of(context).pop(); // Ferme le dialogue actuel
              _showQrCodeDialog(
                  context, fullCommand); // Ouvre le dialogue QR Code
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.copy, color: theme.colorScheme.onPrimary),
            label: Text(isFr ? 'Copier' : 'Copy',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(
                  context,
                  isFr
                      ? 'Commande copiée dans le presse-papiers !'
                      : 'Command copied to clipboard!');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context, String data) {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFr ? 'QR Code pour la commande' : 'QR Code for command',
            style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: data,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorStateBuilder: (cxt, err) {
                return Center(
                  child: Text(
                    'Uh oh! Something went wrong :($err)',
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
                isFr
                    ? 'Scannez ce QR code avec votre appareil mobile pour obtenir la commande.'
                    : 'Scan this QR code with your mobile device to get the command.',
                style: theme.textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isFr ? 'Fermer' : 'Close',
                style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}

class _PreAuthKeyCard extends StatelessWidget {
  final PreAuthKey apiKey;
  final VoidCallback onAction;
  final Function(BuildContext, String) onShowQrCode; // Nouveau callback

  const _PreAuthKeyCard({
    required this.apiKey,
    required this.onAction,
    required this.onShowQrCode, // Requis
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Card(
      elevation: 0,
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const Icon(Icons.check_circle, color: Colors.green),
        title: Text(
            '${isFr ? 'Clé' : 'Key'}: ...${apiKey.key.substring(apiKey.key.length - 6)}',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500, fontFamily: 'monospace')),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
                '${isFr ? 'Utilisateur' : 'User'}: ${apiKey.user?.name ?? 'N/A'}',
                style: theme.textTheme.bodyMedium),
            Text(
                '${isFr ? 'Expiration' : 'Expiration'}: ${apiKey.expiration?.toLocal() ?? (isFr ? 'Jamais' : 'Never')}',
                style: theme.textTheme.bodyMedium),
            Row(
              children: [
                Text(
                    '${isFr ? 'Réutilisable' : 'Reusable'}: ${apiKey.reusable ? (isFr ? 'Oui' : 'Yes') : (isFr ? 'Non' : 'No')}',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(width: 8),
                Text(
                    '${isFr ? 'Éphémère' : 'Ephemeral'}: ${apiKey.ephemeral ? (isFr ? 'Oui' : 'Yes') : (isFr ? 'Non' : 'No')}',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.timer_off, color: Colors.redAccent),
          tooltip: isFr ? 'Expirer la clé' : 'Expire key',
          onPressed: () => _expireKey(context),
        ),
        onTap: () => _handleTap(context),
      ),
    );
  }

  Future<void> _expireKey(BuildContext context) async {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Expirer la clé ?' : 'Expire key?',
                style: theme.textTheme.titleLarge),
            content: Text(
                isFr
                    ? 'Voulez-vous vraiment faire expirer cette clé ? L\'action est irréversible.'
                    : 'Do you really want to expire this key? The action is irreversible.',
                style: theme.textTheme.bodyMedium),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(isFr ? 'Annuler' : 'Cancel',
                      style: theme.textTheme.labelLarge)),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isFr ? 'Expirer' : 'Expire',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm && context.mounted) {
      try {
        await context
            .read<AppProvider>()
            .apiService
            .expirePreAuthKey(apiKey.user!.id, apiKey.key);
        showSafeSnackBar(context,
            isFr ? 'Clé expirée avec succès.' : 'Key expired successfully.');
        onAction(); // This will trigger the refresh
      } catch (e) {
        showSafeSnackBar(context,
            '${isFr ? 'Erreur lors de l\'expiration de la clé' : 'Error expiring key'}: $e');
      }
    }
  }

  void _handleTap(BuildContext context) async {
    final theme = Theme.of(context);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final appProvider = context.read<AppProvider>();
    final serverUrl = await appProvider.storageService.getServerUrl();
    final String loginServer = serverUrl?.endsWith('/') == true
        ? serverUrl!.substring(0, serverUrl.length - 1)
        : serverUrl ?? '';
    final fullCommand =
        'tailscale up --login-server=$loginServer --authkey=${apiKey.key}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            isFr ? 'Commande d\'enregistrement' : 'Registration Command',
            style: theme.textTheme.titleLarge),
        content: SelectableText(fullCommand,
            style:
                theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code, color: theme.colorScheme.onPrimary),
            label: Text('QR Code',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () {
              Navigator.of(context).pop(); // Ferme le dialogue actuel
              onShowQrCode(context, fullCommand); // Utilise le callback
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.copy, color: theme.colorScheme.onPrimary),
            label: Text(isFr ? 'Copier' : 'Copy',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onPrimary)),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(
                  context, isFr ? 'Commande copiée !' : 'Command copied!');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isFr ? 'Fermer' : 'Close',
                style: theme.textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}
