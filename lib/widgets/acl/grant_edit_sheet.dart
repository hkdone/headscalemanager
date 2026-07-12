import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';

/// Édition inline d'un grant réseau existant.
class GrantEditSheet extends StatefulWidget {
  final Map<String, dynamic> grant;
  final List<User> users;
  final List<Node> nodes;
  final bool isFr;

  const GrantEditSheet({
    super.key,
    required this.grant,
    required this.users,
    required this.nodes,
    required this.isFr,
  });

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> grant,
    required List<User> users,
    required List<Node> nodes,
    required bool isFr,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GrantEditSheet(
        grant: grant,
        users: users,
        nodes: nodes,
        isFr: isFr,
      ),
    );
  }

  @override
  State<GrantEditSheet> createState() => _GrantEditSheetState();
}

class _GrantEditSheetState extends State<GrantEditSheet> {
  late final Set<String> _src;
  late final Set<String> _dst;
  String? _via;

  @override
  void initState() {
    super.initState();
    _src = (widget.grant['src'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    _dst = (widget.grant['dst'] as List?)?.map((e) => e.toString()).toSet() ?? {};
    final viaList = widget.grant['via'] as List?;
    _via = viaList != null && viaList.isNotEmpty ? viaList.first.toString() : null;
  }

  Map<String, dynamic> _buildGrant() {
    return GrantComposerService.buildNetworkGrant(
      src: _src.toList()..sort(),
      dst: _dst.toList()..sort(),
      via: _via != null ? [_via!] : const [],
      ip: (widget.grant['ip'] as List?)?.map((e) => e.toString()).toList() ??
          const ['*'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final srcOptions = GrantComposerService.sourceTagOptions(
      users: widget.users,
      nodes: widget.nodes,
    );
    final routers = [
      ...GrantComposerService.routerOptions(nodes: widget.nodes, forExit: false),
      ...GrantComposerService.routerOptions(nodes: widget.nodes, forExit: true),
    ];
    final dstOptions = GrantComposerService.destinationOptions(
      nodes: widget.nodes,
      template: GrantComposerTemplate.lanAccess,
    )
      ..addAll(GrantComposerService.destinationOptions(
        nodes: widget.nodes,
        template: GrantComposerTemplate.internetExit,
      ))
      ..addAll(GrantComposerService.destinationOptions(
        nodes: widget.nodes,
        template: GrantComposerTemplate.intraFleet,
      ));

    final uniqueDst = <String, GrantComposerOption>{};
    for (var o in dstOptions) {
      uniqueDst[o.value] = o;
    }
    for (var d in _dst) {
      uniqueDst.putIfAbsent(
        d,
        () => GrantComposerOption(value: d, label: d),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.isFr ? 'Modifier le grant' : 'Edit grant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(widget.isFr ? 'Source(s)' : 'Source(s)',
                      style: Theme.of(context).textTheme.titleSmall),
                  ...srcOptions.map((o) => CheckboxListTile(
                        value: _src.contains(o.value),
                        onChanged: (_) => setState(() {
                          _src.contains(o.value)
                              ? _src.remove(o.value)
                              : _src.add(o.value);
                        }),
                        title: Text(o.label),
                      )),
                  const Divider(),
                  Text(widget.isFr ? 'Via (routeur)' : 'Via (router)',
                      style: Theme.of(context).textTheme.titleSmall),
                  RadioGroup<String?>(
                    groupValue: _via,
                    onChanged: (v) => setState(() => _via = v),
                    child: Column(
                      children: [
                        RadioListTile<String?>(
                          value: null,
                          title: Text(widget.isFr
                              ? 'Aucun (direct)'
                              : 'None (direct)'),
                        ),
                        ...routers.map((r) => RadioListTile<String?>(
                              value: r.viaTag,
                              title: Text('${r.node.name} (${r.viaTag})'),
                            )),
                      ],
                    ),
                  ),
                  const Divider(),
                  Text(widget.isFr ? 'Destination(s)' : 'Destination(s)',
                      style: Theme.of(context).textTheme.titleSmall),
                  ...uniqueDst.values.map((o) => CheckboxListTile(
                        value: _dst.contains(o.value),
                        onChanged: (_) => setState(() {
                          _dst.contains(o.value)
                              ? _dst.remove(o.value)
                              : _dst.add(o.value);
                        }),
                        title: Text(o.label),
                      )),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(_buildGrant()),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.isFr ? 'Annuler' : 'Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _src.isNotEmpty && _dst.isNotEmpty
                        ? () => Navigator.pop(context, _buildGrant())
                        : null,
                    child: Text(widget.isFr ? 'Enregistrer' : 'Save'),
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
