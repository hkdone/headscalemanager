import 'package:flutter/material.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/utils/string_utils.dart';

class AclEngineBanner extends StatelessWidget {
  final AclEngineMode engineMode;
  final String serverVersion;
  final List<User> users;
  final List<Node> nodes;
  final bool isFr;
  final bool compact;

  const AclEngineBanner({
    super.key,
    required this.engineMode,
    required this.serverVersion,
    required this.users,
    required this.nodes,
    required this.isFr,
    this.compact = false,
  });

  List<String> _usersWithoutTaggedNodes() {
    final warnings = <String>[];
    for (var user in users) {
      final norm = normalizeUserName(user.name);
      final stdClientTag = 'tag:$norm-client';
      final hasTaggedNode = nodes.any((n) =>
          (n.user == user.name || n.getNormalizedOwner() == norm) &&
          n.tags.any((t) =>
              t == stdClientTag ||
              t.startsWith('tag:$norm-client') ||
              t.contains(';')));
      if (!hasTaggedNode) {
        warnings.add(user.name);
      }
    }
    return warnings;
  }

  String _engineLabel() {
    switch (engineMode) {
      case AclEngineMode.legacy:
        return isFr ? 'Legacy (tags fusionnés)' : 'Legacy (merged tags)';
      case AclEngineMode.standard:
        return isFr ? 'Standard (tags séparés)' : 'Standard (split tags)';
      case AclEngineMode.grantsV29:
        return isFr ? 'Grants V29 (via)' : 'Grants V29 (via)';
    }
  }

  Color _engineColor(BuildContext context) {
    switch (engineMode) {
      case AclEngineMode.legacy:
        return Colors.orange;
      case AclEngineMode.standard:
        return Colors.blue;
      case AclEngineMode.grantsV29:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final untagged = _usersWithoutTaggedNodes();
    final grantsFallback = engineMode == AclEngineMode.grantsV29 &&
        !VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0');

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.settings_suggest,
                size: 18, color: _engineColor(context)),
            const SizedBox(width: 6),
            Text(
              isFr ? 'Moteur :' : 'Engine:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 6),
            Chip(
              label: Text(
                _engineLabel(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              backgroundColor: _engineColor(context).withValues(alpha: 0.15),
            ),
            if (grantsFallback) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFr ? 'Fallback Standard (< 0.29)' : 'Standard fallback (< 0.29)',
                  style: TextStyle(color: Colors.orange[800], fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_suggest, color: _engineColor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFr ? 'Moteur actif : ' : 'Active engine: ',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(
                    _engineLabel(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  backgroundColor:
                      _engineColor(context).withValues(alpha: 0.15),
                ),
              ],
            ),
            if (grantsFallback)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isFr
                      ? 'Serveur < 0.29 : fallback Standard appliqué à la génération.'
                      : 'Server < 0.29: Standard fallback used for generation.',
                  style: TextStyle(color: Colors.orange[800], fontSize: 12),
                ),
              ),
            if (untagged.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber,
                        size: 18, color: Colors.amber[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Utilisateurs sans nœud tagué (aucune règle auto) : ${untagged.join(", ")}'
                            : 'Users without tagged nodes (no auto rules): ${untagged.join(", ")}',
                        style: TextStyle(
                            color: Colors.amber[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
