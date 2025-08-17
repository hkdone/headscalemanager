import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:headscalemanager/widgets/create_user_dialog.dart'; // New import
import 'package:headscalemanager/widgets/delete_user_dialog.dart'; // New import
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart'; // Extracted earlier

/// Écran de gestion des utilisateurs Headscale.
///
/// Permet de visualiser, créer et supprimer des utilisateurs, ainsi que de
/// générer des clés de pré-authentification.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  /// Future qui contiendra la liste des utilisateurs récupérés depuis l'API.
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  /// Rafraîchit la liste des utilisateurs en effectuant un nouvel appel API.
  void _refreshUsers() {
    setState(() {
      _usersFuture = context.read<AppProvider>().apiService.getUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          // Affiche un indicateur de chargement pendant la récupération des utilisateurs.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Affiche un message d'erreur si la récupération des utilisateurs échoue.
          if (snapshot.hasError) {
            debugPrint('Erreur lors du chargement des utilisateurs : ${snapshot.error}');
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          // Affiche un message si aucun utilisateur n'est trouvé.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun utilisateur trouvé.'));
          }

          final users = snapshot.data!;

          // Construit une liste déroulante des utilisateurs.
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
                      // Affiche le dialogue de suppression d'utilisateur.
                      showDialog(
                        context: context,
                        builder: (ctx) => DeleteUserDialog(
                          user: user,
                          onUserDeleted: _refreshUsers, // Rafraîchit la liste après suppression
                        ),
                      );
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
                  // Navigue vers l'écran de détails de l'utilisateur au tap.
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => UserDetailScreen(user: user),
                  )).then((_) => _refreshUsers()); // Rafraîchit la liste après le retour.
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton flottant pour créer un nouvel utilisateur.
          FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => CreateUserDialog(
                  onUserCreated: _refreshUsers, // Rafraîchit la liste après création
                ),
              );
            },
            heroTag: 'createUser',
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          // Bouton flottant pour créer une clé de pré-authentification.
          FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => CreatePreAuthKeyDialog(
                  onKeyCreated: _refreshUsers, // Rafraîchit la liste après création de clé
                ),
              );
            },
            heroTag: 'createKey',
            child: const Icon(Icons.vpn_key),
          ),
        ],
      ),
    );
  }
}