import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';

class MoveNodeDialog extends StatefulWidget {
  final Node node;
  final VoidCallback onNodeMoved;

  const MoveNodeDialog({super.key, required this.node, required this.onNodeMoved});

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
    if (_selectedUser == null) return;

    final provider = context.read<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';

    // Close the dialog first, as operations will take time
    Navigator.of(context).pop();
    showSafeSnackBar(context, isFr ? 'Déplacement en cours...' : 'Moving device...');

    try {
      await provider.apiService.moveNode(widget.node.id, _selectedUser!);

      bool aclMode = true;
      try {
        await provider.apiService.getAclPolicy();
      } catch (e) {
        aclMode = false;
      }

      if (aclMode) {
        final bool? updateAcls = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(isFr ? 'Mettre à jour les ACLs ?' : 'Update ACLs?'),
            content: Text(isFr
                ? 'Voulez-vous régénérer et appliquer la politique ACL pour refléter ce changement de propriétaire ?'
                : 'Do you want to regenerate and apply the ACL policy to reflect this change of ownership?'),
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

        if (updateAcls == true) {
          showSafeSnackBar(context, isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');

          final allUsers = await provider.apiService.getUsers();
          final allNodes = await provider.apiService.getNodes();
          final tempRules = await provider.storageService.getTemporaryRules();
          final aclGenerator = NewAclGeneratorService();
          final newPolicyMap = aclGenerator.generatePolicy(
              users: allUsers, nodes: allNodes, temporaryRules: tempRules);
          final newPolicyJson = jsonEncode(newPolicyMap);
          await provider.apiService.setAclPolicy(newPolicyJson);

          showSafeSnackBar(context, isFr ? 'Appareil déplacé et ACLs mises à jour !' : 'Device moved and ACLs updated!');
        } else {
          showSafeSnackBar(context, isFr ? 'Appareil déplacé.' : 'Device moved.');
        }
      } else {
        showSafeSnackBar(context, isFr ? 'Appareil déplacé (ACLs non gérées).' : 'Device moved (ACLs not managed).');
      }

      widget.onNodeMoved();

    } catch (e) {
        showSafeSnackBar(context, isFr ? 'Échec du déplacement: $e' : 'Failed to move: $e');
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
