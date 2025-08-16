import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';

class NodeDetailScreen extends StatelessWidget {
  final Node node;

  const NodeDetailScreen({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(node.givenName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDetailRow('Nom : ', node.givenName),
            _buildDetailRow('Nom d\'hôte : ', node.name),
            _buildDetailRow('Nom de domaine complet (FQDN) : ', node.fqdn),
            _buildDetailRow('ID : ', node.id),
            _buildDetailRow('Clé machine : ', node.machineKey),
            _buildDetailRow('Utilisateur : ', node.user),
            _buildDetailRow('En ligne : ', node.online ? 'Oui' : 'Non'),
            _buildDetailRow('Dernière connexion : ', node.lastSeen.toLocal().toString()),
            _buildDetailRow('Adresses IP : ', node.ipAddresses.join(', ')),
            _buildDetailRow('Routes annoncées : ', node.advertisedRoutes.isEmpty ? 'Aucune' : node.advertisedRoutes.join(', ')),
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
            width: 150,
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
