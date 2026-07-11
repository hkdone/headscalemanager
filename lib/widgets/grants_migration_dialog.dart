import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:provider/provider.dart';

class GrantsMigrationDialog extends StatefulWidget {
  const GrantsMigrationDialog({super.key});

  @override
  State<GrantsMigrationDialog> createState() => _GrantsMigrationDialogState();
}

class _GrantsMigrationDialogState extends State<GrantsMigrationDialog> {
  int _step = 0;
  final List<String> _logs = [];
  bool _processing = false;
  String? _error;

  bool get _isFr => context.read<AppProvider>().locale.languageCode == 'fr';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_title()),
        content: SizedBox(
          width: double.maxFinite,
          child: _step == 0 ? _buildIntro() : _buildLogs(),
        ),
        actions: _actions(),
      ),
    );
  }

  String _title() {
    if (_step == 0) {
      return _isFr ? 'Migration Grants V29' : 'Grants V29 Migration';
    }
    if (_step == 1) {
      return _isFr ? 'Migration en cours…' : 'Migration in progress…';
    }
    return _isFr ? 'Migration terminée' : 'Migration completed';
  }

  Widget _buildIntro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isFr
              ? 'Votre serveur Headscale ≥ 0.29 supporte les grants avec routage via. Cette migration bascule le moteur ACL vers Grants V29 et régénère la politique.'
              : 'Your Headscale server ≥ 0.29 supports grants with via routing. This migration switches the ACL engine to Grants V29 and regenerates the policy.',
        ),
        const SizedBox(height: 12),
        Text(
          _isFr
              ? 'Recommandé si plusieurs utilisateurs partagent le même sous-réseau LAN (ex. 192.168.1.0/24).'
              : 'Recommended when multiple users share the same LAN subnet (e.g. 192.168.1.0/24).',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildLogs() {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (_, i) => Text(_logs[i],
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ),
    );
  }

  List<Widget> _actions() {
    if (_step == 0) {
      return [
        TextButton(
          onPressed: _processing ? null : _dismissLater,
          child: Text(_isFr ? 'Plus tard' : 'Later'),
        ),
        TextButton(
          onPressed: _processing ? null : _startMigration,
          child: Text(_isFr ? 'Démarrer' : 'Start'),
        ),
      ];
    }
    if (_step == 1) return [];
    return [
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(_isFr ? 'OK' : 'OK'),
      ),
    ];
  }

  Future<void> _dismissLater() async {
    final provider = context.read<AppProvider>();
    final serverId = provider.activeServer?.id;
    if (serverId != null) {
      await provider.storageService.setGrantsMigrationDismissed(serverId, true);
    }
    if (mounted) Navigator.of(context).pop(false);
  }

  void _log(String msg) {
    setState(() => _logs.add(msg));
  }

  Future<void> _startMigration() async {
    setState(() {
      _processing = true;
      _error = null;
      _step = 1;
    });

    final provider = context.read<AppProvider>();
    final serverId = provider.activeServer?.id;
    if (serverId == null) {
      setState(() {
        _error = _isFr ? 'Aucun serveur actif.' : 'No active server.';
        _step = 0;
        _processing = false;
      });
      return;
    }

    try {
      _log(_isFr ? 'Activation moteur Grants V29…' : 'Enabling Grants V29 engine…');
      await provider.setAclEngineMode(AclEngineMode.grantsV29);

      _log(_isFr ? 'Récupération utilisateurs et nœuds…' : 'Fetching users and nodes…');
      final users = await provider.apiService.getUsers();
      final nodes = await provider.apiService.getNodes();
      final tempRules =
          await provider.storageService.getTemporaryRules(serverId);

      _log(_isFr ? 'Génération politique grants…' : 'Generating grants policy…');
      final orchestrator = AclPolicyOrchestrator();
      final policy = orchestrator.generatePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: users,
        nodes: nodes,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
        serverVersion: provider.serverVersion,
      );

      _log(_isFr ? 'Envoi vers le serveur…' : 'Pushing to server…');
      final jsonPolicy =
          const JsonEncoder.withIndent('  ').convert(policy);
      await provider.apiService.setAclPolicy(jsonPolicy);

      await provider.storageService.setGrantsMigrationCompleted(serverId, true);
      await provider.storageService.setGrantsMigrationDismissed(serverId, false);

      _log(_isFr ? 'Migration réussie !' : 'Migration successful!');
      if (mounted) setState(() => _step = 2);
    } catch (e) {
      _log('ERROR: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _step = 0;
        });
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
