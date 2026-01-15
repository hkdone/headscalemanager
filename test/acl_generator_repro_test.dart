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

  test('StandardAclGeneratorService: Missing Tags but Present Routes', () {
    // 1. Setup User "marine"
    final userMarine =
        User(id: '2', name: 'marine@synology.me', createdAt: DateTime.now());

    // 2. Setup Node with routes but NO exit-node/lan-sharer tags
    final nodeMarine = Node(
      id: '200',
      hostname: 'marine-node',
      user: 'marine@synology.me',
      ipAddresses: ['100.64.0.2'],
      tags: [
        'tag:marine-client', // Only client tag
        // NO 'tag:marine-exit-node'
        // NO 'tag:marine-lan-sharer'
      ],
      sharedRoutes: [
        '0.0.0.0/0', // Should trigger internet access
        '10.0.0.0/24' // Should trigger route access
      ],
      availableRoutes: [],
      isExitNode: true,
      isLanSharer: true,
      baseDomain: 'example.com',
      endpoint: '',
      name: 'Marine Node',
      online: true,
      lastSeen: DateTime.now(),
      machineKey: 'key2',
    );

    final users = [userMarine];
    final nodes = [nodeMarine];

    final generator = StandardAclGeneratorService();
    final policy = generator.generatePolicy(users: users, nodes: nodes);

    // 3. Inspect Results
    final acls = policy['acls'] as List<Map<String, dynamic>>;

    // Find the intra-user rule
    final marineRule = acls.firstWhere(
        (rule) => (rule['src'] as List).contains('tag:marine-client'),
        orElse: () => {});

    expect(marineRule, isNotEmpty, reason: 'Should have a rule for marine');

    print('Generated Rule for Marine: $marineRule');

    final dst = (marineRule['dst'] as List?)?.cast<String>() ?? [];

    // Assertions - These are expected to FAIL currently
    expect(dst, contains('autogroup:internet:*'),
        reason:
            'Should contain internet access because 0.0.0.0/0 is shared, even without tag');
    expect(dst, contains('10.0.0.0/24:*'),
        reason:
            'Should contain LAN route because 10.0.0.0/24 is shared, even without tag');
  });
}
