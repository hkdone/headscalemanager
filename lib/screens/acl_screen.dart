import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:yaml/yaml.dart';
import 'package:headscalemanager/widgets/acl_generator_dialog.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/models/user.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAcl();
  }

  void _loadAcl() {
    // Initialize with an empty ACL structure
    final Map<String, dynamic> initialAclMap = {
      'acl': {
        'policy': [],
      },
    };
    final String initialYaml = jsonEncode(initialAclMap);

    setState(() {
      _aclController.text = initialYaml;
      _isLoading = false;
    });
  }

  void _saveAcl() {
    // The content is already in _aclController.text, which is what the user will copy.
    // We just need to provide feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contenu ACL mis à jour. Copiez le texte ci-dessus pour l\'utiliser.')),
    );
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Pour définir des serveurs DNS globaux, ajoutez une section \'dns\' à votre politique.\n\nExemple :\n' 'dns :\n' '  serveurs :\n' '    - 8.8.8.8\n' '    - 1.1.1.1\n' '  magicDNS : true',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _aclController,
                      maxLines: null, // Permet une saisie sur plusieurs lignes
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Politique ACL (format YAML)',
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
            child: const Icon(Icons.share), // Icon for sharing the file
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _initializeAcl, // This is now "base configuration"
            heroTag: 'initializeAcl',
            child: const Icon(Icons.settings_backup_restore), // Icon for base config
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AclGeneratorDialog(
                  onRuleGenerated: (rule) {
                    _addGeneratedRule(rule);
                  },
                ),
              );
            },
            heroTag: 'generateAcl',
            child: const Icon(Icons.add), // Icon for generating new rules
          ),
        ],
      ),
    );
  }

  void _addGeneratedRule(String rule) {
    Map<dynamic, dynamic> aclMap = {};
    if (_aclController.text.isNotEmpty) {
      aclMap = loadYaml(_aclController.text);
    }

    // Ensure 'acl' and 'policy' nodes exist
    if (!aclMap.containsKey('acl')) {
      aclMap['acl'] = {};
    }
    if (!aclMap['acl'].containsKey('policy')) {
      aclMap['acl']['policy'] = [];
    }

    final List<dynamic> policyList = aclMap['acl']['policy'];
    final newRule = loadYaml(rule);
    policyList.add(newRule);

    final String generatedYaml = jsonEncode(aclMap);

    setState(() {
      _aclController.text = generatedYaml;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Règle ACL ajoutée. Copiez le texte ci-dessus pour l\'utiliser.')),
    );
  }

  void _removeGeneratedRules() {
    Map<dynamic, dynamic> aclMap = {};
    if (_aclController.text.isNotEmpty) {
      aclMap = loadYaml(_aclController.text);
    }

    if (!aclMap.containsKey('acl') || !aclMap['acl'].containsKey('policy')) {
      return; // No policy to remove rules from
    }

    final List<dynamic> policyList = aclMap['acl']['policy'];
    final List<dynamic> rulesToKeep = [];

    for (var item in policyList) {
      if (item is Map && item.containsKey('_generated') && item['_generated'] == true) {
        // This is a generated rule, skip it (don't add to rulesToKeep)
      } else {
        rulesToKeep.add(item);
      }
    }

    aclMap['acl']['policy'] = rulesToKeep;

    setState(() {
      _aclController.text = jsonEncode(aclMap);
    });
    _saveAcl(); // Save the ACL after removing rules
  }

  Future<void> _initializeAcl() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      final users = await apiService.getUsers();
      final nodes = await apiService.getNodes();

      Map<String, dynamic> aclMap = {
        'acl': {
          'policy': [],
        },
        'autoApprovers': {
          'routes': <String, List<String>>{},
          'exitNodes': <String>[], // Initialize as a List<String>
        },
        'exitNode': {}, // Initialize exitNode map
        'groups': {}, // Initialize groups map
      };

      // Add a base rule for autogroup:self (as requested by user)
      aclMap['acl']['policy'].add({
        'action': 'accept',
        'src': ['autogroup:self'],
        'dst': ['autogroup:self'],
      });

      // Iterate through users to create intra-user communication rules
      for (User user in users) {
        // Define the group for the user
        aclMap['groups']['group:${user.name}'] = ['user:${user.name}'];

        // Rule for all nodes of a user to communicate with each other
        aclMap['acl']['policy'].add({
          'action': 'accept',
          'src': ['group:${user.name}'],
          'dst': ['group:${user.name}'],
        });

        // Process nodes for routes and exit nodes for this user
        final userNodes = nodes.where((node) => node.user == user.name).toList();
        for (var node in userNodes) {
          // Subnet Routes
          if (node.advertisedRoutes.isNotEmpty) {
            // Allow other nodes of the same user to access these routes
            aclMap['acl']['policy'].add({
              'action': 'accept',
              'src': ['group:${user.name}'],
              'dst': List<String>.from(node.advertisedRoutes),
            });
            // Auto-approve routes for the user's nodes
            for (var route in node.advertisedRoutes) {
              if (!aclMap['autoApprovers']['routes'].containsKey(route)) { // Key is the route
                aclMap['autoApprovers']['routes'][route] = <String>[]; // Value is a list of aliases
              }
              if (!aclMap['autoApprovers']['routes'][route]!.contains('group:${user.name}')) { // Add alias to the list
                aclMap['autoApprovers']['routes'][route]!.add('group:${user.name}');
              }
            }
          }

          // Exit Nodes
          if (node.advertisedRoutes.contains('0.0.0.0/0') || node.advertisedRoutes.contains('::/0')) {
            // Define the exit node
            if (!aclMap['exitNode'].containsKey(node.givenName)) {
              aclMap['exitNode'][node.givenName] = {
                'users': [],
              };
            }
            // Allow other nodes of the same user to use this exit node
            if (!aclMap['exitNode'][node.givenName]['users'].contains('group:${user.name}')) {
              aclMap['exitNode'][node.givenName]['users'].add('group:${user.name}');
            }

            // Auto-approve exit nodes for the user's nodes
            // Corrected logic: add alias to the list, not a map
            if (!aclMap['autoApprovers']['exitNodes'].contains('group:${user.name}')) {
              aclMap['autoApprovers']['exitNodes'].add('group:${user.name}');
            }
          }
        }
      }

      const JsonEncoder encoder = JsonEncoder.withIndent('  '); // 2 spaces for indentation
      final String generatedYaml = encoder.convert(aclMap);

      print('Generated ACL YAML:\n$generatedYaml');


      setState(() {
        _aclController.text = generatedYaml;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Politique ACL générée dynamiquement. Copiez le texte ci-dessus.')),
      );
    } catch (e) {
      print('Erreur lors de la génération dynamique de la politique ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la génération dynamique de la politique ACL : $e')),
      );
    }
  }

  Future<void> _shareAclFile() async {
    try {
      if (_aclController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le contenu ACL est vide. Générez d\'abord une politique.')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/acl.yaml');
      await file.writeAsString(_aclController.text);

      await Share.shareXFiles([XFile(file.path)], text: 'Voici votre politique ACL Headscale.');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier ACL partagé avec succès.')),
      );
    } catch (e) {
      print('Erreur lors du partage du fichier ACL : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du partage du fichier ACL : $e')),
      );
    }
  }
}
