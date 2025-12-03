import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:headscalemanager/screens/pre_auth_keys_screen.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_user_dialog.dart';
import 'package:headscalemanager/widgets/delete_user_dialog.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';

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
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<List<User>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary));
            }
            if (snapshot.hasError) {
              debugPrint(
                  'Erreur lors du chargement des utilisateurs : ${snapshot.error}');
              return Center(
                  child: Text('${isFr ? 'Erreur' : 'Error'}: ${snapshot.error}',
                      style: theme.textTheme.bodyMedium));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                  child: Text(
                      isFr ? 'Aucun utilisateur trouvé.' : 'No users found.',
                      style: theme.textTheme.bodyMedium));
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
      floatingActionButton: _buildFloatingActionButtons(context),
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PreAuthKeysScreen()));
          },
          heroTag: 'managePreAuthKeys',
          tooltip: isFr ? 'Gérer les clés d\'accès' : 'Manage pre-auth keys',
          backgroundColor: theme.colorScheme.primary,
          child: Icon(Icons.vpn_key, color: theme.colorScheme.onPrimary),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () async {
            final bool? userCreated = await showDialog<bool>(
              context: context,
              builder: (ctx) => const CreateUserDialog(),
            );
            if (userCreated == true) {
              _refreshUsers();
              if (mounted) {
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Utilisateur créé avec succès.'
                        : 'User created successfully.');
              }
            }
          },
          heroTag: 'createUser',
          tooltip: isFr ? 'Créer un utilisateur' : 'Create user',
          backgroundColor: theme.colorScheme.primary,
          child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
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
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(
              builder: (_) => UserDetailScreen(user: user),
            ))
            .then((_) => onUserAction());
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
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
                  Icon(Icons.person,
                      size: 48, color: theme.colorScheme.onPrimary),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isFr ? 'Créé le' : 'Created on'}: ${user.createdAt?.toLocal().toString().substring(0, 10) ?? 'N/A'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
                onSelected: (value) {
                  if (value == 'delete') {
                    showDialog(
                      context: context,
                      builder: (ctx) => DeleteUserDialog(
                          user: user, onUserDeleted: onUserAction),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete,
                          color: Colors.red,
                          semanticLabel: isFr
                              ? 'Supprimer l\'utilisateur'
                              : 'Delete user'),
                      title: Text(
                          isFr ? 'Supprimer l\'utilisateur' : 'Delete user',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme
                                  .onSurface)), // Keep default onSurface for menu item
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
