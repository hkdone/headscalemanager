import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
// For debugPrint

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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Déplacer l\'appareil' : 'Move Device'),
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
            debugPrint(
                'Erreur lors du chargement des utilisateurs pour déplacer le nœud : ${snapshot.error}');
            return Text(isFr
                ? 'Échec du chargement des utilisateurs : ${snapshot.error}'
                : 'Failed to load users: ${snapshot.error}');
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Text(isFr
                ? 'Aucun autre utilisateur disponible pour déplacer l\'appareil.'
                : 'No other user available to move the device.');
          }

          final users = snapshot.data!;
          // Filtre l'utilisateur actuel du nœud pour ne pas le proposer comme destination.
          final otherUsers =
              users.where((u) => u.name != widget.node.user).toList();

          if (otherUsers.isEmpty) {
            return Text(isFr
                ? 'Aucun autre utilisateur disponible pour déplacer l\'appareil.'
                : 'No other user available to move the device.');
          }

          // Sélectionne le premier utilisateur différent par défaut si aucun n'est sélectionné.
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
          child: Text(isFr ? 'Déplacer' : 'Move'),
          onPressed: () async {
            if (_selectedUser != null) {
              try {
                await provider.apiService
                    .moveNode(widget.node.id, _selectedUser!.id);
                Navigator.of(context).pop(); // Ferme le dialogue
                widget.onNodeMoved(); // Appelle le callback pour rafraîchir la liste
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Appareil déplacé avec succès.'
                        : 'Device moved successfully.');
              } catch (e) {
                debugPrint('Erreur lors du déplacement de l\'appareil : $e');
                if (!mounted) return;
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Échec du déplacement de l\'appareil : $e'
                        : 'Failed to move device: $e');
              }
            }
          },
        ),
      ],
    );
  }
}
