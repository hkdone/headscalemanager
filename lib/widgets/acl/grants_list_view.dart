import 'package:flutter/material.dart';

class GrantsListView extends StatelessWidget {
  final List<dynamic> grants;
  final bool isFr;

  const GrantsListView({
    super.key,
    required this.grants,
    required this.isFr,
  });

  bool _isTaildriveGrant(Map<String, dynamic> grant) {
    final app = grant['app'];
    if (app is! Map) return false;
    return app.containsKey('tailscale.com/cap/drive') ||
        app.containsKey('tailscale.com/cap/taildrive');
  }

  bool _isNetworkGrant(Map<String, dynamic> grant) {
    return grant.containsKey('ip') && !_isTaildriveGrant(grant);
  }

  @override
  Widget build(BuildContext context) {
    final networkGrants = grants
        .whereType<Map<String, dynamic>>()
        .where(_isNetworkGrant)
        .toList();
    final taildriveGrants = grants
        .whereType<Map<String, dynamic>>()
        .where(_isTaildriveGrant)
        .toList();

    if (networkGrants.isEmpty && taildriveGrants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isFr ? 'Aucun grant réseau dans la politique.' : 'No network grants in policy.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        if (networkGrants.isNotEmpty) ...[
          Text(
            isFr ? 'Grants réseau (ip + via)' : 'Network grants (ip + via)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...networkGrants.map((g) => _GrantTile(grant: g, isFr: isFr)),
        ],
        if (taildriveGrants.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            isFr ? 'Grants Taildrive' : 'Taildrive grants',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...taildriveGrants.map((g) => _GrantTile(grant: g, isFr: isFr, isTaildrive: true)),
        ],
      ],
    );
  }
}

class _GrantTile extends StatelessWidget {
  final Map<String, dynamic> grant;
  final bool isFr;
  final bool isTaildrive;

  const _GrantTile({
    required this.grant,
    required this.isFr,
    this.isTaildrive = false,
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
          ],
        ),
        isThreeLine: via != null,
      ),
    );
  }
}
