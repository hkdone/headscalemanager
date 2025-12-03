import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:provider/provider.dart';

class MoveNodeDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onNodeMoved;

  const MoveNodeDialog(
      {super.key, required this.node, required this.onNodeMoved});

  @override
  State<MoveNodeDialog> createState() => _MoveNodeDialogState();
}

class _MoveNodeDialogState extends State<MoveNodeDialog> {
  User? _selectedUser;
  late Future<List<User>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<AppProvider>().apiService.getUsers();
  }

  Future<void> _handleMove() async {
    if (_selectedUser == null) {
      Navigator.of(context).pop(false);
      return;
    }

    final provider = context.read<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';

    try {
      // 1. Move node to the new user
      await provider.apiService.moveNode(widget.node.id, _selectedUser!);

      // 2. Update tags to reflect the new owner
      final List<String> oldTags = List.from(widget.node.tags);
      String capabilities = '';
      final clientTag =
          oldTags.firstWhere((t) => t.contains('-client'), orElse: () => '');

      if (clientTag.isNotEmpty) {
        if (clientTag.contains(';')) {
          capabilities = clientTag.substring(clientTag.indexOf(';'));
        }
      }

      final newUserName = normalizeUserName(_selectedUser!.name);
      final newClientTag = 'tag:$newUserName-client$capabilities';

      final newTags = oldTags.where((tag) => !tag.contains('-client')).toList();
      newTags.add(newClientTag);

      await provider.apiService.setTags(widget.node.id, newTags);

      // 3. Handle ACLs if necessary
      bool aclMode = true;
      try {
        await provider.apiService.getAclPolicy();
      } catch (e) {
        aclMode = false;
      }

      if (aclMode && mounted) {
        final bool? updateAcls = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isFr ? 'Mettre à jour les ACLs ?' : 'Update ACLs?'),
            content: Text(isFr
                ? 'Voulez-vous aussi régénérer la politique ACL pour refléter ce changement ?'
                : 'Do you also want to regenerate the ACL policy to reflect this change?'),
            actions: [
              TextButton(
                child: Text(isFr ? 'Non' : 'No'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              TextButton(
                child: Text(isFr ? 'Oui' : 'Yes'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
            ],
          ),
        );

        if (updateAcls == true && mounted) {
          showSafeSnackBar(
              context, isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');

          final allUsers = await provider.apiService.getUsers();
          final allNodes = await provider.apiService.getNodes();
          final tempRules = await provider.storageService.getTemporaryRules();
          final aclGenerator = NewAclGeneratorService();
          final newPolicyMap = aclGenerator.generatePolicy(
              users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          final newPolicyJson = jsonEncode(newPolicyMap);
          await provider.apiService.setAclPolicy(newPolicyJson);

          showSafeSnackBar(
              context, isFr ? 'ACLs mises à jour !' : 'ACLs updated!');
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
      widget.onNodeMoved();
    } catch (e) {
      if (mounted) {
        // Show error and then pop
        showSafeSnackBar(
            context, isFr ? 'Échec du déplacement: $e' : 'Failed to move: $e');
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Déplacer l\'appareil' : 'Move Device'),
      content: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Text(isFr
                ? 'Échec du chargement des utilisateurs : ${snapshot.error}'
                : 'Failed to load users: ${snapshot.error}');
          }
          final users = snapshot.data ?? [];
          final otherUsers =
              users.where((u) => u.name != widget.node.user).toList();

          if (otherUsers.isEmpty) {
            return Text(isFr
                ? 'Aucun autre utilisateur disponible.'
                : 'No other users available.');
          }

          _selectedUser ??= otherUsers.first;

          return DropdownButtonFormField<User>(
            value: _selectedUser,
            isExpanded: true,
            items: otherUsers.map((user) {
              return DropdownMenuItem<User>(
                value: user,
                child: Text(user.name),
              );
            }).toList(),
            onChanged: (user) {
              setState(() {
                _selectedUser = user;
              });
            },
            decoration: InputDecoration(
              labelText: isFr ? 'Sélectionner un utilisateur' : 'Select a user',
              border: const OutlineInputBorder(),
            ),
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleMove,
          child: Text(isFr ? 'Déplacer' : 'Move'),
        ),
      ],
    );
  }
}
