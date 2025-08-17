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
/// (réutilisable, éphémère, expiration) et de générer la commande `tailscale up`
/// pour l'enregistrement d'un nouvel appareil.
class CreatePreAuthKeyDialog extends StatefulWidget {
  /// Fonction de rappel appelée après la création réussie d'une clé.
  final VoidCallback onKeyCreated;

  const CreatePreAuthKeyDialog({super.key, required this.onKeyCreated});

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
              future: provider.apiService.getUsers(),
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
                final serverUrl = await provider.storageService.getServerUrl();
                final fullCommand = 'tailscale up --login-server=${serverUrl ?? ''} --authkey=${key.key}';

                Navigator.of(context).pop(); // Ferme le dialogue de création
                // Affiche un nouveau dialogue avec la commande générée.
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clé de pré-authentification créée'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('La commande d\'enregistrement de l\'appareil a été générée.'),
                        const SizedBox(height: 16),
                        const Text('Veuillez copier cette commande et l\'envoyer au client pour qu\'il l\'exécute sur son appareil.'),
                        const SizedBox(height: 16),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: const Text('Fermer'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.copy),
                        label: const Text('Copier la commande pour le client'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: fullCommand));
                          showSafeSnackBar(context, 'Commande copiée dans le presse-papiers !');
                          Navigator.of(context).pop(); // Ferme le dialogue après copie
                        },
                      ),
                    ],
                  ),
                );
                widget.onKeyCreated(); // Appelle le callback pour rafraîchir la liste
              } catch (e) {
                debugPrint('Erreur lors de la création de la clé : $e');
                Navigator.of(context).pop();
                showSafeSnackBar(context, 'Échec de la création de la clé : $e');
              }
            }
          },
        ),
      ],
    );
  }
}
