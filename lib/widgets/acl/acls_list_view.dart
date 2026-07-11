import 'package:flutter/material.dart';

class AclsListView extends StatelessWidget {
  final List<dynamic> acls;
  final bool isFr;

  const AclsListView({
    super.key,
    required this.acls,
    required this.isFr,
  });

  @override
  Widget build(BuildContext context) {
    if (acls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isFr ? 'Aucune règle ACL classique.' : 'No classic ACL rules.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: acls.length,
      itemBuilder: (context, index) {
        final rule = acls[index];
        if (rule is! Map) return const SizedBox.shrink();
        final action = rule['action']?.toString() ?? 'accept';
        final src = (rule['src'] as List?)?.join(', ') ?? '?';
        final dst = (rule['dst'] as List?)?.join(', ') ?? '?';
        final proto = rule['proto']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              action == 'accept' ? Icons.check_circle : Icons.block,
              color: action == 'accept' ? Colors.green : Colors.red,
            ),
            title: Text('$src → $dst'),
            subtitle: proto != null ? Text('Proto: $proto') : null,
          ),
        );
      },
    );
  }
}
