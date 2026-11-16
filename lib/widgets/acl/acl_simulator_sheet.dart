import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/utils/ip_utils.dart';

/// Feuille interactive de simulation ACL ("Qui peut parler à qui ?")
/// et d'épinglage dans le bloc `"tests"` (Headscale >= 0.29.0).
class AclSimulatorSheet extends StatefulWidget {
  final Map<String, dynamic> policy;
  final List<Node> nodes;
  final List<User> users;
  final bool isFr;
  final bool composerAvailable;
  final bool supportsTestsBlock;
  final ValueChanged<Map<String, dynamic>>? onPinTest;
  final ValueChanged<int>? onRemoveTest;
  final void Function(Node sourceNode, String destination)? onAuthorizeWithComposer;

  const AclSimulatorSheet({
    super.key,
    required this.policy,
    required this.nodes,
    required this.users,
    required this.isFr,
    required this.composerAvailable,
    required this.supportsTestsBlock,
    this.onPinTest,
    this.onRemoveTest,
    this.onAuthorizeWithComposer,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> policy,
    required List<Node> nodes,
    required List<User> users,
    required bool isFr,
    required bool composerAvailable,
    required bool supportsTestsBlock,
    ValueChanged<Map<String, dynamic>>? onPinTest,
    ValueChanged<int>? onRemoveTest,
    void Function(Node sourceNode, String destination)? onAuthorizeWithComposer,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: AclSimulatorSheet(
          policy: policy,
          nodes: nodes,
          users: users,
          isFr: isFr,
          composerAvailable: composerAvailable,
          supportsTestsBlock: supportsTestsBlock,
          onPinTest: onPinTest,
          onRemoveTest: onRemoveTest,
          onAuthorizeWithComposer: onAuthorizeWithComposer,
        ),
      ),
    );
  }

  @override
  State<AclSimulatorSheet> createState() => _AclSimulatorSheetState();
}

class _AclSimulatorSheetState extends State<AclSimulatorSheet> {
  late AclParserService _parser;
  Node? _sourceNode;
  String _destinationPreset = 'custom';
  late final TextEditingController _destController;
  late final TextEditingController _portController;
  String _protocol = 'tcp';
  SimulationResult? _result;
  late List<dynamic> _pinnedTests;

  @override
  void initState() {
    super.initState();
    _parser = AclParserService(
      aclPolicy: widget.policy,
      allNodes: widget.nodes,
      allUsers: widget.users,
    );
    _sourceNode = widget.nodes.isNotEmpty ? widget.nodes.first : null;
    final defaultDest = widget.nodes.length > 1
        ? (widget.nodes[1].ipAddresses.isNotEmpty
            ? widget.nodes[1].ipAddresses.first
            : widget.nodes[1].name)
        : 'autogroup:internet';
    _destController = TextEditingController(text: defaultDest);
    _portController = TextEditingController(text: '*');
    _pinnedTests = List<dynamic>.from(
      (widget.policy['tests'] as List?) ?? const [],
    );
    if (_sourceNode != null) {
      _runSimulation();
    }
  }

  @override
  void dispose() {
    _destController.dispose();
    _portController.dispose();
    super.dispose();
  }

  List<_DestinationChoice> _buildDestinationChoices() {
    final choices = <_DestinationChoice>[
      _DestinationChoice(
        value: 'autogroup:internet',
        label: widget.isFr
            ? 'Internet (autogroup:internet)'
            : 'Internet (autogroup:internet)',
      ),
    ];

    for (final node in widget.nodes) {
      final ip = node.ipAddresses.isNotEmpty ? node.ipAddresses.first : node.name;
      choices.add(_DestinationChoice(
        value: ip,
        label: '${node.name} ($ip)',
      ));
    }

    final seenRoutes = <String>{};
    for (final node in widget.nodes) {
      for (final route in node.sharedRoutes) {
        final r = route.trim();
        if (r.isEmpty || r == '0.0.0.0/0' || r == '::/0') continue;
        if (seenRoutes.add(r)) {
          choices.add(_DestinationChoice(
            value: r,
            label: '${widget.isFr ? 'Sous-réseau' : 'Subnet'}: $r (${node.name})',
          ));
        }
      }
    }
    return choices;
  }

