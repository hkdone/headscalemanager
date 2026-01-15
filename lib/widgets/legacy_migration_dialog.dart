import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/tag_migration_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';
import 'package:provider/provider.dart';

class LegacyMigrationDialog extends StatefulWidget {
  const LegacyMigrationDialog({super.key});

  @override
  State<LegacyMigrationDialog> createState() => _LegacyMigrationDialogState();
}

class _LegacyMigrationDialogState extends State<LegacyMigrationDialog> {
  int _currentStep = 0; // 0: VPN Warning, 1: Execution, 2: Finished
  final List<String> _logs = [];
  bool _isProcessing = false;
  String? _errorMessage;

  // I18n helper
  bool get _isFr => context.read<AppProvider>().locale.languageCode == 'fr';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent closing by back button
      child: AlertDialog(
        title: Text(_getTitle()),
        content: SizedBox(
          width: double.maxFinite,
          child: _buildStepContent(),
        ),
        actions: _buildActions(),
      ),
    );
  }

  String _getTitle() {
    if (_currentStep == 0) {
      return _isFr
          ? 'Configuration Non Conforme Détectée'
          : 'Non-Compliant Configuration Detected';
    } else if (_currentStep == 1) {
      return _isFr ? 'Migration en cours...' : 'Migration in progress...';
    } else {
      return _isFr ? 'Migration Terminée' : 'Migration Completed';
    }
  }

  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFr
                ? 'Des tags "fusionnés" (Legacy) ont été détectés. Cette configuration est obsolète et peut poser des problèmes de routage.'
                : 'Merged (Legacy) tags have been detected. This configuration is obsolete and may cause routing issues.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isFr ? 'ATTENTION REQUISE' : 'ATTENTION REQUIRED',
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isFr
                      ? 'Avant de continuer, vous DEVEZ désactiver votre VPN sur cet appareil pour éviter toute coupure de connexion pendant la mise à jour.'
                      : 'Before proceeding, you MUST disable your VPN on this device to avoid connection loss during the update.',
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            )
          ]
        ],
      );
    } else {
      // Step 1 & 2: Logs
      return Container(
        height: 300,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: ListView.builder(
          itemCount: _logs.length,
          itemBuilder: (context, index) {
            final log = _logs[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  if (index == _logs.length - 1 && _currentStep == 1)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.check, size: 12, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(log,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
  }

  List<Widget> _buildActions() {
    if (_currentStep == 0) {
      return [
        TextButton(
          onPressed: () {
            // Close dialog without migrating
            Navigator.of(context).pop();
          },
          child: Text(_isFr ? "Plus tard" : "Later"),
        ),
        TextButton(
          onPressed: _isProcessing ? null : _testConnectionAndStart,
          child: Text(_isFr
              ? "J'ai coupé mon VPN, Démarrer"
              : "I disabled my VPN, Start"),
        ),
      ];
    } else if (_currentStep == 1) {
      return []; // No actions while processing
    } else {
      return [
        ElevatedButton(
          onPressed: () {
            // Quit App - Force exit to ensure fresh state on reload
            exit(0);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(_isFr ? 'Fermer l\'application' : 'Close Application'),
        ),
      ];
    }
  }

  Future<void> _testConnectionAndStart() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final appProvider = context.read<AppProvider>();
    try {
      // 1. Simple connectivity test
      await appProvider.apiService.getUsers();

      if (!mounted) return;

      // Connection OK, proceed to migration
      setState(() {
        _currentStep = 1;
      });
      _runMigration();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = _isFr
            ? "Impossible de joindre le serveur. Vérifiez votre connexion internet (hors VPN)."
            : "Cannot reach server. Check your internet connection (outside VPN).";
      });
    }
  }

  Future<void> _runMigration() async {
    final appProvider = context.read<AppProvider>();
    final migrationService = TagMigrationService(appProvider.apiService);
    final standardAclGen = StandardAclGeneratorService();

    // Helper to add log
    void log(String fr, String en) {
      if (!mounted) return;
      setState(() {
        _logs.add(_isFr ? fr : en);
      });
    }

    try {
      // 1. Enable Standard Engine
      log("Activation du moteur Standard ACL...",
          "Enabling Standard ACL Engine...");
      await appProvider.setStandardAclEngineEnabled(true);
      await Future.delayed(const Duration(milliseconds: 500)); // Visual delay

      // 2. Migrate Tags
      log("Début de la migration des tags...", "Starting tag migration...");
      final nodes = await appProvider.apiService.getNodes(); // Fresh fetch

      for (var node in nodes) {
        log("Modification du nœud: ${node.name}...",
            "Modifying node: ${node.name}...");
        // Use migration service internal logic or call it?
        // TagMigrationService has batch method, but for UI feedback we might want granular...
        // But TagMigrationService.migrateToStandard handles all logic including verification.
        // Let's use the batch method for safety, and we can't easily log per-node inside it without callbacks.
        // For now, let's trust the batch.
      }

      // Actually, calling the batch method is safer.
      final result = await migrationService.migrateToStandard();
      log("Résultat migration tags: ${result.successCount} succès, ${result.failureCount} échecs.",
          "Tag migration result: ${result.successCount} success, ${result.failureCount} fail.");

      if (result.failureCount > 0) {
        throw Exception("Echec partiel de la migration des tags.");
      }

      // 3. Generate ACLs
      log("Génération de la nouvelle politique ACL...",
          "Generating new ACL policy...");

      // We need FRESH nodes after migration
      final freshNodes = await appProvider.apiService.getNodes();
      final users = await appProvider.apiService.getUsers();

      // Be sure to include stored temporary rules
      final serverId = appProvider.activeServer?.id;
      List<Map<String, dynamic>> tempRules = [];
      if (serverId != null) {
        tempRules =
            await appProvider.storageService.getTemporaryRules(serverId);
      }

      final policy = standardAclGen.generatePolicy(
          users: users, nodes: freshNodes, temporaryRules: tempRules);

      // 4. Push to Server
      log("Envoi de la configuration au serveur...",
          "Pushing configuration to server...");
      await appProvider.apiService.setAclPolicy(jsonEncode(policy));
      log("Configuration ACL appliquée avec succès.",
          "ACL configuration applied successfully.");

      // Finish
      if (!mounted) return;
      setState(() {
        _currentStep = 2;
        _logs.add(_isFr
            ? "Terminé. L'application doit maintenant se fermer pour rafraîchir ses données."
            : "Finished. Application must now close to refresh data.");
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentStep = 0; // Go back to start? Or stay in error state?
        _isProcessing = false;
        _errorMessage = "Erreur critique: $e";
      });
    }
  }
}
