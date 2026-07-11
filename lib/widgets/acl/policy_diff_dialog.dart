import 'dart:convert';
import 'package:flutter/material.dart';

class PolicyDiffDialog extends StatelessWidget {
  final Map<String, dynamic> currentPolicy;
  final Map<String, dynamic> newPolicy;
  final bool isFr;

  const PolicyDiffDialog({
    super.key,
    required this.currentPolicy,
    required this.newPolicy,
    required this.isFr,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> currentPolicy,
    required Map<String, dynamic> newPolicy,
    required bool isFr,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PolicyDiffDialog(
        currentPolicy: currentPolicy,
        newPolicy: newPolicy,
        isFr: isFr,
      ),
    );
  }

  String _summarize(Map<String, dynamic> policy) {
    final grants = (policy['grants'] as List?)?.length ?? 0;
    final acls = (policy['acls'] as List?)?.length ?? 0;
    final groups = (policy['groups'] as Map?)?.length ?? 0;
    return isFr
        ? '$grants grants, $acls acls, $groups groupes'
        : '$grants grants, $acls acls, $groups groups';
  }

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    final changed = encoder.convert(currentPolicy) != encoder.convert(newPolicy);

    return AlertDialog(
      title: Text(isFr ? 'Aperçu des changements' : 'Change preview'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isFr ? 'Politique actuelle :' : 'Current policy:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_summarize(currentPolicy)),
              const SizedBox(height: 12),
              Text(isFr ? 'Nouvelle politique :' : 'New policy:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(_summarize(newPolicy)),
              const SizedBox(height: 12),
              Text(
                changed
                    ? (isFr
                        ? 'Le JSON sera modifié avant export.'
                        : 'JSON will be modified before export.')
                    : (isFr
                        ? 'Aucune différence détectée.'
                        : 'No difference detected.'),
                style: TextStyle(
                  color: changed ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: changed ? () => Navigator.pop(context, true) : null,
          child: Text(isFr ? 'Confirmer export' : 'Confirm export'),
        ),
      ],
    );
  }
}
