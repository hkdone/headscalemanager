import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/widgets/shared_routes_access_dialog.dart';
import 'package:provider/provider.dart';
import 'package:headscalemanager/providers/app_provider.dart';

class AddAclRuleDialog extends StatefulWidget {
  final List<Node> allNodes;

  const AddAclRuleDialog({
    super.key,
    required this.allNodes,
  });

  @override
  State<AddAclRuleDialog> createState() => _AddAclRuleDialogState();
}

class _AddAclRuleDialogState extends State<AddAclRuleDialog> {
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final _portController = TextEditingController();
  List<Node> _destinationNodes = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _destinationNodes = List.from(widget.allNodes);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr ? 'Ajouter une règle ACL' : 'Add ACL Rule'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr
                    ? 'Créez une exception pour autoriser la communication entre les appareils.'
                    : 'Create an exception to allow communication between devices.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildNodeDropdown(
                isFr ? 'Source (Nœud)' : 'Source (Node)',
                _selectedSourceNode,
                widget.allNodes,
                (node) {
                  setState(() {
                    _selectedSourceNode = node;
                    _selectedDestinationNode = null;
                    if (node != null) {
                      _destinationNodes = widget.allNodes
                          .where((n) => n.user != node.user)
                          .toList();
                    } else {
                      _destinationNodes = List.from(widget.allNodes);
                    }
                  });
                },
                isFr
                    ? 'Veuillez sélectionner un nœud source'
                    : 'Please select a source node',
              ),
              const SizedBox(height: 16),
              _buildNodeDropdown(
                isFr ? 'Destination (Nœud)' : 'Destination (Node)',
                _selectedDestinationNode,
                _destinationNodes,
                (node) => setState(() => _selectedDestinationNode = node),
                isFr
                    ? 'Veuillez sélectionner un nœud destination'
                    : 'Please select a destination node',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration(
                    isFr ? 'Port(s)' : 'Port(s)', 'ex: 443, 8080-8089, *'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _addRule,
          child: Text(isFr ? 'Ajouter' : 'Add'),
        ),
      ],
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(
    String label,
    Node? selectedNode,
    List<Node> nodes,
    ValueChanged<Node?> onChanged,
    String? validationMessage,
  ) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return DropdownButtonFormField<Node>(
      initialValue: selectedNode,
      decoration: _buildInputDecoration(
          label, isFr ? 'Choisir un nœud' : 'Choose a node'),
      items: nodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
      validator: (value) {
        if (value == null) {
          return validationMessage;
        }
        return null;
      },
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _addRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    if (_selectedSourceNode!.ipAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFr
              ? 'Le nœud source doit avoir au moins une adresse IP.'
              : 'Source node must have at least one IP address.'),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    final sourceIp = _selectedSourceNode!.ipAddresses.first;

    List<Map<String, dynamic>> newRulesToAdd = [];

    final sharedLanRoutes = _selectedDestinationNode!.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();

    if (sharedLanRoutes.isNotEmpty) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SharedRoutesAccessDialog(
          destinationNode: _selectedDestinationNode!,
        ),
      );

      if (result == null) return;

      final choice = result['choice'] as RouteAccessChoice;
      final rules = result['rules'] as Map<String, dynamic>;

      if (choice == RouteAccessChoice.none) {
        // Fallback: add rule for the node itself if subnet access is denied
        if (_selectedDestinationNode!.ipAddresses.isNotEmpty) {
          final destinationIp = _selectedDestinationNode!.ipAddresses.first;
          final port = _portController.text.trim();
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': destinationIp,
            'port': port.isEmpty ? '*' : port,
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isFr
                ? 'Accès au sous-réseau non configuré et le nœud n\'a pas d\'IP pour une règle de base.'
                : 'Subnet access not configured and the node has no IP for a fallback rule.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
          return;
        }
      }

      if (choice == RouteAccessChoice.full) {
        for (var route in sharedLanRoutes) {
          newRulesToAdd.add({
            'src': sourceIp,
            'dst': route,
            'port': '*',
          });
        }
      } else if (choice == RouteAccessChoice.custom) {
        rules.forEach((route, ruleDetails) {
          final startIp = (ruleDetails['startIp'] as String).trim();
          final endIp = (ruleDetails['endIp'] as String).trim();
          final ports = (ruleDetails['ports'] as String).trim();

          if (startIp.isEmpty) return;

          String dst;
          if (endIp.isNotEmpty) {
            final range = IpUtils.generateIpRange(startIp, endIp);
            dst = range.join(',');
          } else {
            dst = startIp;
          }

          if (dst.isNotEmpty) {
            newRulesToAdd.add({
              'src': sourceIp,
              'dst': dst,
              'port': ports.isEmpty ? '*' : ports,
            });
          }
        });
      }
    } else {
      if (_selectedDestinationNode!.ipAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isFr
                ? 'Le nœud destination doit avoir au moins une adresse IP.'
                : 'Destination node must have at least one IP address.'),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
      final destinationIp = _selectedDestinationNode!.ipAddresses.first;

      final port = _portController.text.trim();
      newRulesToAdd.add({
        'src': sourceIp,
        'dst': destinationIp,
        'port': port.isEmpty ? '*' : port,
      });
    }

    if (mounted) {
      Navigator.of(context).pop(newRulesToAdd);
    }
  }
}
