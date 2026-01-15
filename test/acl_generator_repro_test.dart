import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';

void main() {
  test('StandardAclGeneratorService Reproduction Test', () {
    // 1. Setup User "jean"
    final userJean =
        User(id: '1', name: 'jean@synology.me', createdAt: DateTime.now());

    // 2. Setup Node with Exit Node tag and Routes
    // tag:jean-exit-node implies normalized user 'jean'
    final nodeJean = Node(
      id: '100',
      hostname: 'jean-node',
      user: 'jean@synology.me',
      ipAddresses: ['100.64.0.1'],
      tags: [
        'tag:jean-client',
        'tag:jean-exit-node', // <--- This should trigger hasActiveExitNodes
        'tag:jean-lan-sharer'
      ],
      sharedRoutes: [
        '192.168.1.0/24' // <--- This should be added to DST
      ],
      availableRoutes: [],
      isExitNode: true,
      isLanSharer: true,
      baseDomain: 'example.com',
      endpoint: '',
      name: 'Jean Node',
      online: true,
      lastSeen: DateTime.now(),
      machineKey: 'key',
    );

    final users = [userJean];
    final nodes = [nodeJean];

    final generator = StandardAclGeneratorService();
    final policy = generator.generatePolicy(users: users, nodes: nodes);

    // 3. Inspect Results
    final acls = policy['acls'] as List<Map<String, dynamic>>;

    // Find the intra-user rule
    final jeanRule = acls.firstWhere((rule) =>
        (rule['src'] as List).contains('tag:jean-client') &&
        (rule['src'] as List).contains('tag:jean-exit-node'));

    print('Generated Rule for Jean: $jeanRule');

    final dst = (jeanRule['dst'] as List).cast<String>();

    // Assertions
    expect(dst, contains('autogroup:internet:*'),
        reason:
            'Should contain internet access because exit-node tag is present');
    expect(dst, contains('192.168.1.0/24:*'),
        reason:
            'Should contain shared route because lan-sharer tag is present');
  });
}
