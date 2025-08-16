import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/models/user.dart'; // Nécessaire pour le dialogue de création

class PreAuthKeysScreen extends StatefulWidget {
  const PreAuthKeysScreen({super.key});

  @override
  State<PreAuthKeysScreen> createState() => _PreAuthKeysScreenState();
}

class _PreAuthKeysScreenState extends State<PreAuthKeysScreen> {
  late Future<List<PreAuthKey>> _preAuthKeysFuture;

  @override
  void initState() {
    super.initState();
    _refreshPreAuthKeys();
  }

  void _refreshPreAuthKeys() {
    setState(() {
      _preAuthKeysFuture = context.read<AppProvider>().apiService.getPreAuthKeys();
    });
  }

  void _showCreatePreAuthKeyDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    User? selectedUser;
    bool isReusable = false;
    bool isEphemeral = false;
    final expirationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Créer une clé de pré-authentification'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<List<User>>(
                      future: provider.apiService.getUsers(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final users = snapshot.data!;
                        if (selectedUser == null && users.isNotEmpty) {
                          selectedUser = users.first;
                        }
                        return DropdownButtonFormField<User>(
                          value: selectedUser,
                          items: users.map((user) {
                            return DropdownMenuItem<User>(
                              value: user,
                              child: Text(user.name),
                            );
                          }).toList(),
                          onChanged: (user) {
                            setState(() {
                              selectedUser = user;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Sélectionner un utilisateur',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Réutilisable'),
                      value: isReusable,
                      onChanged: (value) {
                        setState(() {
                          isReusable = value!;
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: const Text('Éphémère'),
                      value: isEphemeral,
                      onChanged: (value) {
                        setState(() {
                          isEphemeral = value!;
                        });
                      },
                    ),
                    TextFormField(
                      controller: expirationController,
                      decoration: const InputDecoration(
                        labelText: 'Expiration en jours (facultatif)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Créer'),
              onPressed: () async {
                if (selectedUser != null) {
                  final expirationDays = int.tryParse(expirationController.text);
                  final expiration = expirationDays != null ? DateTime.now().add(Duration(days: expirationDays)) : null;
                  try {
                                        final key = await provider.apiService.createPreAuthKey(
                      selectedUser!.id,
                      isReusable,
                      isEphemeral,
                      expiration: expiration,
                    );
                    final serverUrl = await provider.storageService.getServerUrl();
                    final fullCommand = 'tailscale up --login-server=${serverUrl ?? ''} --authkey=${key.key}';

                    Navigator.of(dialogContext).pop();
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clé de pré-authentification créée'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Utilisez la commande suivante pour enregistrer votre appareil :'),
                            const SizedBox(height: 8),
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
                          TextButton(
                            child: const Text('Copier la commande'),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: fullCommand));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Commande copiée dans le presse-papiers !'),
                              ));
                            },
                          ),
                        ],
                      ),
                    );
                    _refreshPreAuthKeys(); // Refresh the list after creating a key
                  } catch (e) {
                    print('Erreur lors de la création de la clé : $e');
                    Navigator.of(dialogContext).pop();
                    showSafeSnackBar(context, 'Échec de la création de la clé : $e');
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeletePreAuthKeyDialog(PreAuthKey key) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer la clé ?'),
          content: Text('Êtes-vous sûr de vouloir supprimer la clé ${key.key} ?'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                final provider = context.read<AppProvider>();
                try {
                  await provider.apiService.deletePreAuthKey(key.key);
                  Navigator.of(dialogContext).pop();
                  _refreshPreAuthKeys();
                  showSafeSnackBar(context, 'Clé supprimée avec succès.');
                } catch (e) {
                  print('Erreur lors de la suppression de la clé : $e');
                  Navigator.of(dialogContext).pop();
                  showSafeSnackBar(context, 'Échec de la suppression de la clé : $e');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clés de pré-authentification'),
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

          final keys = snapshot.data!;

          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(key.key),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utilisateur : ${key.user}'),
                      Text('Réutilisable : ${key.reusable ? 'Oui' : 'Non'}'),
                      Text('Éphémère : ${key.ephemeral ? 'Oui' : 'Non'}'),
                      if (key.expiration != null)
                        Text('Expire le : ${key.expiration!.toLocal().toShortDateString()}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeletePreAuthKeyDialog(key),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePreAuthKeyDialog(context),
        heroTag: 'createPreAuthKey',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Extension pour formater la date
extension on DateTime {
  String toShortDateString() {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year.toString()}';
  }
}