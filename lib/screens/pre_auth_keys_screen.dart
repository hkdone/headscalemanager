import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;
const Color _accentColor = Colors.blue;

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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Clés de Pré-authentification', style: TextStyle(color: _primaryTextColor)),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_off),
            tooltip: 'Expirer toutes les clés',
            onPressed: _expireAllKeys,
          ),
        ],
      ),
      body: FutureBuilder<List<PreAuthKey>>(
        future: _preAuthKeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune clé de pré-authentification trouvée.'));
          }

          final preAuthKeys = snapshot.data!;
          preAuthKeys.sort((a, b) {
            final aExpired = a.expiration != null && a.expiration!.isBefore(DateTime.now());
            final bExpired = b.expiration != null && b.expiration!.isBefore(DateTime.now());
            if (aExpired && !bExpired) return 1;
            if (!aExpired && bExpired) return -1;
            return 0;
          });

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: preAuthKeys.length,
            itemBuilder: (context, index) {
              final key = preAuthKeys[index];
              return _PreAuthKeyCard(apiKey: key, onAction: _refreshData);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewKey,
        tooltip: 'Créer une clé de pré-authentification',
        backgroundColor: _accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _expireAllKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expirer toutes les clés ?'),
        content: const Text('Êtes-vous sûr de vouloir expirer toutes les clés de pré-authentification ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Expirer tout', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      final preAuthKeys = await _preAuthKeysFuture;
      final apiService = context.read<AppProvider>().apiService;
      for (final key in preAuthKeys) {
        if (key.user != null && key.key.isNotEmpty) {
          try {
            await apiService.expirePreAuthKey(key.user!.id, key.key);
          } catch (e) {
            debugPrint('Erreur lors de l\'expiration de la clé ${key.key}: $e');
          }
        }
      }
      _refreshData();
      showSafeSnackBar(context, 'Toutes les clés ont été expirées.');
    }
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
    final fullCommand = 'tailscale up --login-server=$loginServer --authkey=${key.key}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commande d\'enregistrement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copiez et exécutez cette commande sur votre appareil pour vous connecter.'),
            const SizedBox(height: 16),
            SelectableText(fullCommand, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Expirer la clé'),
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
            icon: const Icon(Icons.copy), 
            label: const Text('Copier'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
            },
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
    final isExpired = apiKey.expiration != null && apiKey.expiration!.isBefore(DateTime.now());
    final isUsed = apiKey.used;

    return Opacity(
      opacity: isExpired || isUsed ? 0.5 : 1.0,
      child: Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: Icon(isExpired || isUsed ? Icons.do_not_disturb_on : Icons.check_circle, color: isExpired || isUsed ? Colors.grey : Colors.green),
          title: Text('Clé: ...${apiKey.key.substring(apiKey.key.length - 6)}', style: const TextStyle(fontWeight: FontWeight.w500, color: _primaryTextColor, fontSize: 16, fontFamily: 'monospace')),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('Utilisateur: ${apiKey.user?.name ?? 'N/A'}', style: const TextStyle(color: _secondaryTextColor)),
              Text('Expiration: ${apiKey.expiration?.toLocal() ?? 'Jamais'}', style: const TextStyle(color: _secondaryTextColor)),
              Row(
                children: [
                  Text('Réutilisable: ${apiKey.reusable ? 'Oui' : 'Non'}', style: const TextStyle(color: _secondaryTextColor)),
                  const SizedBox(width: 8),
                  Text('Éphémère: ${apiKey.ephemeral ? 'Oui' : 'Non'}', style: const TextStyle(color: _secondaryTextColor)),
                ],
              ),
            ],
          ),
          onTap: () => _handleTap(context),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) async {
    final isExpired = apiKey.expiration != null && apiKey.expiration!.isBefore(DateTime.now());
    if (isExpired) {
      showSafeSnackBar(context, 'Cette clé est expirée et ne peut pas être utilisée.');
      return;
    }
    if (apiKey.used) {
      showSafeSnackBar(context, 'Cette clé a déjà été utilisée.');
      return;
    }

    final appProvider = context.read<AppProvider>();
    final serverUrl = await appProvider.storageService.getServerUrl();
    final String loginServer = serverUrl?.endsWith('/') == true ? serverUrl!.substring(0, serverUrl.length - 1) : serverUrl ?? '';
    final fullCommand = 'tailscale up --login-server=$loginServer --authkey=${apiKey.key}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commande d\'enregistrement'),
        content: SelectableText(fullCommand, style: const TextStyle(fontFamily: 'monospace')),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(context, 'Commande copiée !');
            },
            child: const Text('Copier'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}