import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/alignment_diagnostic_service.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/widgets/acl/policy_diff_dialog.dart';
import 'package:provider/provider.dart';

/// Dialogue interactif de diagnostic et d'alignement ACL + nœuds (Sous-Plan 09-0).
///
/// Inspecte en lecture seule les comptes, nœuds et la politique serveur, puis
/// propose des corrections assistées avec aperçu Diff ligne-par-ligne avant tout
/// envoi vers Headscale.
class AlignmentAssistantDialog extends StatefulWidget {
  final bool isPreflight;
  final AclEngineMode? targetEngineMode;

  const AlignmentAssistantDialog({
    super.key,
    this.isPreflight = false,
    this.targetEngineMode,
  });

  /// Ouvre le diagnostic et retourne `true` si des modifications ont été
  /// appliquées sur le serveur (ou si l'utilisateur confirme en pre-flight).
  static Future<bool> show(
    BuildContext context, {
    bool isPreflight = false,
    AclEngineMode? targetEngineMode,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlignmentAssistantDialog(
        isPreflight: isPreflight,
        targetEngineMode: targetEngineMode,
      ),
    );
    return result ?? false;
  }

  @override
  State<AlignmentAssistantDialog> createState() =>
      _AlignmentAssistantDialogState();
}

class _AlignmentAssistantDialogState extends State<AlignmentAssistantDialog> {
  bool _loading = true;
  bool _applying = false;
  String? _loadError;
  bool _appliedAnyFix = false;

  List<User> _users = [];
  List<Node> _nodes = [];
  Map<String, dynamic>? _serverPolicy;
  String _rawPolicyText = '';
  Map<String, String> _ruleComments = {};
  String? _leadingComments;
  AlignmentReport? _report;

  @override
  void initState() {
    super.initState();
    _runInspection();
  }

  Future<void> _runInspection() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final api = provider.apiService;

      final results = await Future.wait([
        api.getUsers(),
        api.getNodes(),
      ]);
      final users = results[0] as List<User>;
      final nodes = results[1] as List<Node>;

      final bundle = await PolicyPreserver.fetchServerPolicyBundleSafely(api);
      final serverId = provider.activeServer?.id;
      final tempRules = serverId != null
          ? await provider.storageService.getTemporaryRules(serverId)
          : const <Map<String, dynamic>>[];

