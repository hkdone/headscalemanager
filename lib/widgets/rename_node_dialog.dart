import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'dart:convert';

/// Dialogue pour renommer un nœud.
///
/// Permet à l'utilisateur de saisir un nouveau nom pour le nœud.
/// Valide le nouveau nom et appelle l'API pour renommer le nœud.
class RenameNodeDialog extends StatefulWidget {
  /// Le nœud à renommer.
  final Node node;

  /// Fonction de rappel appelée après le renommage du nœud.
  final VoidCallback onNodeRenamed;

  const RenameNodeDialog({
    super.key,
    required this.node,
    required this.onNodeRenamed,
  });

  @override
  State<RenameNodeDialog> createState() => _RenameNodeDialogState();
}

class _RenameNodeDialogState extends State<RenameNodeDialog> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.node.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Renommer l\'appareil' : 'Rename Device'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: isFr ? 'Nouveau nom' : 'New name',
            hintText: isFr
                ? 'Entrez le nouveau nom de l\'appareil'
                : 'Enter the new device name',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return isFr
                  ? 'Le nom ne peut pas être vide.'
                  : 'Name cannot be empty.';
            }
            return null;
          },
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(isFr ? 'Renommer' : 'Rename'),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final newName = _nameController.text.trim();

              // Validation RFC 1123 stricte
              if (!isValidDns1123Subdomain(newName)) {
                final sanitized = sanitizeDns1123Subdomain(newName);
                showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                          title:
                              Text(isFr ? 'Format Invalide' : 'Invalid Format'),
                          content: Text(isFr
                              ? 'Le nom "$newName" ne respecte pas le format DNS (RFC 1123).\n\nCaractères autorisés : a-z, 0-9 et tirets.\nPas de majuscules ni de caractères spéciaux.\n\nVoulez-vous utiliser "$sanitized" à la place ?'
                              : 'The name "$newName" does not match DNS format (RFC 1123).\n\nAllowed: a-z, 0-9, and dashes.\nNo uppercase or special characters.\n\nDo you want to use "$sanitized" instead?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(isFr ? 'Annuler' : 'Cancel')),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _nameController.text = sanitized;
                                },
                                child: Text(isFr
                                    ? 'Utiliser corrigé'
                                    : 'Use corrected')),
                          ],
                        ));
                return;
              }

              try {
                final appProvider = context.read<AppProvider>();
                final apiService = appProvider.apiService;

                // 1. Renommer le nœud
                await apiService.renameNode(widget.node.id, newName);

                // 2. Régénérer les ACLs pour garantir la cohérence
                final serverId = appProvider.activeServer?.id;
                if (serverId != null) {
                  if (!context.mounted) return;
                  showSafeSnackBar(context,
                      isFr ? 'Mise à jour des ACLs...' : 'Updating ACLs...');
                  final allUsers = await apiService.getUsers();
                  final allNodes = await apiService.getNodes();
                  final tempRules = await appProvider.storageService
                      .getTemporaryRules(serverId);

                  final aclGenerator = NewAclGeneratorService();
                  final newPolicyMap = aclGenerator.generatePolicy(
                      users: allUsers,
                      nodes: allNodes,
                      temporaryRules: tempRules);

                  await apiService.setAclPolicy(jsonEncode(newPolicyMap));
                }

                if (!context.mounted) return;
                widget.onNodeRenamed();
                Navigator.of(context).pop();
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Appareil renommé et ACLs mises à jour.'
                        : 'Device renamed and ACLs updated.');
              } catch (e) {
                showSafeSnackBar(
                    context,
                    isFr
                        ? 'Erreur lors du renommage: $e'
                        : 'Error while renaming: $e');
              }
            }
          },
        ),
      ],
    );
  }
}
