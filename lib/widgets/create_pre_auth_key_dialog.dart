import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

/// Dialogue pour créer une nouvelle clé de pré-authentification.
///
/// Permet de sélectionner un utilisateur, de définir les propriétés de la clé
/// (réutilisable, éphémère, expiration).
class CreatePreAuthKeyDialog extends StatefulWidget {
  /// Future qui contiendra la liste des utilisateurs.
  final Future<List<User>> usersFuture;

  const CreatePreAuthKeyDialog({super.key, required this.usersFuture});

  @override
  State<CreatePreAuthKeyDialog> createState() => _CreatePreAuthKeyDialogState();
}

class _CreatePreAuthKeyDialogState extends State<CreatePreAuthKeyDialog> {
  User? _selectedUser;
  bool _isReusable = false;
  bool _isEphemeral = false;
  final TextEditingController _expirationController = TextEditingController();

  @override
  void dispose() {
    _expirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();

    return AlertDialog(
      title: const Text('Créer une clé de pré-authentification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sélecteur d'utilisateur pour la clé de pré-authentification.
            FutureBuilder<List<User>>(
              future: widget.usersFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final users = snapshot.data!;
                if (_selectedUser == null && users.isNotEmpty) {
                  _selectedUser = users.first; // Sélectionne le premier utilisateur par défaut
                }
                return DropdownButtonFormField<User>(
                  isExpanded: true,
                  value: _selectedUser,
                  items: users.map((user) {
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
            // Option pour rendre la clé réutilisable.
            CheckboxListTile(
              title: const Text('Réutilisable'),
              value: _isReusable,
              onChanged: (value) {
                setState(() {
                  _isReusable = value!;
                });
              },
            ),
            // Option pour rendre la clé éphémère.
            CheckboxListTile(
              title: const Text('Éphémère'),
              value: _isEphemeral,
              onChanged: (value) {
                setState(() {
                  _isEphemeral = value!;
                });
              },
            ),
            // Champ pour la durée d'expiration en jours.
            TextFormField(
              controller: _expirationController,
              decoration: const InputDecoration(
                labelText: 'Expiration en jours (facultatif)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Annuler'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: const Text('Créer'),
          onPressed: () async {
            if (_selectedUser != null) {
              final expirationDays = int.tryParse(_expirationController.text);
              final expiration = expirationDays != null ? DateTime.now().add(Duration(days: expirationDays)) : null;
              try {
                final key = await provider.apiService.createPreAuthKey(
                  _selectedUser!.id,
                  _isReusable,
                  _isEphemeral,
                  expiration: expiration,
                );
                Navigator.of(context).pop(key); // Return the created key
              } catch (e) {
                debugPrint('Erreur lors de la création de la clé : $e');
                showSafeSnackBar(context, 'Échec de la création de la clé : $e');
                Navigator.of(context).pop(); // Pop the dialog on error
              }
            }
          },
        ),
      ],
    );
  }
}