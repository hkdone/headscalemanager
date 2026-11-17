import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';

enum TaglessRouteApprovalChoice {
  cancel,
  approveWithoutTags,
  convertToTaggedRouter,
}

/// Propose à l'administrateur de conserver un nœud sans tag lors de l'approbation
/// de routes (LAN / Exit Node) au lieu de le convertir de force en `tagged-devices`.
Future<TaglessRouteApprovalChoice> showTaglessRouteChoiceDialog(
  BuildContext context, {
  required Node node,
  required bool isFr,
  required bool isExitNode,
  required bool isLanSharer,
}) async {
  final capabilityLabel = [
    if (isExitNode) 'Exit Node',
    if (isLanSharer) 'LAN',
  ].join(' / ');

  final result = await showDialog<TaglessRouteApprovalChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        isFr
            ? 'Approuver $capabilityLabel sans tag ?'
            : 'Approve $capabilityLabel without tags?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr
                ? 'L\'appareil "${node.name}" n\'a actuellement aucun tag et appartient directement à un utilisateur humain.'
                : 'Device "${node.name}" currently has no tags and belongs directly to a human user.',
          ),
          const SizedBox(height: 12),
          Text(
            isFr
                ? '• Sans tag (Recommandé) : la route est approuvée via group:<utilisateur> en Mode Hybride.\n• Convertir en routeur tagué : déplace le nœud vers "tagged-devices" (utile uniquement si deux utilisateurs partagent le même CIDR LAN avec "via").'
                : '• Keep tagless (Recommended): routes are approved via group:<user> in Hybrid Mode.\n• Convert to tagged router: moves the node to "tagged-devices" (only needed when two users share the exact same LAN CIDR with "via").',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(TaglessRouteApprovalChoice.cancel),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(ctx)
              .pop(TaglessRouteApprovalChoice.convertToTaggedRouter),
          child: Text(
            isFr ? 'Convertir en routeur tagué' : 'Convert to tagged router',
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx)
              .pop(TaglessRouteApprovalChoice.approveWithoutTags),
          child: Text(
            isFr
                ? 'Approuver sans tag (Recommandé)'
                : 'Approve tagless (Recommended)',
          ),
        ),
      ],
    ),
  );

  return result ?? TaglessRouteApprovalChoice.cancel;
}
