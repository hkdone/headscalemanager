import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Dialogue pour déplacer un nœud vers un autre utilisateur.
///
/// Permet à l'utilisateur de sélectionner un utilisateur cible parmi la liste
/// des utilisateurs existants et de déplacer le nœud vers cet utilisateur.
class MoveNodeDialog extends StatefulWidget {
  /// Le nœud à déplacer.
  final Node node;

  /// Fonction de rappel appelée après le déplacement réussi du nœud.
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return AlertDialog(
      title: const Text('Déplacer l\'appareil'),
      content: FutureBuilder<List<User>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100, // Hauteur fixe pour éviter le redimensionnement
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            debugPrint('Erreur lors du chargement des utilisateurs pour déplacer le nœud : ${snapshot.error}');
            return Text('Échec du chargement des utilisateurs : ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Text('Aucun autre utilisateur disponible pour déplacer l\'appareil.');
          }

          final users = snapshot.data!;
          // Filtre l'utilisateur actuel du nœud pour ne pas le proposer comme destination.
          final otherUsers = users.where((u) => u.name != widget.node.user).toList();

          if (otherUsers.isEmpty) {
            return const Text('Aucun autre utilisateur disponible pour déplacer l\'appareil.');
          }

          // Sélectionne le premier utilisateur différent par défaut si aucun n'est sélectionné.
          if (_selectedUser == null) {
            _selectedUser = otherUsers.first;
          }

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
            decoration: const InputDecoration(
              labelText: 'Sélectionner un utilisateur',
              border: OutlineInputBorder(),
            ),
          );
        },
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Déplacer'),
          onPressed: () async {
            if (_selectedUser != null) {
              try {
                await provider.apiService.moveNode(widget.node.id, _selectedUser!.name);
                Navigator.of(context).pop(); // Ferme le dialogue
                widget.onNodeMoved(); // Appelle le callback pour rafraîchir la liste
                showSafeSnackBar(context, 'Appareil déplacé avec succès.');
              } catch (e) {
                debugPrint('Erreur lors du déplacement de l\'appareil : $e');
                if (!mounted) return;
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Échec du déplacement de l\'appareil : $e');
              }
            }
          },
        ),
      ],
    );
  }
}
