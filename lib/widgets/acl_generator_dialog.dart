import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';

class AclGeneratorDialog extends StatefulWidget {
  final Function(String) onRuleGenerated;

  const AclGeneratorDialog({super.key, required this.onRuleGenerated});

  @override
  State<AclGeneratorDialog> createState() => _AclGeneratorDialogState();
}

class _AclGeneratorDialogState extends State<AclGeneratorDialog> {
  Node? _sourceNode;
  Node? _destinationNode;
  late Future<List<Node>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _nodesFuture = context.read<AppProvider>().apiService.getNodes();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Générateur de règles ACL'),
      content: FutureBuilder<List<Node>>(
        future: _nodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur lors du chargement des nœuds : ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun nœud trouvé.'));
          }

          final nodes = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Node>(
                  decoration: const InputDecoration(labelText: 'Nœud source'),
                  value: _sourceNode,
                  items: nodes.map((node) {
                    return DropdownMenuItem<Node>(
                      value: node,
                      child: Text('${node.givenName} (${node.fqdn})'),
                    );
                  }).toList(),
                  onChanged: (node) {
                    setState(() {
                      _sourceNode = node;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Node>(
                  decoration: const InputDecoration(labelText: 'Nœud de destination'),
                  value: _destinationNode,
                  items: nodes.map((node) {
                    return DropdownMenuItem<Node>(
                      value: node,
                      child: Text('${node.givenName} (${node.fqdn})'),
                    );
                  }).toList(),
                  onChanged: (node) {
                    setState(() {
                      _destinationNode = node;
                    });
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_sourceNode != null && _destinationNode != null) {
                      final rule = '  - action: accept\n    src: ["${_sourceNode!.fqdn}"]\n    dst: ["${_destinationNode!.fqdn}"]\n    _generated: true';
                      widget.onRuleGenerated(rule);
                      Navigator.of(context).pop();
                    } else {
                      showSafeSnackBar(context, 'Veuillez sélectionner les nœuds source et de destination.');
                    }
                  },
                  child: const Text('Générer et ajouter la règle'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}