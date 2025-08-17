import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:headscalemanager/widgets/create_pre_auth_key_dialog.dart'; // New import
import 'package:headscalemanager/widgets/delete_pre_auth_key_dialog.dart'; // New import

/// Écran de gestion des clés de pré-authentification Headscale.
///
/// Permet de visualiser, créer et supprimer des clés de pré-authentification.
class PreAuthKeysScreen extends StatefulWidget {
  const PreAuthKeysScreen({super.key});

  @override
  State<PreAuthKeysScreen> createState() => _PreAuthKeysScreenState();
}

class _PreAuthKeysScreenState extends State<PreAuthKeysScreen> {
  /// Future qui contiendra la liste des clés de pré-authentification récupérées depuis l'API.
  late Future<List<PreAuthKey>> _preAuthKeysFuture;

  @override
  void initState() {
    super.initState();
    _refreshPreAuthKeys();
  }

  /// Rafraîchit la liste des clés de pré-authentification en effectuant un nouvel appel API.
  void _refreshPreAuthKeys() {
    setState(() {
      _preAuthKeysFuture = context.read<AppProvider>().apiService.getPreAuthKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clés de pré-authentification'),
      ),
      body: FutureBuilder<List<PreAuthKey>>(
        future: _preAuthKeysFuture,
        builder: (context, snapshot) {
          // Affiche un indicateur de chargement pendant la récupération des clés.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Affiche un message d'erreur si la récupération des clés échoue.
          if (snapshot.hasError) {
            debugPrint('Erreur lors du chargement des clés de pré-authentification : ${snapshot.error}');
            return Center(child: Text('Erreur : ${snapshot.error}'));
          }
          // Affiche un message si aucune clé n'est trouvée.
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune clé de pré-authentification trouvée.'));
          }

          final keys = snapshot.data!;

          // Construit une liste déroulante de cartes, une par clé de pré-authentification.
          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(key.key),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Utilisateur : ${key.user}'),
                      Text('Réutilisable : ${key.reusable ? 'Oui' : 'Non'}'),
                      Text('Éphémère : ${key.ephemeral ? 'Oui' : 'Non'}'),
                      if (key.expiration != null)
                        Text('Expire le : ${key.expiration.toLocal().toShortDateString()}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Affiche le dialogue de suppression de clé.
                      showDialog(
                        context: context,
                        builder: (ctx) => DeletePreAuthKeyDialog(
                          preAuthKey: key,
                          onKeyDeleted: _refreshPreAuthKeys, // Rafraîchit la liste après suppression
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      // Bouton flottant pour créer une nouvelle clé de pré-authentification.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Affiche le dialogue de création de clé.
          showDialog(
            context: context,
            builder: (ctx) => CreatePreAuthKeyDialog(
              onKeyCreated: _refreshPreAuthKeys, // Rafraîchit la liste après création
            ),
          );
        },
        heroTag: 'createPreAuthKey',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Extension pour formater la date
extension on DateTime {
  String toShortDateString() {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year.toString()}';
  }
}