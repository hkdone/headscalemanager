import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:provider/provider.dart';

class ManageSpecificRulesDialog extends StatefulWidget {
  final List<Node> allNodes;

  const ManageSpecificRulesDialog({super.key, required this.allNodes});

  @override
  State<ManageSpecificRulesDialog> createState() =>
      _ManageSpecificRulesDialogState();
}

class _ManageSpecificRulesDialogState extends State<ManageSpecificRulesDialog> {
  List<Map<String, dynamic>> _temporaryRules = [];
  bool _isLoading = true;
  bool _rulesChanged = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final storage = context.read<AppProvider>().storageService;
    final loadedRules = await storage.getTemporaryRules();
    if (mounted) {
      setState(() {
        _temporaryRules = loadedRules;
        _isLoading = false;
      });
    }
  }

  String _getNodeNameFromIpOrSubnet(String ipOrSubnet) {
    try {
      return widget.allNodes
          .firstWhere((node) =>
              node.ipAddresses.contains(ipOrSubnet) ||
              node.sharedRoutes.contains(ipOrSubnet))
          .name;
    } catch (e) {
      return ipOrSubnet;
    }
  }

  Future<void> _removeTemporaryRule(int index) async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Confirmer la suppression' : 'Confirm Deletion'),
            content: Text(isFr
                ? 'Cela va supprimer la règle et appliquer immédiatement la nouvelle politique au serveur. Continuer ?'
                : 'This will delete the rule and immediately apply the new policy to the server. Continue?'),
            actions: [
              TextButton(
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: Text(isFr ? 'Confirmer' : 'Confirm',
                      style: const TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _temporaryRules.removeAt(index);
      _rulesChanged = true;
    });

    final storage = context.read<AppProvider>().storageService;
    await storage.saveTemporaryRules(_temporaryRules);
    await _generateAndExportPolicy(
        message: isFr
            ? 'Règle supprimée et politique mise à jour.'
            : 'Rule deleted and policy updated.');
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final users = await apiService.getUsers();
      final nodes = widget.allNodes;

      final generator = NewAclGeneratorService();
      final newPolicy = generator.generatePolicy(
        users: users,
        nodes: nodes,
        temporaryRules: _temporaryRules,
      );

      const encoder = JsonEncoder.withIndent('  ');
      final policyString = encoder.convert(newPolicy);

      await apiService.setAclPolicy(policyString);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(message ??
                  (isFr ? 'Politique mise à jour.' : 'Policy updated.')),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? "Erreur lors de la mise à jour de la politique" : "Error updating policy"}: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title:
          Text(isFr ? 'Règles Spécifiques Actives' : 'Active Specific Rules'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _temporaryRules.isEmpty
                ? Center(
                    child: Text(isFr
                        ? 'Aucune règle spécifique active.'
                        : 'No active specific rules.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _temporaryRules.length,
                    itemBuilder: (context, index) {
                      final rule = _temporaryRules[index];
                      final src = rule['src'] as String;
                      final dst = rule['dst'] as String;
                      final port = rule['port'] as String?;

                      final srcNodeName = _getNodeNameFromIpOrSubnet(src);
                      final dstNodeName = _getNodeNameFromIpOrSubnet(dst);

                      final label =
                          '$srcNodeName -> $dstNodeName:${port != null && port.isNotEmpty ? port : '*'}';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 8.0),
                        child: ListTile(
                          title: Text(label, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeTemporaryRule(index),
                          ),
                          onTap: () => _showRuleDetails(rule),
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_rulesChanged),
          child: Text(isFr ? 'Fermer' : 'Close'),
        ),
      ],
    );
  }

  void _showRuleDetails(Map<String, dynamic> rule) {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final srcIp = rule['src'] as String;
    final dstIpOrSubnet = rule['dst'] as String;
    final port = rule['port'] as String?;

    Node? srcNode;
    Node? dstNode;
    try {
      srcNode =
          widget.allNodes.firstWhere((n) => n.ipAddresses.contains(srcIp));
    } catch (e) {
      // Node not found
    }
    try {
      dstNode = widget.allNodes.firstWhere((n) =>
          n.ipAddresses.contains(dstIpOrSubnet) ||
          n.sharedRoutes.contains(dstIpOrSubnet));
    } catch (e) {
      // Node not found
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFr ? 'Détails de la Règle' : 'Rule Details'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              _buildDetailRow(isFr ? 'Source' : 'Source',
                  srcNode?.name ?? (isFr ? 'Inconnu' : 'Unknown')),
              _buildDetailRow('IP Source', srcIp),
              if (srcNode != null)
                _buildDetailRow('IPs Source', srcNode.ipAddresses.join(', ')),
              const Divider(),
              _buildDetailRow(isFr ? 'Destination' : 'Destination',
                  dstNode?.name ?? dstIpOrSubnet),
              _buildDetailRow('IP/Subnet Dest.', dstIpOrSubnet),
              if (dstNode != null)
                _buildDetailRow('IPs Dest.', dstNode.ipAddresses.join(', ')),
              if (dstNode != null && dstNode.sharedRoutes.isNotEmpty)
                _buildDetailRow(
                    'Routes Partagées', dstNode.sharedRoutes.join(', ')),
              const Divider(),
              _buildDetailRow(
                  'Port(s)', port != null && port.isNotEmpty ? port : '*'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text(isFr ? 'Fermer' : 'Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text('$label :',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
