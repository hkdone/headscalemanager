import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/widgets/acl_generator_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {}; // Nouvelle source de vérité

  @override
  void initState() {
    super.initState();
    _loadAcl();
  }

  void _updateAclControllerText() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(_currentAclPolicy);
    setState(() {}); // Rafraîchir l'UI si le texte du contrôleur est lié
  }

  void _loadAcl() {
    // Initialise avec une structure JSON par défaut pour Headscale
    // Headscale v0.22.0+ utilise 'acls' directement.
    _currentAclPolicy = {
      'acls': [],
      'groups': {},
      'tagOwners': {},
      'autoApprovers': {'routes': <String, List<String>>{}, 'exitNodes': <String>[]},
      'tests': [],
      'hosts': {},
      // 'dns': {}, // Optionnel, peut être ajouté par l'utilisateur
    };

    _updateAclControllerText();
    setState(() {
      _isLoading = false;
    });
  }

  // void _saveAcl() {
  //   // Sera réimplémenté si la sauvegarde SharedPreferences est nécessaire
  //   // avec _currentAclPolicy comme source.
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Contenu ACL mis à jour. Copiez le texte ci-dessus pour l\'utiliser.')),
  //   );
  // }

  // void _removeGeneratedRules() {
  //   // Sera réimplémenté pour fonctionner avec _currentAclPolicy['acls']
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Pour définir des serveurs DNS globaux, ajoutez une section \'dns\' à votre politique (format JSON).\n\nExemple :\n'
                        '"dns": {\n'
                        '  "servers": ["8.8.8.8", "1.1.1.1"],\n'
                        '  "magicDNS": true\n'
                        '}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _aclController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Politique ACL (format JSON)', // Changé en JSON
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _shareAclFile,
            heroTag: 'shareAclFile',
            tooltip: 'Partager le fichier ACL',
            child: const Icon(Icons.share),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _initializeAcl,
            heroTag: 'initializeAcl',
            tooltip: 'Générer la configuration de base',
            child: const Icon(Icons.settings_backup_restore),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AclGeneratorDialog(
                  onRuleGenerated: (ruleJson) { // Attend une chaîne JSON
                    _addGeneratedRule(ruleJson);
                  },
                ),
              );
            },
            heroTag: 'generateAcl',
            tooltip: 'Ajouter une règle ACL',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _addGeneratedRule(String ruleJson) { // Accepte une chaîne JSON
    try {
      final newRule = jsonDecode(ruleJson);

      if (_currentAclPolicy['acls'] == null || !(_currentAclPolicy['acls'] is List)) {
        _currentAclPolicy['acls'] = [];
      }

      (_currentAclPolicy['acls'] as List).add(newRule);
      _updateAclControllerText();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règle ACL ajoutée.')),
      );
    } catch (e) {
      print('Erreur lors de l\'ajout de la règle ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'ajout de la règle : $e. Assurez-vous que la règle est un JSON valide.')),
      );
    }
  }

  Future<void> _initializeAcl() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      final users = await apiService.getUsers();
      final nodes = await apiService.getNodes();

      // --- Étape 1: Extraire toutes les informations des noeuds ---
      final groups = <String, List<String>>{};
      users.forEach((user) => groups['group:${user.name}'] = [user.name]);

      final tagOwners = <String, List<String>>{};
      final autoApprovers = {'routes': <String, List<String>>{}, 'exitNodes': <String>[]};
      
      final tagsByUser = <String, Set<String>>{};
      final routesByUser = <String, Set<String>>{};
      final userOwnsExitNode = <String, bool>{};

      for (var node in nodes) {
        final groupName = 'group:${node.user}';
        final userName = node.user;

        if (node.tags.isNotEmpty) {
          if (!tagsByUser.containsKey(userName)) tagsByUser[userName] = <String>{};
          tagsByUser[userName]!.addAll(node.tags);

          for (var tag in node.tags) {
            if (!tagOwners.containsKey(tag)) tagOwners[tag] = [];
            if (!tagOwners[tag]!.contains(groupName)) tagOwners[tag]!.add(groupName);
          }
        }

        final isExitNode = node.advertisedRoutes.contains('0.0.0.0/0') || node.advertisedRoutes.contains('::/0');
        if (isExitNode) userOwnsExitNode[userName] = true;

        final subnetRoutes = node.advertisedRoutes.where((r) => r != '0.0.0.0/0' && r != '::/0').toList();
        if (subnetRoutes.isNotEmpty) {
          if (!routesByUser.containsKey(userName)) routesByUser[userName] = <String>{};
          routesByUser[userName]!.addAll(subnetRoutes);

          if (node.tags.isNotEmpty) {
            final routesMap = autoApprovers['routes'] as Map<String, List<String>>;
            for (var tag in node.tags) {
              for (var route in subnetRoutes) {
                if (!routesMap.containsKey(route)) routesMap[route] = [];
                if (!routesMap[route]!.contains(tag)) routesMap[route]!.add(tag);
              }
            }
          }
        }
        
        if (isExitNode && node.tags.isNotEmpty) {
          final exitNodesList = autoApprovers['exitNodes'] as List<String>;
          for (var tag in node.tags) {
            if (!exitNodesList.contains(tag)) exitNodesList.add(tag);
          }
        }
      }

      // --- Étape 2: Construire les règles ACL "Tout-Tag" ---
      final acls = <Map<String, dynamic>>[];

      // Règle pour chaque utilisateur, basée sur l'ensemble de ses tags
      tagsByUser.forEach((userName, userTags) {
        if (userTags.isEmpty) return; // Ne rien faire pour les utilisateurs sans tags

        final userTagList = userTags.toList();
        final destinations = <String>{};
        // Les tags d'un utilisateur peuvent communiquer entre eux
        destinations.addAll(userTagList.map((t) => '$t:*'));

        // Ajouter l'accès aux routes possédées par l'utilisateur
        if (routesByUser.containsKey(userName)) {
          destinations.addAll(routesByUser[userName]!.map((r) => '$r:*'));
        }
        // Ajouter l'accès à internet si l'utilisateur possède un exit node
        if (userOwnsExitNode[userName] == true) {
          destinations.add('autogroup:internet:*');
        }

        acls.add({
          'action': 'accept',
          'src': userTagList,
          'dst': destinations.toList(),
        });
      });

      // Règle pour les tags "routeurs" eux-mêmes
      final allRouterTags = <String>{};
      (autoApprovers['routes'] as Map<String, List<String>>).values.forEach(allRouterTags.addAll);
      allRouterTags.addAll(autoApprovers['exitNodes'] as List<String>);

      allRouterTags.forEach((tag) {
        final destinations = <String>{};
        // Le routeur peut parler aux autres tags de son propriétaire
        tagOwners[tag]?.forEach((ownerGroup) {
          final ownerName = ownerGroup.replaceFirst('group:', '');
          if (tagsByUser.containsKey(ownerName)) {
            destinations.addAll(tagsByUser[ownerName]!.map((t) => '$t:*'));
          }
        });

        // Le routeur peut parler aux routes qu'il annonce
        (autoApprovers['routes'] as Map<String, List<String>>).forEach((route, tags) {
          if (tags.contains(tag)) destinations.add('$route:*');
        });

        // Le routeur peut parler à internet s'il est un exit node
        if ((autoApprovers['exitNodes'] as List<String>).contains(tag)) {
          destinations.add('autogroup:internet:*');
        }

        if (destinations.isNotEmpty) {
          acls.add({
            'action': 'accept',
            'src': [tag],
            'dst': destinations.toList(),
          });
        }
      });

      // --- Étape 3: Assemblage final ---
      _currentAclPolicy = {
        'groups': groups,
        'tagOwners': tagOwners,
        'autoApprovers': autoApprovers,
        'acls': acls,
        'hosts': <String, dynamic>{},
        'tests': <Map<String, dynamic>>[],
      };

      _updateAclControllerText();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL "Tout-Tag" générée.')),
      );
    } catch (e) {
      print('Erreur lors de la génération de la politique ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération de la politique ACL : $e')),
      );
    }
  }

  Future<void> _shareAclFile() async {
    try {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String aclJsonString = encoder.convert(_currentAclPolicy);

      if (aclJsonString.isEmpty || aclJsonString == encoder.convert({})) { // Vérifie si la politique est vide ou structure par défaut non remplie
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le contenu ACL est vide ou non initialisé. Générez d\'abord une politique.')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl.json'); // Changé en acl.json
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Voici votre politique ACL Headscale.');

      //ScaffoldMessenger.of(context).showSnackBar(
      //  const SnackBar(content: Text('Fichier ACL partagé avec succès.')),
      //);
    } catch (e) {
      print('Erreur lors du partage du fichier ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du partage du fichier ACL : $e')),
      );
    }
  }
}
