import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/utils/grants_v29_gate.dart';
import 'package:provider/provider.dart';

/// Bandeau affiché après migration Grants V29 réussie ou auto-upgrade.
class GrantsMigrationBanner extends StatefulWidget {
  final bool isFr;
  final int grantCount;
  final bool hidden;

  const GrantsMigrationBanner({
    super.key,
    required this.isFr,
    this.grantCount = 0,
    this.hidden = false,
  });

  @override
  State<GrantsMigrationBanner> createState() => _GrantsMigrationBannerState();
}

class _GrantsMigrationBannerState extends State<GrantsMigrationBanner> {
  bool _visible = false;
  DateTime? _migrationDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final serverId = provider.activeServer?.id;
    if (serverId == null) return;

    if (!GrantsV29Gate.isAvailable(
      engineMode: provider.aclEngineMode,
      serverVersion: provider.serverVersion,
    )) {
      return;
    }

    final dismissed = await provider.storageService
        .isGrantsMigrationBannerDismissed(serverId);
    if (dismissed) return;

    final completed =
        await provider.storageService.isGrantsMigrationCompleted(serverId);
    final date = await provider.storageService.getGrantsMigrationDate(serverId);
    if (!completed && date == null) return;

    if (mounted) {
      setState(() {
        _visible = true;
        _migrationDate = date;
      });
    }
  }

  Future<void> _dismiss() async {
    final provider = context.read<AppProvider>();
    final serverId = provider.activeServer?.id;
    if (serverId != null) {
      await provider.storageService.setGrantsMigrationBannerDismissed(
          serverId, true);
    }
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hidden || !_visible) return const SizedBox.shrink();

    final dateStr = _migrationDate != null
        ? '${_migrationDate!.day.toString().padLeft(2, '0')}/'
            '${_migrationDate!.month.toString().padLeft(2, '0')}/'
            '${_migrationDate!.year}'
        : (widget.isFr ? 'récemment' : 'recently');

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      color: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isFr
                        ? 'Policy migrée en Grants V29 ($dateStr)'
                        : 'Policy migrated to Grants V29 ($dateStr)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _dismiss,
                  tooltip: widget.isFr ? 'Masquer' : 'Dismiss',
                ),
              ],
            ),
            if (widget.grantCount > 0)
              Text(
                widget.isFr
                    ? '${widget.grantCount} grant(s) réseau actif(s) avec routage via.'
                    : '${widget.grantCount} active network grant(s) with via routing.',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
