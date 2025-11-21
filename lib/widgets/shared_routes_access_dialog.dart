import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/ip_utils.dart';

enum RouteAccessChoice { none, full, custom }

class SharedRoutesAccessDialog extends StatefulWidget {
  final Node destinationNode;

  const SharedRoutesAccessDialog({super.key, required this.destinationNode});

  @override
  State<SharedRoutesAccessDialog> createState() =>
      _SharedRoutesAccessDialogState();
}

class _SharedRoutesAccessDialogState extends State<SharedRoutesAccessDialog> {
  RouteAccessChoice _choice = RouteAccessChoice.none;
  final Map<String, _CustomRule> _customRules = {};
  late List<String> _lanRoutes;

  @override
  void initState() {
    super.initState();
    _lanRoutes = widget.destinationNode.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();
    for (var route in _lanRoutes) {
      _customRules[route] = _CustomRule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';

    return AlertDialog(
      title: Text(isFr
          ? 'Accès aux routes partagées'
          : 'Shared Routes Access'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFr
                  ? 'Le nœud de destination partage les sous-réseaux suivants. Choisissez comment y accéder.'
                  : 'The destination node shares the following subnets. Choose how to access them.',
            ),
            const SizedBox(height: 16),
            ..._buildChoiceRadios(isFr),
            if (_choice == RouteAccessChoice.custom)
              _buildCustomRulesSection(isFr),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(isFr ? 'Annuler' : 'Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _handleConfirm,
          child: Text(isFr ? 'Confirmer' : 'Confirm'),
        ),
      ],
    );
  }

  List<Widget> _buildChoiceRadios(bool isFr) {
    return [
      RadioListTile<RouteAccessChoice>(
        title: Text(isFr ? 'Accès au nœud uniquement' : 'Node access only'),
        subtitle: Text(isFr
            ? 'Autoriser l\'accès au nœud mais pas aux sous-réseaux partagés'
            : 'Allow access to the node but not to shared subnets'),
        value: RouteAccessChoice.none,
        groupValue: _choice,
        onChanged: (value) => setState(() => _choice = value!),
      ),
      RadioListTile<RouteAccessChoice>(
        title: Text(isFr ? 'Accès total' : 'Full access'),
        subtitle: Text(isFr
            ? 'Autoriser l\'accès au nœud et à toutes les routes partagées'
            : 'Allow access to the node and all shared routes'),
        value: RouteAccessChoice.full,
        groupValue: _choice,
        onChanged: (value) => setState(() => _choice = value!),
      ),
      RadioListTile<RouteAccessChoice>(
        title: Text(isFr ? 'Accès personnalisé' : 'Custom access'),
        subtitle: Text(isFr
            ? 'Définir des règles spécifiques par sous-réseau'
            : 'Define specific rules per subnet'),
        value: RouteAccessChoice.custom,
        groupValue: _choice,
        onChanged: (value) => setState(() => _choice = value!),
      ),
    ];
  }

  Widget _buildCustomRulesSection(bool isFr) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _lanRoutes.map((route) {
          return _SubnetRuleCard(
            subnet: route,
            rule: _customRules[route]!,
            isFr: isFr,
          );
        }).toList(),
      ),
    );
  }

  void _handleConfirm() {
    final isFr = Localizations.localeOf(context).languageCode == 'fr';
    
    // Debug: Afficher le choix sélectionné
    debugPrint('DEBUG DIALOG: Choix sélectionné: $_choice');
    
    if (_choice == RouteAccessChoice.custom) {
      // Validate all custom rules before popping
      for (var route in _lanRoutes) {
        final rule = _customRules[route]!;
        final startIp = rule.startIpController.text;
        final endIp = rule.endIpController.text;

        if (startIp.isNotEmpty && !IpUtils.isValidIp(startIp)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${isFr ? 'Format IP de début invalide pour' : 'Invalid start IP format for'} $route')));
          return;
        }

        if (startIp.isNotEmpty && !IpUtils.isIpInSubnet(startIp, route)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${isFr ? 'IP de début n\'est pas dans le sous-réseau' : 'Start IP is not in subnet'} $route')));
          return;
        }

        if (endIp.isNotEmpty && !IpUtils.isValidIp(endIp)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${isFr ? 'Format IP de fin invalide pour' : 'Invalid end IP format for'} $route')));
          return;
        }

        if (endIp.isNotEmpty && !IpUtils.isIpInSubnet(endIp, route)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${isFr ? 'IP de fin n\'est pas dans le sous-réseau' : 'End IP is not in subnet'} $route')));
          return;
        }
      }
    }

    final result = {
      'choice': _choice,
      'rules': _customRules.map((key, value) => MapEntry(key, {
            'startIp': value.startIpController.text,
            'endIp': value.endIpController.text,
            'ports': value.portsController.text,
          })),
    };
    
    // Debug: Afficher le résultat qui va être retourné
    debugPrint('DEBUG DIALOG: Résultat retourné: $result');
    
    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    for (var rule in _customRules.values) {
      rule.dispose();
    }
    super.dispose();
  }
}

class _SubnetRuleCard extends StatelessWidget {
  final String subnet;
  final _CustomRule rule;
  final bool isFr;

  const _SubnetRuleCard(
      {required this.subnet, required this.rule, required this.isFr});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subnet, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: rule.startIpController,
              decoration: InputDecoration(
                labelText: isFr ? 'IP de début' : 'Start IP',
                hintText: 'Ex: 192.168.1.10',
              ),
            ),
            TextFormField(
              controller: rule.endIpController,
              decoration: InputDecoration(
                labelText: isFr ? 'IP de fin (optionnel)' : 'End IP (optional)',
                hintText: isFr
                    ? 'Laisser vide si IP unique'
                    : 'Leave empty for single IP',
              ),
            ),
            TextFormField(
              controller: rule.portsController,
              decoration: InputDecoration(
                labelText: isFr ? 'Ports (optionnel)' : 'Ports (optional)',
                hintText: isFr ? 'Ex: 80, 443, 1024-2048' : 'E.g. 80, 443, 1024-2048',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomRule {
  final TextEditingController startIpController = TextEditingController();
  final TextEditingController endIpController = TextEditingController();
  final TextEditingController portsController = TextEditingController();

  void dispose() {
    startIpController.dispose();
    endIpController.dispose();
    portsController.dispose();
  }
}
