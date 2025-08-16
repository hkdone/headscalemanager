import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'package:headscalemanager/services/acl_generator_service.dart'; // New import

/// Écran de gestion des politiques ACL (Access Control List) Headscale.
///
/// Permet de visualiser, éditer, générer et partager les politiques ACL.
class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  /// Contrôleur pour le champ de texte affichant la politique ACL.
  final TextEditingController _aclController = TextEditingController();

  /// Indicateur de chargement pour l'écran.
  bool _isLoading = true;

  /// La politique ACL actuelle, stockée sous forme de Map.
  Map<String, dynamic> _currentAclPolicy = {};

  /// Instance du service de génération d'ACL.
  final AclGeneratorService _aclGeneratorService = AclGeneratorService();

  @override
  void initState() {
    super.initState();
    _loadAcl();
  }

  /// Met à jour le texte du contrôleur ACL avec le contenu de `_currentAclPolicy`.
  ///
  /// Le JSON est formaté avec une indentation pour une meilleure lisibilité.
  void _updateAclControllerText() {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    _aclController.text = encoder.convert(_currentAclPolicy);
    // Rafraîchir l'UI si le texte du contrôleur est lié
    setState(() {});
  }

  /// Initialise la politique ACL avec une structure JSON par défaut pour Headscale.
  ///
  /// Cette structure inclut les sections 'acls', 'groups', 'tagOwners', 'autoApprovers',
  /// 'tests' et 'hosts'.
  void _loadAcl() {
    _currentAclPolicy = {
      'acls': [],
      'groups': {},
      'tagOwners': {},
      'autoApprovers': {'routes': <String, List<String>>{}, 'exitNodes': <String>[]},
      'tests': [],
      'hosts': {},
    };
    _updateAclControllerText();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Carte d'information pour les serveurs DNS globaux.
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        '''Pour définir des serveurs DNS globaux, ajoutez une section 'dns' à votre politique (format JSON).

Exemple :
"dns": {
  "servers": ["8.8.8.8", "1.1.1.1"],
  "magicDNS": true
}

Note: Ce texte est codé en dur. Pour une meilleure gestion, il pourrait être déplacé vers une constante ou un fichier de ressources.''',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Champ de texte extensible pour afficher et éditer la politique ACL.
                  Expanded(
                    child: TextField(
                      controller: _aclController,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Politique ACL (format JSON)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
      // Boutons d'action flottants.
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton pour partager le fichier ACL.
          FloatingActionButton(
            onPressed: _shareAclFile,
            heroTag: 'shareAclFile',
            tooltip: 'Partager le fichier ACL',
            child: const Icon(Icons.share),
          ),
          const SizedBox(height: 16),
          // Bouton pour générer la configuration de base de l'ACL.
          FloatingActionButton(
            onPressed: _initializeAclPolicy, // Renommé pour éviter la confusion avec _loadAcl
            heroTag: 'initializeAcl',
            tooltip: 'Générer la configuration de base',
            child: const Icon(Icons.settings_backup_restore),
          ),
        ],
      ),
    );
  }

  /// Ajoute une règle ACL générée à la politique ACL actuelle.
  ///
  /// [ruleJson] : La règle ACL sous forme de chaîne JSON.
  void _addGeneratedRule(String ruleJson) {
    try {
      final newRule = jsonDecode(ruleJson);

      // S'assure que 'acls' est une liste avant d'ajouter la nouvelle règle.
      if (_currentAclPolicy['acls'] == null || !(_currentAclPolicy['acls'] is List)) {
        _currentAclPolicy['acls'] = [];
      }

      (_currentAclPolicy['acls'] as List).add(newRule);
      _updateAclControllerText();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règle ACL ajoutée.')),
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout de la règle ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'ajout de la règle : $e. Assurez-vous que la règle est un JSON valide.')),
      );
    }
  }

  /// Génère une politique ACL complète en utilisant le service `AclGeneratorService`.
  ///
  /// Récupère les utilisateurs et les nœuds via l'API, puis utilise le service
  /// pour construire la politique ACL basée sur les tags et les routes.
  Future<void> _initializeAclPolicy() async { // Renommé
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      // Récupération des utilisateurs et des nœuds via le service API.
      final users = await apiService.getUsers();
      final nodes = await apiService.getNodes();

      // Utilisation du service AclGeneratorService pour générer la politique ACL.
      _currentAclPolicy = _aclGeneratorService.generateAclPolicy(
        users: users,
        nodes: nodes,
      );

      _updateAclControllerText();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL "Tout-Tag" générée.')),
      );
    } catch (e) {
      debugPrint('Erreur lors de la génération de la politique ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération de la politique ACL : $e')),
      );
    }
  }

  /// Partage le contenu de la politique ACL actuelle sous forme de fichier JSON.
  ///
  /// Le fichier est sauvegardé temporairement et partagé via le plugin `share_plus`.
  Future<void> _shareAclFile() async {
    try {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final String aclJsonString = encoder.convert(_currentAclPolicy);

      // Vérifie si la politique est vide ou non initialisée.
      if (aclJsonString.isEmpty || aclJsonString == encoder.convert({})) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le contenu ACL est vide ou non initialisé. Générez d\'abord une politique.')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl.json');
      await file.writeAsString(aclJsonString);

      await Share.shareXFiles([XFile(file.path)], text: 'Voici votre politique ACL Headscale.');

    } catch (e) {
      debugPrint('Erreur lors du partage du fichier ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du partage du fichier ACL : $e')),
      );
    }
  }
}