  void _runSimulation() {
    final src = _sourceNode;
    final dest = _destController.text.trim();
    if (src == null || dest.isEmpty) {
      setState(() => _result = null);
      return;
    }

    final result = _parser.simulateConnection(
      sourceNode: src,
      destination: dest,
      port: _portController.text.trim().isEmpty
          ? '*'
          : _portController.text.trim(),
      protocol: _protocol,
    );
    setState(() => _result = result);
  }

  Future<void> _pinCurrentTest() async {
    final src = _sourceNode;
    final res = _result;
    if (src == null || res == null || widget.onPinTest == null) return;

    final isFr = widget.isFr;
    final srcAddr = src.ipAddresses.isNotEmpty ? src.ipAddresses.first : src.name;
    var dstAddr = res.normalizedDestination;
    if (dstAddr == 'autogroup:internet') {
      // Headscale/Tailscale "tests" évalue les sorties Internet via une IP publique
      dstAddr = '8.8.8.8';
    } else if (IpUtils.isCIDR(dstAddr)) {
      // Headscale exige une IP concrète (et non un CIDR /24) dans "tests"
      dstAddr = dstAddr.split('/').first;
    }

    var targetPort = res.requestedPort.trim();
    final parsedPort = int.tryParse(targetPort);
    if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
      targetPort = await _askSinglePortDialog(isFr) ?? '';
      if (targetPort.isEmpty || !mounted) return;
    }

    final formattedDst = IpUtils.isIPv6(dstAddr)
        ? '[$dstAddr]:$targetPort'
        : '$dstAddr:$targetPort';

    final entry = <String, dynamic>{
      'src': srcAddr,
      if (res.allowed) 'accept': [formattedDst] else 'deny': [formattedDst],
    };

