import 'package:flutter/material.dart';

class GrantsListView extends StatelessWidget {
  final List<dynamic> grants;
  final bool isFr;
  final void Function(int networkIndex, Map<String, dynamic> grant)? onEditGrant;
  final void Function(int networkIndex)? onDeleteGrant;

  const GrantsListView({
    super.key,
    required this.grants,
    required this.isFr,
    this.onEditGrant,
    this.onDeleteGrant,
  });

  static bool isTaildriveGrant(Map<String, dynamic> grant) {
    final app = grant['app'];
    if (app is! Map) return false;
    return app.containsKey('tailscale.com/cap/drive') ||
        app.containsKey('tailscale.com/cap/taildrive');
  }

  static bool isNetworkGrant(Map<String, dynamic> grant) {
    return grant.containsKey('ip') && !isTaildriveGrant(grant);
  }

  @override
  Widget build(BuildContext context) {
    final networkEntries = <({int index, Map<String, dynamic> grant})>[];
    for (var i = 0; i < grants.length; i++) {
      final g = grants[i];
      if (g is Map<String, dynamic> && isNetworkGrant(g)) {
        networkEntries.add((index: networkEntries.length, grant: g));
      } else if (g is Map && isNetworkGrant(Map<String, dynamic>.from(g))) {
        networkEntries.add(
            (index: networkEntries.length, grant: Map<String, dynamic>.from(g)));
      }
    }

    final taildriveGrants = grants
        .whereType<Map<String, dynamic>>()
        .where(isTaildriveGrant)
        .toList();

    if (networkEntries.isEmpty && taildriveGrants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isFr
                ? 'Aucun grant réseau dans la politique.'
                : 'No network grants in policy.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (networkEntries.isNotEmpty) ...[
          Text(
            isFr ? 'Grants réseau (ip + via)' : 'Network grants (ip + via)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...networkEntries.map((e) => _GrantTile(
                grant: e.grant,
                isFr: isFr,
                onTap: onEditGrant != null
                    ? () => onEditGrant!(e.index, e.grant)
                    : null,
                onDelete: onDeleteGrant != null
                    ? () => onDeleteGrant!(e.index)
                    : null,
              )),
        ],
        if (taildriveGrants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            isFr ? 'Grants Taildrive' : 'Taildrive grants',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...taildriveGrants.map((g) => _GrantTile(
                grant: g,
                isFr: isFr,
                isTaildrive: true,
              )),
        ],
      ],
    );
  }
}

class _GrantTile extends StatelessWidget {
  final Map<String, dynamic> grant;
  final bool isFr;
  final bool isTaildrive;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _GrantTile({
    required this.grant,
    required this.isFr,
    this.isTaildrive = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final src = (grant['src'] as List?)?.join(', ') ?? '?';
    final dst = (grant['dst'] as List?)?.join(', ') ?? '?';
    final via = (grant['via'] as List?)?.join(', ');
    final ip = (grant['ip'] as List?)?.join(', ') ?? '*';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isTaildrive ? Icons.folder_shared : Icons.route,
          color: via != null ? Colors.purple : Colors.blue,
        ),
        title: Text('$src → $dst'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (via != null)
              Text(
                isFr ? 'Via : $via' : 'Via: $via',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.purple),
              ),
            Text(isFr ? 'IP : $ip' : 'IP: $ip'),
            if (onTap != null)
              Text(
                isFr ? 'Appuyer pour modifier' : 'Tap to edit',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
      ),
    );
  }
}
