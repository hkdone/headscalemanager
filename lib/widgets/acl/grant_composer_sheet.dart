import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';

/// Composeur guidé de grants réseau (Headscale 0.29+, moteur Grants V29).
class GrantComposerSheet extends StatefulWidget {
  final List<User> users;
  final List<Node> nodes;
  final bool isFr;
  final Node? prefilledRouterNode;
  final GrantComposerTemplate? initialTemplate;

  const GrantComposerSheet({
    super.key,
    required this.users,
    required this.nodes,
    required this.isFr,
    this.prefilledRouterNode,
    this.initialTemplate,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<User> users,
    required List<Node> nodes,
    required bool isFr,
    Node? prefilledRouterNode,
    GrantComposerTemplate? initialTemplate,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GrantComposerSheet(
        users: users,
        nodes: nodes,
        isFr: isFr,
        prefilledRouterNode: prefilledRouterNode,
        initialTemplate: initialTemplate,
      ),
    );
  }

  @override
  State<GrantComposerSheet> createState() => _GrantComposerSheetState();
}

class _GrantComposerSheetState extends State<GrantComposerSheet> {
  int _step = 0;
  GrantComposerTemplate _template = GrantComposerTemplate.lanAccess;
  final Set<String> _selectedSrc = {};
  String? _selectedVia;
  final Set<String> _selectedDst = {};
  String _targetIp = '';
  bool _isExceptionAcl = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTemplate != null) {
      _template = widget.initialTemplate!;
    }
    if (widget.prefilledRouterNode != null) {
      _applyPrefilledRouter(widget.prefilledRouterNode!);
    }
  }

  void _applyPrefilledRouter(Node node) {
    final norm = node.getNormalizedOwner();
    final lanTag = GrantComposerService.lanSharerTagForUser(norm);
    final exitTag = GrantComposerService.exitNodeTagForUser(norm);
    if (node.isExitNode && node.tags.contains(exitTag)) {
      _template = GrantComposerTemplate.internetExit;
      _selectedVia = exitTag;
    } else if (node.sharedRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0')) {
      _template = GrantComposerTemplate.lanAccess;
      if (node.tags.contains(lanTag)) _selectedVia = lanTag;
    }
    final clientTag = GrantComposerService.clientTagForUser(norm);
    if (node.tags.contains(clientTag)) _selectedSrc.add(clientTag);
  }

  int get _maxStep => _isExceptionAcl ? 3 : 4;

  bool get _needsVia =>
      !_isExceptionAcl &&
      _template != GrantComposerTemplate.intraFleet;

  String _templateLabel(GrantComposerTemplate t) {
    if (!widget.isFr) {
      switch (t) {
        case GrantComposerTemplate.lanAccess:
          return 'LAN access';
        case GrantComposerTemplate.internetExit:
          return 'Internet exit';
        case GrantComposerTemplate.intraFleet:
          return 'Intra-fleet';
        case GrantComposerTemplate.targetedIp:
          return 'Targeted IP';
        case GrantComposerTemplate.exceptionAcl:
          return 'Exception (ACL)';
      }
    }
    switch (t) {
      case GrantComposerTemplate.lanAccess:
        return 'Accès LAN';
      case GrantComposerTemplate.internetExit:
        return 'Sortie internet';
      case GrantComposerTemplate.intraFleet:
        return 'Intra-flotte';
      case GrantComposerTemplate.targetedIp:
        return 'IP ciblée';
      case GrantComposerTemplate.exceptionAcl:
        return 'Exception (ACL)';
    }
  }

  IconData _templateIcon(GrantComposerTemplate t) {
    switch (t) {
      case GrantComposerTemplate.lanAccess:
        return Icons.lan;
      case GrantComposerTemplate.internetExit:
        return Icons.public;
      case GrantComposerTemplate.intraFleet:
        return Icons.hub;
      case GrantComposerTemplate.targetedIp:
        return Icons.pin;
      case GrantComposerTemplate.exceptionAcl:
        return Icons.rule;
    }
  }

  String? _routerOwnerNorm() {
    if (_selectedVia == null) return null;
    for (var node in widget.nodes) {
      final norm = node.getNormalizedOwner();
      if (node.tags.contains(_selectedVia)) return norm;
      if (node.tags.any((t) => t == _selectedVia)) return norm;
    }
    return null;
  }

  Map<String, dynamic>? _buildResult() {
    if (_isExceptionAcl) {
      if (_selectedSrc.isEmpty || _selectedDst.isEmpty) return null;
      return GrantComposerService.buildExceptionAcl(
        src: _selectedSrc.first,
        dst: _selectedDst.first,
      );
    }

    if (_selectedSrc.isEmpty || _selectedDst.isEmpty) return null;
    if (_needsVia && (_selectedVia == null || _selectedVia!.isEmpty)) {
      return null;
    }

    return GrantComposerService.buildNetworkGrant(
      src: _selectedSrc.toList()..sort(),
      dst: _selectedDst.toList()..sort(),
      via: _needsVia && _selectedVia != null ? [_selectedVia!] : const [],
    );
  }

  void _next() {
    if (_step == 0) {
      _isExceptionAcl = _template == GrantComposerTemplate.exceptionAcl;
    }
    if (_step < _maxStep) {
      setState(() => _step++);
    } else {
      final result = _buildResult();
      if (result != null) Navigator.pop(context, result);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  bool _canNext() {
    switch (_step) {
      case 0:
        return true;
      case 1:
        return _selectedSrc.isNotEmpty;
      case 2:
        if (_isExceptionAcl) {
          return _selectedDst.isNotEmpty;
        }
        if (!_needsVia) return true;
        return _selectedVia != null;
      case 3:
        if (_isExceptionAcl) return _buildResult() != null;
        if (_template == GrantComposerTemplate.targetedIp) {
          return _targetIp.trim().isNotEmpty || _selectedDst.isNotEmpty;
        }
        return _selectedDst.isNotEmpty;
      case 4:
        return _buildResult() != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildResult();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isFr
                            ? 'Composeur de grants'
                            : 'Grant composer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Text('${_step + 1}/$_maxStep'),
                  ],
                ),
              ),
              LinearProgressIndicator(value: (_step + 1) / (_maxStep + 1)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_step == 0) _buildTemplateStep(),
                    if (_step == 1) _buildSourceStep(),
                    if (_step == 2 && !_isExceptionAcl) _buildViaStep(),
                    if (_step == 2 && _isExceptionAcl) _buildDestStep(),
                    if (_step == 3 && !_isExceptionAcl) _buildDestStep(),
                    if (_step == 3 && _isExceptionAcl) _buildPreviewStep(preview),
                    if (_step == 4) _buildPreviewStep(preview),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _back,
                        child: Text(widget.isFr ? 'Retour' : 'Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _canNext() ? _next : null,
                      child: Text(_step == _maxStep
                          ? (widget.isFr ? 'Ajouter' : 'Add')
                          : (widget.isFr ? 'Suivant' : 'Next')),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isFr ? 'Choisir un modèle' : 'Choose a template',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...GrantComposerTemplate.values.map((t) {
          return Card(
            child: ListTile(
              leading: Icon(_templateIcon(t)),
              title: Text(_templateLabel(t)),
              trailing: _template == t
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => setState(() {
                _template = t;
                _selectedDst.clear();
                _selectedVia = null;
              }),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSourceStep() {
    final options = GrantComposerService.sourceTagOptions(
      users: widget.users,
      nodes: widget.nodes,
    );
    if (options.isEmpty) {
      return Text(widget.isFr
          ? 'Aucun tag client disponible. Taguer au moins un nœud -client.'
          : 'No client tags available. Tag at least one -client node.');
    }
    return _optionCheckList(
      widget.isFr ? 'Qui accède ? (source)' : 'Who accesses? (source)',
      options,
      _selectedSrc,
      single: _isExceptionAcl,
    );
  }

  Widget _buildViaStep() {
    final forExit = _template == GrantComposerTemplate.internetExit;
    final routers = GrantComposerService.routerOptions(
      nodes: widget.nodes,
      forExit: forExit,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isFr ? 'Par où router ? (via)' : 'Route through? (via)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (routers.isEmpty)
          Text(widget.isFr
              ? 'Aucun routeur tagué trouvé (lan-sharer ou exit-node).'
              : 'No tagged router found (lan-sharer or exit-node).')
        else
          ...routers.map((r) {
            final selected = _selectedVia == r.viaTag;
            return Card(
              child: ListTile(
                leading: Icon(
                  forExit ? Icons.public : Icons.router,
                  color: Colors.purple,
                ),
                title: Text(r.node.name),
                subtitle: Text('${r.roleLabel} • ${r.viaTag}'),
                trailing: selected
                    ? Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => setState(() => _selectedVia = r.viaTag),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildDestStep() {
    if (_template == GrantComposerTemplate.targetedIp && !_isExceptionAcl) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isFr ? 'IP destination' : 'Destination IP',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: '100.64.0.15',
              border: const OutlineInputBorder(),
              labelText: widget.isFr ? 'Adresse IP Tailscale' : 'Tailscale IP',
            ),
            onChanged: (v) => setState(() {
              _targetIp = v.trim();
              _selectedDst
                ..clear()
                ..add(_targetIp);
            }),
          ),
          const SizedBox(height: 16),
          Text(widget.isFr ? 'Ou choisir un nœud :' : 'Or pick a node:'),
          const SizedBox(height: 8),
          ...GrantComposerService.destinationOptions(
            nodes: widget.nodes,
            template: _template,
          ).map((o) => _destTile(o)),
        ],
      );
    }

    final options = _isExceptionAcl
        ? GrantComposerService.destinationOptions(
            nodes: widget.nodes,
            template: GrantComposerTemplate.targetedIp,
          )
        : GrantComposerService.destinationOptions(
            nodes: widget.nodes,
            template: _template,
            restrictToOwnerNorm: _template == GrantComposerTemplate.lanAccess
                ? _routerOwnerNorm()
                : null,
          );

    return _optionCheckList(
      widget.isFr ? 'Vers quoi ? (destination)' : 'Towards what? (destination)',
      options,
      _selectedDst,
      single: true,
    );
  }

  Widget _destTile(GrantComposerOption o) {
    final selected = _selectedDst.contains(o.value);
    return ListTile(
      title: Text(o.label),
      subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => setState(() {
        _selectedDst
          ..clear()
          ..add(o.value);
        _targetIp = o.value;
      }),
    );
  }

  Widget _optionCheckList(
    String title,
    List<GrantComposerOption> options,
    Set<String> selected, {
    bool single = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...options.map((o) {
          final isSelected = selected.contains(o.value);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) {
              setState(() {
                if (single) {
                  selected
                    ..clear()
                    ..add(o.value);
                } else {
                  isSelected ? selected.remove(o.value) : selected.add(o.value);
                }
              });
            },
            title: Text(o.label),
            subtitle: o.subtitle != null ? Text(o.subtitle!) : null,
          );
        }),
      ],
    );
  }

  Widget _buildPreviewStep(Map<String, dynamic>? preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isFr ? 'Aperçu' : 'Preview',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (preview == null)
          Text(widget.isFr
              ? 'Complétez les étapes précédentes.'
              : 'Complete previous steps.')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(preview),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }
}