      final report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodes,
        serverPolicy: bundle.policy,
        serverVersion: provider.serverVersion,
        engineMode: widget.targetEngineMode ?? provider.aclEngineMode,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
      );

      if (!mounted) return;
      setState(() {
        _users = users;
        _nodes = nodes;
        _serverPolicy = bundle.policy;
        _rawPolicyText = bundle.rawText;
        _ruleComments = Map<String, String>.from(bundle.ruleComments);
        _leadingComments = bundle.leadingComments;
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _applyPolicyFix({required bool isFr}) async {
    final report = _report;
    final aligned = report?.alignedPolicy;
    if (report == null || aligned == null) return false;

    final hasComments = _ruleComments.isNotEmpty ||
        (_leadingComments != null && _leadingComments!.trim().isNotEmpty);

    // Migrer aussi les signatures des commentaires HuJSON dont la règle a été réécrite en cascade
    final migratedComments = Map<String, String>.from(_ruleComments);
    final removedCommentSigs = <String>{};
    report.migratedRuleCommentKeys.forEach((oldSig, newSig) {
      final comment = migratedComments.remove(oldSig);
      if (comment != null && comment.trim().isNotEmpty) {
        removedCommentSigs.add(oldSig);
        migratedComments[newSig] = comment;
      }
    });

    final previewNewText = hasComments
        ? HuJsonCommentService.formatPolicyWithComments(
            aligned,
            ruleComments: migratedComments,
            leadingComments: _leadingComments,
          )
        : const JsonEncoder.withIndent('  ').convert(aligned);

    final confirmed = await PolicyDiffDialog.show(
          context,
          currentPolicy: _serverPolicy ?? const {},
          newPolicy: aligned,
          rawCurrentText: _rawPolicyText,
          rawNewText: previewNewText,
          isFr: isFr,
        ) ??
        false;
    if (!confirmed || !mounted) return false;

    setState(() => _applying = true);
    try {
      final provider = context.read<AppProvider>();
      await PolicyPreserver.applyPreservingPolicy(
        apiService: provider.apiService,
        generatedPolicy: aligned,
        serverPolicy: _serverPolicy,
        rawServerPolicy: _rawPolicyText.isNotEmpty ? _rawPolicyText : null,
        overrideRuleComments: migratedComments,
        removedCommentSignatures: removedCommentSigs,
        pretty: true,
        preserveCustomRules: false,
      );
      final serverId = provider.activeServer?.id;
      if (serverId != null && report.alignedTemporaryRules != null) {
        await provider.storageService
            .saveTemporaryRules(serverId, report.alignedTemporaryRules!);
      }
      if (report.alignedTaildriveShares != null) {
        await provider
            .replaceTaildriveShares(report.alignedTaildriveShares!);
      }
      _appliedAnyFix = true;
      if (mounted) {
        showSafeSnackBar(
          context,
          isFr
              ? 'Politique ACL alignée et appliquée au serveur.'
              : 'ACL policy aligned and pushed to server.',
        );
      }
      await _runInspection();
      return true;
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(
          context,
          isFr
              ? 'Erreur lors de la mise à jour ACL : $e'
              : 'Failed to update ACL policy: $e',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _applyNodeFixes({required bool isFr}) async {
    final report = _report;
    if (report == null || !report.hasNodeFixes) return;
    final actions = report.allNodeActions;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              isFr
                  ? 'Appliquer ${actions.length} correctif(s) sur les nœuds ?'
                  : 'Apply ${actions.length} node fix(es)?',
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isFr
                          ? 'Les opérations suivantes seront exécutées sur le serveur Headscale :'
                          : 'The following operations will be executed on the Headscale server:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    ...actions.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${isFr ? a.summaryFr : a.summaryEn}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (report.hasPolicyFix &&
                        actions.any((a) => a.newTags != null)) ...[
                      const SizedBox(height: 10),
                      Text(
                        isFr
                            ? 'Note : la politique ACL (tagOwners) sera d\'abord mise à jour pour autoriser les nouveaux tags.'
                            : 'Note: ACL policy (tagOwners) will be updated first to authorize converted tags.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isFr ? 'Annuler' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isFr ? 'Confirmer' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    // Si des tags changent et que la policy doit d'abord déclarer tagOwners,
    // pousser l'alignement ACL avant setTags (règle 0.29/0.30 tags_not_permitted).
    if (report.hasPolicyFix && actions.any((a) => a.newTags != null)) {
      final policyApplied = await _applyPolicyFix(isFr: isFr);
      if (!policyApplied || !mounted) return;
    }

    setState(() => _applying = true);
    final provider = context.read<AppProvider>();
    final errors = <String>[];
    int appliedCount = 0;

    try {
      for (final action in actions) {
        try {
          if (action.newTags != null) {
            await provider.apiService.setTags(action.nodeId, action.newTags!);
            appliedCount++;
          }
          if (action.newNodeName != null) {
            await provider.apiService
                .renameNode(action.nodeId, action.newNodeName!);
            appliedCount++;
          }
        } catch (e) {
          errors.add('${action.nodeName}: $e');
        }
      }

      if (appliedCount > 0) {
        _appliedAnyFix = true;
      }

      if (mounted) {
        if (errors.isEmpty) {
          showSafeSnackBar(
            context,
            isFr
                ? '$appliedCount correctif(s) appliqué(s) avec succès.'
                : '$appliedCount node fix(es) applied successfully.',
          );
        } else {
          showSafeSnackBar(
            context,
            isFr
                ? '$appliedCount réussi(s), ${errors.length} erreur(s) : ${errors.first}'
                : '$appliedCount succeeded, ${errors.length} error(s): ${errors.first}',
          );
        }
      }
      await _runInspection();
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Color _severityColor(AlignmentIssueSeverity severity) {
    switch (severity) {
      case AlignmentIssueSeverity.critical:
        return Colors.red;
      case AlignmentIssueSeverity.warning:
        return Colors.orange;
      case AlignmentIssueSeverity.info:
        return Colors.blue;
    }
  }

  IconData _severityIcon(AlignmentIssueSeverity severity) {
    switch (severity) {
      case AlignmentIssueSeverity.critical:
        return Icons.error_outline;
      case AlignmentIssueSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlignmentIssueSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';
    final report = _report;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isFr
                  ? 'Diagnostic & Alignement ACL'
                  : 'ACL Alignment Diagnostic',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isFr ? 'Relancer l\'analyse' : 'Re-run check',
            onPressed: (_loading || _applying) ? null : _runInspection,
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
                ? SingleChildScrollView(
                    child: Text(
                      isFr
                          ? 'Impossible d\'analyser le serveur : $_loadError'
                          : 'Unable to inspect server: $_loadError',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (VersionInfo.isServerDeprecated(
                            provider.serverVersion)) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Text(
                              isFr
                                  ? 'Version serveur détectée : ${provider.serverVersion}. Pensez à mettre à jour vers Headscale 0.28 / 0.29.'
                                  : 'Detected server version: ${provider.serverVersion}. Consider upgrading to Headscale 0.28 / 0.29.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        if (report != null && report.isClean) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isFr
                                        ? 'Configuration saine : aucun désalignement détecté sur ${_users.length} utilisateur(s) et ${_nodes.length} nœud(s).'
                                        : 'Healthy configuration: no misalignment detected across ${_users.length} user(s) and ${_nodes.length} node(s).',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (report != null) ...[
                          Text(
                            isFr
                                ? '${report.issues.length} point(s) d\'attention détecté(s) sur ${_users.length} utilisateur(s) et ${_nodes.length} nœud(s) :'
                                : '${report.issues.length} item(s) detected across ${_users.length} user(s) and ${_nodes.length} node(s):',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          ...report.issues.map((issue) {
                            final color = _severityColor(issue.severity);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: color.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _severityIcon(issue.severity),
                                          color: color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isFr
                                                ? issue.titleFr
                                                : issue.titleEn,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isFr
                                          ? issue.descriptionFr
                                          : issue.descriptionEn,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (issue.affectedItems.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: issue.affectedItems
                                            .take(8)
                                            .map(
                                              (item) => Chip(
                                                label: Text(
                                                  item,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
      ),
      actions: [
        if (widget.isPreflight)
          TextButton(
            onPressed: _applying ? null : () => Navigator.of(context).pop(false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
        TextButton(
          onPressed: _applying
              ? null
              : () => Navigator.of(context).pop(
                    widget.isPreflight ? true : _appliedAnyFix,
                  ),
          child: Text(
            widget.isPreflight
                ? ((report != null && report.isClean)
                    ? (isFr ? 'Continuer' : 'Continue')
                    : (isFr ? 'Continuer quand même' : 'Continue anyway'))
                : (isFr ? 'Fermer' : 'Close'),
          ),
        ),
        if (report != null && report.hasNodeFixes)
          OutlinedButton.icon(
            onPressed:
                (_loading || _applying) ? null : () => _applyNodeFixes(isFr: isFr),
            icon: const Icon(Icons.devices, size: 18),
            label: Text(
              isFr
                  ? 'Corriger nœuds (${report.allNodeActions.length})'
                  : 'Fix nodes (${report.allNodeActions.length})',
            ),
          ),
        if (report != null && report.hasLocalConfigFixes && !report.hasPolicyFix)
          FilledButton.icon(
            onPressed: (_loading || _applying)
                ? null
                : () async {
                    setState(() => _applying = true);
                    try {
                      final provider = context.read<AppProvider>();
                      final serverId = provider.activeServer?.id;
                      if (serverId != null &&
                          report.alignedTemporaryRules != null) {
                        await provider.storageService.saveTemporaryRules(
                          serverId,
                          report.alignedTemporaryRules!,
                        );
                      }
                      if (report.alignedTaildriveShares != null) {
                        await provider.replaceTaildriveShares(
                          report.alignedTaildriveShares!,
                        );
                      }
                      _appliedAnyFix = true;
                      if (context.mounted) {
                        showSafeSnackBar(
                          context,
                          isFr
                              ? 'Règles locales et partages Taildrive alignés.'
                              : 'Local rules and Taildrive shares aligned.',
                        );
                      }
                      await _runInspection();
                    } finally {
                      if (mounted) setState(() => _applying = false);
                    }
                  },
            icon: const Icon(Icons.sync_alt, size: 18),
            label: Text(
              isFr ? 'Aligner règles locales' : 'Align local rules',
            ),
          ),
        if (report != null && report.hasPolicyFix)
          FilledButton.icon(
            onPressed:
                (_loading || _applying) ? null : () => _applyPolicyFix(isFr: isFr),
            icon: const Icon(Icons.difference, size: 18),
            label: Text(
              isFr ? 'Corriger ACL (Diff)' : 'Fix ACL (Diff)',
            ),
          ),
      ],
    );
  }
}
