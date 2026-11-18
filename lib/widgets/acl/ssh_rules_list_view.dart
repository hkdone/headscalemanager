import 'package:material_ui/material_ui.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Valide les contraintes Tailscale/Headscale sur les règles `"ssh"`.
class SshRuleValidator {
  static String? validate({
    required List<String> src,
    required List<String> dst,
    required List<String> users,
    required bool isFr,
  }) {
    if (src.isEmpty) {
      return isFr
          ? 'Sélectionnez au moins une source.'
          : 'Select at least one source.';
    }
    if (dst.isEmpty) {
      return isFr
          ? 'Sélectionnez au moins une destination.'
          : 'Select at least one destination.';
    }
    if (users.isEmpty) {
      return isFr
          ? 'Spécifiez au moins un compte Linux autorisé.'
          : 'Specify at least one allowed Linux account.';
    }

    for (final rawDst in dst) {
      final d = rawDst.trim();
      if (d == '*' ||
          d == 'autogroup:internet' ||
          IpUtils.isCIDR(d) ||
          IpUtils.isIPv4(d) ||
          IpUtils.isIPv6(d)) {
        return isFr
            ? 'Destination SSH invalide ("$d") : utilisez autogroup:self ou un tag:.'
            : 'Invalid SSH destination ("$d"): use autogroup:self or a tag:.';
      }
      final isSelf = d == 'autogroup:self';
      final isTag = d.startsWith('tag:');
      final matchesSameSingleSrc = src.length == 1 && src.first.trim() == d;
      if (!isSelf && !isTag && !matchesSameSingleSrc) {
        return isFr
            ? 'Tailscale SSH impose que dst ("$d") soit autogroup:self ou un tag: lorsque src != dst.'
            : 'Tailscale SSH requires dst ("$d") to be autogroup:self or a tag: when src != dst.';
      }
    }
    return null;
  }
}

/// Vue de gestion des règles Tailscale SSH (`policy['ssh']`).
class SshRulesListView extends StatelessWidget {
  final List<dynamic> sshRules;
  final List<Node> allNodes;
  final List<User> allUsers;
  final Map<String, dynamic> policy;
  final bool isFr;
  final ValueChanged<Map<String, dynamic>> onAddRule;
  final void Function(int index, Map<String, dynamic> updatedRule) onEditRule;
  final ValueChanged<int> onDeleteRule;

