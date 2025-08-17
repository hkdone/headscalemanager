import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/widgets/cli_command_display_dialog.dart'; // New import
import 'package:headscalemanager/widgets/edit_tags_dialog.dart'; // New import
import 'package:flutter/foundation.dart'; // For debugPrint

/// Écran affichant les détails d'un nœud Headscale spécifique.
///
/// Permet de visualiser les informations du nœud et de gérer ses tags.
class NodeDetailScreen extends StatefulWidget {
  /// Le nœud dont les détails doivent être affichés.
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  /// Liste des tags actuels du nœud.
  late List<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _currentTags = List<String>.from(widget.node.tags);
  }

  /// Affiche un dialogue pour modifier les tags du nœud.
  ///
  /// Le dialogue permet à l'utilisateur de saisir de nouveaux tags et génère
  /// une commande CLI correspondante. Cette commande doit être exécutée
  /// manuellement par l'utilisateur.
  void _showEditTagsFlow() async {
    final String? generatedCommand = await showDialog<String>( // Await the dialog dismissal and get returned value
      context: context,
      builder: (context) => EditTagsDialog(
        node: widget.node,
        // onCliCommandGenerated: (command) { // This callback is no longer used
        //   // The command is now returned by the dialog itself
        // },
      ),
    );

    if (generatedCommand != null && generatedCommand.isNotEmpty) {
      // Affiche le dialogue de commande CLI après la génération.
      showDialog(
        context: context,
        builder: (ctx) => CliCommandDisplayDialog(command: generatedCommand),
      );
      // Affiche un SnackBar pour informer l'utilisateur.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Commande CLI générée. Exécutez-la et actualisez la page pour voir les changements.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.node.name),
        actions: [
          // Bouton pour modifier les tags du nœud.
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier les tags',
            onPressed: _showEditTagsFlow,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Affichage des différentes propriétés du nœud.
            _buildDetailRow('Nom : ', widget.node.name),
            _buildDetailRow('Hostname : ', widget.node.hostname),
            _buildDetailRow('Nom de domaine complet (FQDN) : ', widget.node.fqdn),
            _buildDetailRow('ID : ', widget.node.id),
            _buildDetailRow('Clé machine : ', widget.node.machineKey),
            _buildDetailRow('Utilisateur : ', widget.node.user),
            _buildDetailRow('En ligne : ', widget.node.online ? 'Oui' : 'Non'),
            _buildDetailRow(
                'Dernière connexion : ', widget.node.lastSeen.toLocal().toString()),
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

  /// Construit une ligne pour afficher un détail du nœud (libellé et valeur).
  ///
  /// [label] : Le libellé du détail (ex: "Nom :").
  /// [value] : La valeur du détail.
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150, // Largeur ajustée pour un meilleur affichage du libellé.
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value), // Texte sélectionnable pour faciliter la copie.
          ),
        ],
      ),
    );
  }
}