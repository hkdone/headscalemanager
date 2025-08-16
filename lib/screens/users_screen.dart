import 'package:flutter/material.dart';

import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/services/storage_service.dart';



class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = context.read<AppProvider>().apiService.getUsers();
    });
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Créer un utilisateur'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Nom de l'utilisateur"),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Créer'),
              onPressed: () async {
                final String name = nameController.text.trim();
                const String suffix = '@nasfilecloud.synology.me';

                if (name.isNotEmpty) {
                  String finalName = name;
                  if (!name.endsWith(suffix)) {
                    finalName = '$name$suffix';
                  }

                  final provider = context.read<AppProvider>();
                  try {
                    await provider.apiService.createUser(finalName);
                    Navigator.of(dialogContext).pop();
                    _refreshUsers();
                  } catch (e) {
                    print('Erreur lors de la création de l\'utilisateur : $e');
                    if (!mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Échec de la création de l\'utilisateur : $e'),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteUserDialog(User user) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l\'utilisateur ?'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer ${user.name} ?\n\nNote : La suppression échouera si l\'utilisateur possède encore des appareils.'),
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
                  await provider.apiService.deleteUser(user.id);
                  Navigator.of(dialogContext).pop();
                  _refreshUsers();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Utilisateur ${user.name} supprimé.'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ));
                } catch (e) {
                  print('Erreur lors de la suppression de l\'utilisateur : $e');
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Échec de la suppression de l\'utilisateur : $e'),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ));
                }
              },
            ),
          ],
        );
      },
    );
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
                          isExpanded: true, // Add this line
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
                            Text('La commande d\'enregistrement de l\'appareil a été générée.'),
                            const SizedBox(height: 16),
                            Text('Veuillez copier cette commande et l\'envoyer au client pour qu\'il l\'exécute sur son appareil.'),
                            const SizedBox(height: 16),
                          ],
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Fermer'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          ElevatedButton.icon( // Use ElevatedButton for more prominence
                            icon: const Icon(Icons.copy),
                            label: const Text('Copier la commande pour le client'),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: fullCommand));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Commande copiée dans le presse-papiers !'),
                              ));
                              Navigator.of(context).pop(); // Close dialog after copying
                            },
                          ),
                        ],
                      ),
                    );
                    // _refreshPreAuthKeys(); // Refresh the list after creating a key - This line is not needed here
                    _refreshUsers(); // Refresh the user list after creating a key
                  } catch (e) {
                    print('Erreur lors de la création de la clé : $e');
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Échec de la création de la clé : $e'),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ));
                  }
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
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('Erreur lors du chargement des utilisateurs : ${snapshot.error}');
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun utilisateur trouvé.'));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text('Créé le : ${user.createdAt.toLocal()}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteUserDialog(user);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Supprimer l\'utilisateur'),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserDetailScreen(user: user),
                  )).then((_) => _refreshUsers());
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _showCreateUserDialog,
            heroTag: 'createUser',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () => _showCreatePreAuthKeyDialog(context),
            heroTag: 'createKey',
            child: const Icon(Icons.vpn_key),
          ),
        ],
      ),
    );
  }


}