    widget.onPinTest!(entry);
    setState(() {
      _pinnedTests.add(entry);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFr
              ? 'Test de non-régression ajouté au bloc "tests" ($formattedDst).'
              : 'Regression test pinned to "tests" block ($formattedDst).',
        ),
      ),
    );
  }

  Future<String?> _askSinglePortDialog(bool isFr) async {
    final controller = TextEditingController(text: '443');
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isFr ? 'Port requis pour le bloc "tests"' : 'Port required for "tests"',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr
                    ? 'Headscale refuse le joker "*" dans le bloc "tests" et exige un port numérique unique (ex: 443 ou 22).'
                    : 'Headscale rejects "*" in the "tests" block and requires a single numeric port (e.g. 443 or 22).',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: ['22', '80', '443', '5432']
                    .map((p) => ActionChip(
                          label: Text(p),
                          onPressed: () {
                            controller.text = p;
                            setDialogState(() => errorText = null);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isFr ? 'Port TCP/UDP (1-65535)' : 'Port (1-65535)',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setDialogState(() => errorText = null);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(isFr ? 'Annuler' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val == null || val < 1 || val > 65535) {
                  setDialogState(() {
                    errorText = isFr
                        ? 'Entrez un entier entre 1 et 65535.'
                        : 'Enter an integer between 1 and 65535.';
                  });
                  return;
                }
                Navigator.of(dialogCtx).pop(val.toString());
              },
              child: Text(isFr ? 'Épingler' : 'Pin test'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFr = widget.isFr;
    final theme = Theme.of(context);
    final choices = _buildDestinationChoices();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFr ? 'Simulateur de flux ACL' : 'ACL Flow Simulator',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: widget.nodes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isFr
                      ? 'Aucun nœud disponible pour lancer une simulation.'
                      : 'No node available to run a simulation.',
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.indigo.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        isFr
                            ? 'Simule localement si la machine source peut joindre la cible sans rien modifier sur le serveur. L\'épinglage "tests" est facultatif : il ajoute une règle de vérification automatique que Headscale rejouera à chaque export.'
                            : 'Locally simulates whether the source machine can reach the target without changing anything on the server. Pinning to "tests" is optional: Headscale re-verifies pinned assertions on every export.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Node>(
                    initialValue: _sourceNode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Machine source' : 'Source machine',
                      border: const OutlineInputBorder(),
                    ),
                    items: widget.nodes
                        .map((node) => DropdownMenuItem<Node>(
                              value: node,
                              child: Text(
                                '${node.name} (${node.user}) — ${node.ipAddresses.isNotEmpty ? node.ipAddresses.first : '-'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (node) {
                      setState(() => _sourceNode = node);
                      _runSimulation();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _destinationPreset,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: isFr
                          ? 'Préréglage destination'
                          : 'Destination preset',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          isFr
                              ? 'Saisie manuelle ci-dessous'
                              : 'Manual input below',
                        ),
                      ),
                      ...choices.map(
                        (c) => DropdownMenuItem(
                          value: c.value,
                          child: Text(c.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _destinationPreset = val;
                        if (val != 'custom') {
                          _destController.text = val;
                        }
                      });
                      if (val != 'custom') {
                        _runSimulation();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _destController,
                    decoration: InputDecoration(
                      labelText: isFr
                          ? 'Destination (IP, CIDR, nœud ou autogroup:internet)'
                          : 'Destination (IP, CIDR, node or autogroup:internet)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _destinationPreset = 'custom'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _protocol,
                          decoration: InputDecoration(
                            labelText: isFr ? 'Protocole' : 'Protocol',
                            border: const OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                            DropdownMenuItem(value: 'udp', child: Text('UDP')),
                            DropdownMenuItem(value: 'icmp', child: Text('ICMP')),
                            DropdownMenuItem(value: '*', child: Text('* (Tous)')),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _protocol = val);
                            _runSimulation();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          decoration: InputDecoration(
                            labelText: isFr ? 'Port (* ou numéro)' : 'Port (* or number)',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _runSimulation,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      isFr ? 'Simuler le flux' : 'Simulate traffic',
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_result != null) _buildResultCard(context, _result!, theme),
                  if (widget.supportsTestsBlock && _pinnedTests.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      isFr
                          ? 'Tests de non-régression épinglés (${_pinnedTests.length})'
                          : 'Pinned regression tests (${_pinnedTests.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_pinnedTests.length, (index) {
                      final t = _pinnedTests[index];
                      if (t is! Map) return const SizedBox.shrink();
                      final src = t['src']?.toString() ?? '?';
                      final accept = (t['accept'] as List?)?.join(', ');
                      final deny = (t['deny'] as List?)?.join(', ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            accept != null ? Icons.verified : Icons.block,
                            color: accept != null ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          title: Text(
                            'src: $src',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            [
                              if (accept != null) 'accept: $accept',
                              if (deny != null) 'deny: $deny',
                            ].join(' | '),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                          trailing: widget.onRemoveTest != null
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  onPressed: () {
                                    widget.onRemoveTest!(index);
                                    setState(() {
                                      _pinnedTests.removeAt(index);
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    SimulationResult res,
    ThemeData theme,
  ) {
    final isFr = widget.isFr;
    final color = res.allowed ? Colors.green : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  res.allowed ? Icons.check_circle : Icons.cancel,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  res.allowed
                      ? (isFr ? 'AUTORISÉ' : 'ALLOWED')
                      : (isFr ? 'BLOQUÉ' : 'BLOCKED'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              res.allowed
                  ? (res.matchedRuleSummary ?? '')
                  : (isFr
                      ? 'Aucune règle grant ou acl correspondante dans la politique locale.'
                      : 'No matching grant or acl rule in the local policy.'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            if (res.viaNode != null || res.viaTag != null) ...[
              const SizedBox(height: 6),
              Text(
                '${isFr ? 'Routeur / relais' : 'Router / via'}: ${res.viaNode?.name ?? res.viaTag}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!res.allowed &&
                    widget.composerAvailable &&
                    widget.onAuthorizeWithComposer != null &&
                    _sourceNode != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onAuthorizeWithComposer!(
                        _sourceNode!,
                        res.normalizedDestination,
                      );
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(
                      isFr
                          ? 'Autoriser via le Composeur'
                          : 'Allow via Composer',
                    ),
                  ),
                if (widget.supportsTestsBlock && widget.onPinTest != null)
                  OutlinedButton.icon(
                    onPressed: _pinCurrentTest,
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: Text(
                      isFr
                          ? 'Épingler comme test de non-régression'
                          : 'Pin as regression test',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationChoice {
  final String value;
  final String label;
  const _DestinationChoice({required this.value, required this.label});
}
