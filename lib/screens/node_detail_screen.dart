import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:headscalemanager/models/node.dart';
// import 'package:headscalemanager/api/headscale_api_service.dart'; // Commented out
// import 'dart:developer' as developer; // Commented out

class NodeDetailScreen extends StatefulWidget {
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  late List<String> _currentTags;
  // final HeadscaleApiService _apiService = HeadscaleApiService(); // Commented out

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.node.tags);
  }

  Future<void> _showEditTagsDialog() async {
    final TextEditingController tagsController =
        TextEditingController(text: _currentTags.join(', '));

    final newTagsList = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier les tags'),
          content: TextField(
            controller: tagsController,
            decoration: const InputDecoration(
                hintText: 'Tags (minuscules, sans chiffres/espaces/spéciaux)'), // Updated hint
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Générer Commande CLI'),
              onPressed: () {
                final tagsString = tagsController.text.trim();
                final rawTags = tagsString.isNotEmpty
                    ? tagsString
                        .split(',')
                        .map((t) => t.trim())
                        .toList()
                    : <String>[];

                List<String> validTags = [];
                List<String> invalidTagsExamples = [];
                bool allTagsValid = true;
                final RegExp validTagPattern = RegExp(r'^[a-z]+$');

                if (rawTags.isNotEmpty) {
                  for (String tag in rawTags) {
                    if (tag.isNotEmpty) { // Only validate non-empty strings from split
                      if (validTagPattern.hasMatch(tag)) {
                        validTags.add(tag);
                      } else {
                        allTagsValid = false;
                        if (invalidTagsExamples.length < 3) { // Show a few examples
                           invalidTagsExamples.add(tag);
                        }
                      }
                    }
                  }
                }

                if (!allTagsValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tags invalides : ${invalidTagsExamples.join(", ")}. Uniquement lettres minuscules, sans chiffres, espaces ou caractères spéciaux.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return; // Keep the dialog open
                }
                
                // If all tags are valid (or no tags were entered, which is also valid)
                // We use validTags here which only contains successfully validated tags or is empty
                Navigator.of(context).pop(validTags);
              },
            ),
          ],
        );
      },
    );

    if (newTagsList != null) {
      // Construct the CLI command based on:
      // headscale nodes tag -i <identifier> -t tag:<tag1> -t tag:<tag2> ...
      // Each tag MUST be prefixed with "tag:" for the CLI.
      String cliCommand = 'headscale nodes tag -i ${widget.node.id}';
      if (newTagsList.isNotEmpty) {
        for (final tag in newTagsList) {
          // Add "tag:" prefix here
          cliCommand += ' -t "tag:$tag"';
        }
      }
      // If newTagsList is empty, no -t flags are added.
      // 'headscale nodes tag -i <ID>' is assumed to clear existing tags if no -t is provided.

      // ignore: use_build_context_synchronously
      _showCliCommandDialog(cliCommand);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Commande CLI générée. Exécutez-la et actualisez la page pour voir les changements.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showCliCommandDialog(String command) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Commande CLI pour les Tags'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                    'Copiez et exécutez cette commande dans votre terminal où la CLI `headscale` est configurée :'),
                const SizedBox(height: 10),
                SelectableText(
                  command,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Copier'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: command));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Commande copiée dans le presse-papiers !'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            TextButton(
              child: const Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node.givenName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier les tags',
            onPressed: _showEditTagsDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDetailRow('Nom : ', widget.node.givenName),
            _buildDetailRow('Nom d\'hôte : ', widget.node.name),
            _buildDetailRow('Nom de domaine complet (FQDN) : ', widget.node.fqdn),
            _buildDetailRow('ID : ', widget.node.id),
            _buildDetailRow('Clé machine : ', widget.node.machineKey),
            _buildDetailRow('Utilisateur : ', widget.node.user),
            _buildDetailRow('En ligne : ', widget.node.online ? 'Oui' : 'Non'),
            _buildDetailRow('Dernière connexion : ',
                widget.node.lastSeen.toLocal().toString()),
            _buildDetailRow(
                'Adresses IP : ', widget.node.ipAddresses.join(', ')),
            _buildDetailRow(
                'Routes annoncées : ',
                widget.node.advertisedRoutes.isEmpty
                    ? 'Aucune'
                    : widget.node.advertisedRoutes.join(', ')),
            _buildDetailRow('Tags : ',
                _currentTags.isEmpty ? 'Aucun' : _currentTags.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Adjusted width for better label display
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value),
          ),
        ],
      ),
    );
  }
}
