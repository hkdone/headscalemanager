import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:headscalemanager/screens/pre_auth_keys_screen.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_user_dialog.dart';
import 'package:headscalemanager/widgets/delete_user_dialog.dart';

// Couleurs pour le thème épuré style iOS
const Color _backgroundColor = Color(0xFFF2F2F7);
const Color _primaryTextColor = Colors.black87;
const Color _secondaryTextColor = Colors.black54;
const Color _accentColor = Colors.blue;

/// Écran de gestion des utilisateurs Headscale.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              debugPrint('Erreur lors du chargement des utilisateurs : ${snapshot.error}');
              return Center(child: Text('Erreur : ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucun utilisateur trouvé.'));
            }

            final users = snapshot.data!;

            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(user: user, onUserAction: _refreshUsers);
              },
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PreAuthKeysScreen()));
          },
          heroTag: 'managePreAuthKeys',
          tooltip: 'Gérer les clés d\'accès',
          backgroundColor: _accentColor,
          child: const Icon(Icons.vpn_key, color: Colors.white),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => CreateUserDialog(onUserCreated: _refreshUsers),
            );
          },
          heroTag: 'createUser',
          tooltip: 'Créer un utilisateur',
          backgroundColor: _accentColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onUserAction;

  const _UserCard({required this.user, required this.onUserAction});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserDetailScreen(user: user),
        )).then((_) => onUserAction());
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.person, size: 48, color: _accentColor),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryTextColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Créé le: ${user.createdAt?.toLocal().toString().substring(0, 10) ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: _secondaryTextColor),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onSelected: (value) {
                  if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (ctx) => DeleteUserDialog(user: user, onUserDeleted: onUserAction),
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
            ),
          ],
        ),
      ),
    );
  }
}