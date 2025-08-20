import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart';
import 'package:headscalemanager/widgets/delete_pre_auth_key_dialog.dart';
import 'package:headscalemanager/services/storage_service.dart';

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
      _preAuthKeysFuture = context
          .read<AppProvider>()
          .apiService
          .getPreAuthKeys();
      _usersFuture = context
          .read<AppProvider>()
          .apiService
          .getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clés de Pré-authentification'),
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
            return const Center(
                child: Text('Aucune clé de pré-authentification trouvée.'));
          }

          final preAuthKeys = snapshot.data!;

          return ListView.builder(
            itemCount: preAuthKeys.length,
            itemBuilder: (context, index) {
              final key = preAuthKeys[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clé : ${key.key}', style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                      Text('Utilisateur : ${key.user?.name ?? 'N/A'}'),
                      Text('Réutilisable : ${key.reusable ? 'Oui' : 'Non'}'),
                      Text('Éphémère : ${key.ephemeral ? 'Oui' : 'Non'}'),
                      Text('Utilisée : ${key.used ? 'Oui' : 'Non'}'),
                      Text('Expiration : ${key.expiration?.toLocal() ??
                          'Jamais'}'),
                      Text('Créée le : ${key.createdAt?.toLocal() ?? 'N/A'}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) =>
                                    DeletePreAuthKeyDialog(preAuthKey: key,
                                        onKeyDeleted: _refreshData),
                              );
                              if (confirm == true) {
                                _refreshData();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Expirer toutes les clés ?'),
                  content: const Text('Êtes-vous sûr de vouloir expirer toutes les clés de pré-authentification ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Expirer tout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final preAuthKeys = await _preAuthKeysFuture;
                final apiService = context.read<AppProvider>().apiService;
                for (final key in preAuthKeys) {
                  if (key.user != null && key.key.isNotEmpty) {
                    try {
                      await apiService.expirePreAuthKey(key.user!.id, key.key);
                    } catch (e) {
                      // Log error but continue with other keys
                      debugPrint('Erreur lors de l\'expiration de la clé ${key.key}: $e');
                    }
                  }
                }
                _refreshData();
                showSafeSnackBar(context, 'Toutes les clés ont été expirées.');
              }
            },
            heroTag: 'expireAllKeys',
            tooltip: 'Expirer toutes les clés',
            child: const Icon(Icons.delete_sweep),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () async {
              final result = await showDialog<PreAuthKey?>( 
                context: context,
                builder: (ctx) => CreatePreAuthKeyDialog(usersFuture: _usersFuture),
              );
              if (result != null) {
                _refreshData();
                showSafeSnackBar(context, 'Clé de pré-authentification créée.');
                final appProvider = context.read<AppProvider>();
                final serverUrl = await appProvider.storageService.getServerUrl();
                final String loginServer = serverUrl?.endsWith('/') == true
                    ? serverUrl!.substring(0, serverUrl.length - 1)
                    : serverUrl ?? '';
                _showTailscaleUpCommandDialog(context, result, loginServer);
              }
            },
            tooltip: 'Créer une clé de pré-authentification',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _showTailscaleUpCommandDialog(BuildContext context, PreAuthKey key, String loginServer) {
    final fullCommand = 'tailscale up --login-server=$loginServer --authkey=${key.key}';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clé de pré-authentification créée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('La commande d\'enregistrement de l\'appareil a été générée.'),
            const SizedBox(height: 16),
            const Text('Veuillez copier cette commande et l\'envoyer au client pour qu\'il l\'exécute sur son appareil.'),
            const SizedBox(height: 16),
            SelectableText(
              fullCommand,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Fermer'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copier la commande pour le client'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullCommand));
              showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}