  const SshRulesListView({
    super.key,
    required this.sshRules,
    required this.allNodes,
    required this.allUsers,
    required this.policy,
    required this.isFr,
    required this.onAddRule,
    required this.onEditRule,
    required this.onDeleteRule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.indigo.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tailscale SSH',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFr
                            ? 'Contrôle les accès SSH sans clé via Headscale ("ssh": [...]).'
                            : 'Controls keyless Tailscale SSH sessions via Headscale ("ssh": [...]).',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final rule = await SshRuleDialog.show(
                      context,
                      allNodes: allNodes,
                      allUsers: allUsers,
                      policy: policy,
                      isFr: isFr,
                    );
                    if (rule != null) {
                      onAddRule(rule);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(isFr ? 'Ajouter' : 'Add'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (sshRules.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isFr
                    ? 'Aucune règle Tailscale SSH configurée. Ajoutez une règle pour autoriser les connexions SSH sur vos nœuds.'
                    : 'No Tailscale SSH rule configured. Add a rule to allow SSH connections on your nodes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sshRules.length,
            itemBuilder: (context, index) {
              final raw = sshRules[index];
              if (raw is! Map) return const SizedBox.shrink();
              final rule = Map<String, dynamic>.from(raw);
              final action = rule['action']?.toString() ?? 'accept';
              final isCheck = action == 'check';
              final src = (rule['src'] as List?)?.join(', ') ?? '?';
              final dst = (rule['dst'] as List?)?.join(', ') ?? '?';
              final users = (rule['users'] as List?)?.join(', ') ?? '?';
              final checkPeriod = rule['checkPeriod']?.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    isCheck ? Icons.verified_user : Icons.terminal,
                    color: isCheck ? Colors.orange : Colors.teal,
                  ),
                  title: Text('$src → $dst'),
                  subtitle: Text(
                    'action: $action${checkPeriod != null ? ' ($checkPeriod)' : ''} • users: $users',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: isFr ? 'Modifier' : 'Edit',
                        onPressed: () async {
                          final updated = await SshRuleDialog.show(
                            context,
                            allNodes: allNodes,
                            allUsers: allUsers,
                            policy: policy,
                            initialRule: rule,
                            isFr: isFr,
                          );
                          if (updated != null) {
                            onEditRule(index, updated);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        tooltip: isFr ? 'Supprimer' : 'Delete',
                        onPressed: () => onDeleteRule(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Dialogue de création / édition d'une règle Tailscale SSH avec validation stricte.
class SshRuleDialog extends StatefulWidget {
  final List<Node> allNodes;
  final List<User> allUsers;
  final Map<String, dynamic> policy;
  final Map<String, dynamic>? initialRule;
  final bool isFr;

  const SshRuleDialog({
    super.key,
    required this.allNodes,
    required this.allUsers,
    required this.policy,
    this.initialRule,
    required this.isFr,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<Node> allNodes,
    required List<User> allUsers,
    required Map<String, dynamic> policy,
    Map<String, dynamic>? initialRule,
    required bool isFr,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SshRuleDialog(
        allNodes: allNodes,
        allUsers: allUsers,
        policy: policy,
        initialRule: initialRule,
        isFr: isFr,
      ),
    );
  }

  @override
  State<SshRuleDialog> createState() => _SshRuleDialogState();
}

class _SshRuleDialogState extends State<SshRuleDialog> {
  late Set<String> _selectedSrc;
  late Set<String> _selectedDst;
  late Set<String> _selectedUsers;
  late String _action;
  late TextEditingController _customSrcCtrl;
  late TextEditingController _customDstCtrl;
  late TextEditingController _customUserCtrl;
  late TextEditingController _checkPeriodCtrl;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialRule;
    _selectedSrc = {
      ...?((initial?['src'] as List?)?.map((e) => e.toString())),
    };
    if (_selectedSrc.isEmpty) {
      _selectedSrc.add('autogroup:member');
    }
    _selectedDst = {
      ...?((initial?['dst'] as List?)?.map((e) => e.toString())),
    };
    if (_selectedDst.isEmpty) {
      _selectedDst.add('autogroup:self');
    }
    _selectedUsers = {
      ...?((initial?['users'] as List?)?.map((e) => e.toString())),
    };
    if (_selectedUsers.isEmpty) {
      _selectedUsers.add('autogroup:nonroot');
    }
    _action = initial?['action']?.toString() ?? 'accept';
    _customSrcCtrl = TextEditingController();
    _customDstCtrl = TextEditingController();
    _customUserCtrl = TextEditingController();
    _checkPeriodCtrl = TextEditingController(
      text: initial?['checkPeriod']?.toString() ?? '12h',
    );
  }

  @override
  void dispose() {
    _customSrcCtrl.dispose();
    _customDstCtrl.dispose();
    _customUserCtrl.dispose();
    _checkPeriodCtrl.dispose();
    super.dispose();
  }

  List<String> _collectTags() {
    final tags = <String>{
      for (final node in widget.allNodes) ...node.tags,
      if (widget.policy['tagOwners'] is Map)
        ...(widget.policy['tagOwners'] as Map).keys.map((k) => k.toString()),
    };
    final list = tags.toList()..sort();
    return list;
  }

  List<String> _collectGroups() {
    final groups = <String>{
      for (final u in widget.allUsers) 'group:${normalizeUserName(u.name)}',
      if (widget.policy['groups'] is Map)
        ...(widget.policy['groups'] as Map).keys.map((k) => k.toString()),
    };
    final list = groups.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isFr = widget.isFr;
    final tags = _collectTags();
    final groups = _collectGroups();

    final srcOptions = <String>{
      'autogroup:member',
      ...groups,
      ...tags,
      ..._selectedSrc,
    }.toList();

    final dstOptions = <String>{
      'autogroup:self',
      ...tags,
      ..._selectedDst,
    }.toList();

    final userOptions = <String>{
      'autogroup:nonroot',
      'root',
      ..._selectedUsers,
    }.toList();

    final validationError = SshRuleValidator.validate(
      src: _selectedSrc.toList(),
      dst: _selectedDst.toList(),
      users: _selectedUsers.toList(),
      isFr: isFr,
    );

    return AlertDialog(
      title: Text(
        widget.initialRule == null
            ? (isFr ? 'Nouvelle règle Tailscale SSH' : 'New Tailscale SSH Rule')
            : (isFr ? 'Modifier règle Tailscale SSH' : 'Edit Tailscale SSH Rule'),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isFr ? 'Source (src)' : 'Source (src)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: srcOptions
                    .map((s) => FilterChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          selected: _selectedSrc.contains(s),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedSrc.add(s);
                              } else {
                                _selectedSrc.remove(s);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              _CustomTokenInput(
                controller: _customSrcCtrl,
                hint: isFr ? 'Ajouter src (ex: group:admin)' : 'Add src (e.g. group:admin)',
                onAdd: (val) => setState(() => _selectedSrc.add(val)),
              ),
              const SizedBox(height: 14),
              Text(
                isFr
                    ? 'Destination (dst — autogroup:self ou tag:...)'
                    : 'Destination (dst — autogroup:self or tag:...)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: dstOptions
                    .map((d) => FilterChip(
                          label: Text(d, style: const TextStyle(fontSize: 12)),
                          selected: _selectedDst.contains(d),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedDst.add(d);
                              } else {
                                _selectedDst.remove(d);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              _CustomTokenInput(
                controller: _customDstCtrl,
                hint: isFr ? 'Ajouter dst (ex: tag:server)' : 'Add dst (e.g. tag:server)',
                onAdd: (val) => setState(() => _selectedDst.add(val)),
              ),
              const SizedBox(height: 14),
              Text(
                isFr ? 'Comptes Linux autorisés (users)' : 'Allowed Linux accounts (users)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: userOptions
                    .map((u) => FilterChip(
                          label: Text(u, style: const TextStyle(fontSize: 12)),
                          selected: _selectedUsers.contains(u),
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedUsers.add(u);
                              } else {
                                _selectedUsers.remove(u);
                              }
                            });
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              _CustomTokenInput(
                controller: _customUserCtrl,
                hint: isFr ? 'Compte Linux (ex: ubuntu)' : 'Linux user (e.g. ubuntu)',
                onAdd: (val) => setState(() => _selectedUsers.add(val)),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _action,
                decoration: InputDecoration(
                  labelText: 'Action',
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'accept',
                    child: Text(isFr ? 'accept (connexion directe)' : 'accept (direct access)'),
                  ),
                  DropdownMenuItem(
                    value: 'check',
                    child: Text(isFr ? 'check (vérification périodique)' : 'check (periodic verification)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _action = v);
                },
              ),
              if (_action == 'check') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _checkPeriodCtrl,
                  decoration: InputDecoration(
                    labelText: isFr ? 'Durée checkPeriod (ex: 12h)' : 'checkPeriod (e.g. 12h)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (validationError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.45)),
                  ),
                  child: Text(
                    validationError,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        FilledButton(
          onPressed: validationError != null
              ? null
              : () {
                  final rule = <String, dynamic>{
                    'action': _action,
                    'src': _selectedSrc.toList(),
                    'dst': _selectedDst.toList(),
                    'users': _selectedUsers.toList(),
                    if (_action == 'check' &&
                        _checkPeriodCtrl.text.trim().isNotEmpty)
                      'checkPeriod': _checkPeriodCtrl.text.trim(),
                  };
                  Navigator.of(context).pop(rule);
                },
          child: Text(isFr ? 'Valider' : 'Validate'),
        ),
      ],
    );
  }
}

class _CustomTokenInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onAdd;

  const _CustomTokenInput({
    required this.controller,
    required this.hint,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (val) {
              final trimmed = val.trim();
              if (trimmed.isNotEmpty) {
                onAdd(trimmed);
                controller.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            final trimmed = controller.text.trim();
            if (trimmed.isNotEmpty) {
              onAdd(trimmed);
              controller.clear();
            }
          },
        ),
      ],
    );
  }
}
