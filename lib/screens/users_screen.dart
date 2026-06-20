import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/user_detail_screen.dart';
import 'package:headscalemanager/screens/pre_auth_keys_screen.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/widgets/create_user_dialog.dart';
import 'package:headscalemanager/widgets/delete_user_dialog.dart';
import 'package:headscalemanager/widgets/rename_user_dialog.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';


/// Écran de gestion des utilisateurs Headscale.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<({List<User> users, List<Node> nodes})> _usersDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshUsers();
  }

  void _refreshUsers() {
    if (mounted) {
      setState(() {
        _usersDataFuture = _loadAndFixUsers();
      });
    }
  }

  /// Charge les utilisateurs et les nœuds, puis corrige automatiquement ceux créés par OIDC
  /// avec un nom vide côté serveur, en utilisant leur email comme nom via l'API.
  Future<({List<User> users, List<Node> nodes})> _loadAndFixUsers() async {
    final apiService = context.read<AppProvider>().apiService;
    final results = await Future.wait([
      apiService.getUsers(),
      apiService.getNodes(),
    ]);

    var users = results[0] as List<User>;
    final nodes = results[1] as List<Node>;

    // Signal : OIDC user dont le nom a été résolu depuis l'email (server name était "")
    // Condition : provider renseigné + email dispo + name == email (fallback appliqué dans fromJson)
    final toFix = users
        .where((u) =>
            u.provider != null &&
            u.provider!.isNotEmpty &&
            u.email != null &&
            u.email!.isNotEmpty &&
            u.name == u.email)
        .toList();

    if (toFix.isNotEmpty) {
      bool anyFixed = false;
      for (final user in toFix) {
        try {
          await apiService.renameUser(user.id, user.email!);
          anyFixed = true;
        } catch (_) {
          // Silencieux : si le renommage échoue
        }
      }
      if (anyFixed) {
        users = await apiService.getUsers();
      }
    }

    return (users: users, nodes: nodes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppProvider>();
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';
    final viewMode = provider.usersViewMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<({List<User> users, List<Node> nodes})>(
          future: _usersDataFuture,
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
            if (!snapshot.hasData || snapshot.data!.users.isEmpty) {
              return Center(
                  child: Text(
                      isFr ? 'Aucun utilisateur trouvé.' : 'No users found.',
                      style: theme.textTheme.bodyMedium));
            }

            final users = snapshot.data!.users;
            final nodes = snapshot.data!.nodes;

            if (viewMode == 'list') {
              return ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserListTile(
                    user: user,
                    nodes: nodes,
                    onUserAction: _refreshUsers,
                  );
                },
              );
            }

            final double screenWidth = MediaQuery.of(context).size.width;
            final int crossAxisCount = screenWidth < 600 ? 2 : 3;
            final double childAspectRatio = screenWidth < 600 ? 0.74 : 0.85;

            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return _UserCard(
                  user: user,
                  nodes: nodes,
                  onUserAction: _refreshUsers,
                );
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
              if (context.mounted) {
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
  final List<Node> nodes;
  final VoidCallback onUserAction;

  const _UserCard({
    required this.user,
    required this.nodes,
    required this.onUserAction,
  });

  void _showIconPickerDialog(BuildContext context, AppProvider provider) {
    final theme = Theme.of(context);
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFr ? 'Personnaliser l\'icône' : 'Customize Icon',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  height: 280,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: userIconsPalette.length,
                    itemBuilder: (context, index) {
                      final key = userIconsPalette.keys.elementAt(index);
                      final iconData = userIconsPalette[key]!;
                      final isSelected = provider.getUserIcon(user.id) == key;

                      return InkWell(
                        onTap: () {
                          provider.setUserIcon(user.id, key);
                          Navigator.of(dialogContext).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.onPrimary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            iconData,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked != null) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final String extension = picked.path.split('.').last;
                      final String newPath = '${appDir.path}/custom_avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
                      await File(picked.path).copy(newPath);
                      await provider.setUserIcon(user.id, newPath);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: Text(isFr ? 'Importer une photo' : 'Import a photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppProvider>();
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';

    final iconKey = provider.getUserIcon(user.id);
    final isCustomImage = iconKey.contains('/') || iconKey.contains('\\');
    final customImageExists = isCustomImage && File(iconKey).existsSync();

    final userNodes = nodes
        .where((node) =>
            node.userId == user.id ||
            node.user == user.name ||
            node.getNormalizedOwner() == normalizeUserName(user.name))
        .toList();
    final connectedNodes = userNodes.where((n) => n.online).length;

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
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (user.profilePicUrl != null &&
                        user.profilePicUrl!.isNotEmpty)
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(user.profilePicUrl!),
                        backgroundColor: Colors.transparent,
                      )
                    else if (customImageExists)
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: FileImage(File(iconKey)),
                        backgroundColor: Colors.transparent,
                      )
                    else
                      Icon(userIconsPalette[iconKey] ?? Icons.person,
                          size: 36, color: theme.colorScheme.onPrimary),
                    const SizedBox(height: 6),
                    if (user.provider != null && user.provider!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user.provider!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 8),
                        ),
                      ),
                    Text(
                      user.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user.email != null && user.email!.isNotEmpty)
                      Text(
                        user.email!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimary
                                .withValues(alpha: 0.8),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${isFr ? 'Créé le' : 'Created on'}: ${user.createdAt?.toLocal().toString().substring(0, 10) ?? 'N/A'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                          fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Reactive nodes connectivity count badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: connectedNodes > 0
                            ? Colors.green.withValues(alpha: 0.2)
                            : theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: connectedNodes > 0
                              ? Colors.green.withValues(alpha: 0.5)
                              : theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: connectedNodes > 0 ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$connectedNodes/${userNodes.length} ${isFr ? 'connectés' : 'online'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  } else if (value == 'rename') {
                    showDialog(
                      context: context,
                      builder: (ctx) => RenameUserDialog(
                          user: user, onUserRenamed: onUserAction),
                    );
                  } else if (value == 'change_icon') {
                    _showIconPickerDialog(context, provider);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (user.provider == null || user.provider!.isEmpty)
                    PopupMenuItem<String>(
                      value: 'change_icon',
                      child: ListTile(
                        leading: Icon(Icons.image,
                            color: theme.colorScheme.onSurface,
                            semanticLabel: isFr ? 'Personnaliser l\'icône' : 'Customize icon'),
                        title: Text(
                            isFr ? 'Personnaliser l\'icône' : 'Customize icon',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface)),
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: const Icon(Icons.delete,
                          color: Colors.red,
                          semanticLabel: 'Delete user'),
                      title: Text(
                          isFr ? 'Supprimer l\'utilisateur' : 'Delete user',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface)),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit,
                          color: theme.colorScheme.onSurface,
                          semanticLabel: 'Rename user'),
                      title: Text(
                          isFr ? 'Renommer l\'utilisateur' : 'Rename user',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurface)),
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

class _UserListTile extends StatelessWidget {
  final User user;
  final List<Node> nodes;
  final VoidCallback onUserAction;

  const _UserListTile({
    required this.user,
    required this.nodes,
    required this.onUserAction,
  });

  void _showIconPickerDialog(BuildContext context, AppProvider provider) {
    final theme = Theme.of(context);
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFr ? 'Personnaliser l\'icône' : 'Customize Icon',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 280,
                  height: 280,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: userIconsPalette.length,
                    itemBuilder: (context, index) {
                      final key = userIconsPalette.keys.elementAt(index);
                      final iconData = userIconsPalette[key]!;
                      final isSelected = provider.getUserIcon(user.id) == key;

                      return InkWell(
                        onTap: () {
                          provider.setUserIcon(user.id, key);
                          Navigator.of(dialogContext).pop();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: theme.colorScheme.onPrimary, width: 2)
                                : null,
                          ),
                          child: Icon(
                            iconData,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (picked != null) {
                      final appDir = await getApplicationDocumentsDirectory();
                      final String extension = picked.path.split('.').last;
                      final String newPath = '${appDir.path}/custom_avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';
                      await File(picked.path).copy(newPath);
                      await provider.setUserIcon(user.id, newPath);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.photo_library),
                  label: Text(isFr ? 'Importer une photo' : 'Import a photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<AppProvider>();
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';

    final iconKey = provider.getUserIcon(user.id);
    final isCustomImage = iconKey.contains('/') || iconKey.contains('\\');
    final customImageExists = isCustomImage && File(iconKey).existsSync();

    final userNodes = nodes
        .where((node) =>
            node.userId == user.id ||
            node.user == user.name ||
            node.getNormalizedOwner() == normalizeUserName(user.name))
        .toList();
    final connectedNodes = userNodes.where((n) => n.online).length;

    Widget avatarWidget;
    if (user.profilePicUrl != null && user.profilePicUrl!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(user.profilePicUrl!),
        backgroundColor: Colors.transparent,
      );
    } else if (customImageExists) {
      avatarWidget = CircleAvatar(
        radius: 20,
        backgroundImage: FileImage(File(iconKey)),
        backgroundColor: Colors.transparent,
      );
    } else {
      avatarWidget = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          userIconsPalette[iconKey] ?? Icons.person,
          size: 24,
          color: theme.colorScheme.onPrimary,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: avatarWidget,
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.provider != null && user.provider!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.provider!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.email != null && user.email!.isNotEmpty)
              Text(
                user.email!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              '${isFr ? 'Créé le' : 'Created on'}: ${user.createdAt?.toLocal().toString().substring(0, 10) ?? 'N/A'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: connectedNodes > 0
                    ? Colors.green.withValues(alpha: 0.2)
                    : theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: connectedNodes > 0
                      ? Colors.green.withValues(alpha: 0.5)
                      : theme.colorScheme.onPrimary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: connectedNodes > 0 ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$connectedNodes/${userNodes.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimary),
              onSelected: (value) {
                if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder: (ctx) => DeleteUserDialog(
                      user: user,
                      onUserDeleted: onUserAction,
                    ),
                  );
                } else if (value == 'rename') {
                  showDialog(
                    context: context,
                    builder: (ctx) => RenameUserDialog(
                      user: user,
                      onUserRenamed: onUserAction,
                    ),
                  );
                } else if (value == 'change_icon') {
                  _showIconPickerDialog(context, provider);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (user.provider == null || user.provider!.isEmpty)
                  PopupMenuItem<String>(
                    value: 'change_icon',
                    child: ListTile(
                      leading: Icon(Icons.image, color: theme.colorScheme.onSurface),
                      title: Text(
                        isFr ? 'Personnaliser l\'icône' : 'Customize icon',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: Text(
                      isFr ? 'Supprimer l\'utilisateur' : 'Delete user',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit, color: theme.colorScheme.onSurface),
                    title: Text(
                      isFr ? 'Renommer l\'utilisateur' : 'Rename user',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => UserDetailScreen(user: user),
              ))
              .then((_) => onUserAction());
        },
      ),
    );
  }
}
