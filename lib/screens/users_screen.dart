import 'package:flutter/material.dart';

import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/screens/pre_auth_keys_screen.dart';

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
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreAuthKeysScreen()));
            },
            heroTag: 'manageKeys', // Mettre à jour le heroTag si nécessaire
            child: const Icon(Icons.vpn_key), // L'icône de la clé
          ),
        ],
      ),
    );
  }


}