import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/failover_event.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'dart:convert';

/// Service de basculement automatique pour la haute disponibilité
class HaFailoverService {
  /// Détecte les nœuds LAN qui sont tombés en panne
  static List<FailedNodeInfo> detectFailedLanNodes(
      List<Node> previousNodes, List<Node> currentNodes) {
    final List<FailedNodeInfo> failedNodes = [];

    // Créer une map des nœuds actuels pour un accès rapide
    final currentNodesMap = <String, Node>{};
    for (var node in currentNodes) {
      currentNodesMap[node.id] = node;
    }

    // Vérifier chaque nœud précédent
    for (var previousNode in previousNodes) {
      final currentNode = currentNodesMap[previousNode.id];

      // Si le nœud était en ligne et est maintenant hors ligne
      if (previousNode.online && (currentNode == null || !currentNode.online)) {
        // Vérifier s'il avait des routes LAN partagées
        final lanRoutes = previousNode.sharedRoutes
            .where((route) => route != '0.0.0.0/0' && route != '::/0')
            .toList();

        if (lanRoutes.isNotEmpty) {
          failedNodes.add(FailedNodeInfo(
            node: previousNode,
            affectedRoutes: lanRoutes,
          ));
        }
      }
    }

    return failedNodes;
  }

  /// Trouve le prochain nœud disponible pour une route donnée
  static Node? getNextAvailableNode(
      String route, String user, List<Node> allNodes) {
    // Chercher les nœuds du même utilisateur qui ont cette route disponible
    final candidateNodes = allNodes
        .where((node) =>
            node.user == user &&
            node.online &&
            node.availableRoutes.contains(route) &&
            !node.sharedRoutes.contains(route))
        .toList();

    if (candidateNodes.isEmpty) {
      return null;
    }

    // Prioriser par ordre alphabétique du nom pour la cohérence
    candidateNodes.sort((a, b) => a.name.compareTo(b.name));

    return candidateNodes.first;
  }

  /// Affiche le dialogue de basculement avec détails
  static Future<bool> showFailoverDialog(
      BuildContext context,
      FailedNodeInfo failedInfo,
      Map<String, Node?> replacementNodes,
      bool isFr) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isFr ? 'Basculement HA Requis' : 'HA Failover Required',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isFr
                      ? 'Le nœud "${failedInfo.node.name}" est tombé en panne.'
                      : 'Node "${failedInfo.node.name}" has failed.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  isFr ? 'Routes affectées :' : 'Affected routes:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...failedInfo.affectedRoutes.map((route) {
                  final replacement = replacementNodes[route];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (replacement != null)
                                Text(
                                  isFr
                                      ? '→ Basculer vers "${replacement.name}"'
                                      : '→ Failover to "${replacement.name}"',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                  ),
                                )
                              else
                                Text(
                                  isFr
                                      ? '→ Aucun nœud de remplacement disponible'
                                      : '→ No replacement node available',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  isFr
                      ? 'Voulez-vous procéder au basculement automatique ?'
                      : 'Do you want to proceed with automatic failover?',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(isFr ? 'Annuler' : 'Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                  isFr ? 'Procéder au Basculement' : 'Proceed with Failover'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Sauvegarde un événement de basculement dans l'historique
  static Future<void> saveFailoverHistory(FailoverEvent event) async {
    try {
      final storageService = StorageService();

      // Récupérer l'historique existant
      final existingHistory = await getFailoverHistory();

      // Ajouter le nouvel événement
      existingHistory.add(event);

      // Garder seulement les 100 derniers événements
      if (existingHistory.length > 100) {
        existingHistory.removeRange(0, existingHistory.length - 100);
      }

      // Sauvegarder
      final historyJson = existingHistory.map((e) => e.toJson()).toList();
      await storageService.saveData(
          'failover_history', jsonEncode(historyJson));
    } catch (e) {
      // En cas d'erreur, ne pas bloquer le processus de basculement
      print('Erreur lors de la sauvegarde de l\'historique de basculement: $e');
    }
  }

  /// Récupère l'historique des basculements
  static Future<List<FailoverEvent>> getFailoverHistory() async {
    try {
      final storageService = StorageService();
      final historyData = await storageService.getData('failover_history');

      if (historyData == null) {
        return [];
      }

      final List<dynamic> historyJson = jsonDecode(historyData);
      return historyJson.map((json) => FailoverEvent.fromJson(json)).toList()
        ..sort((a, b) =>
            b.timestamp.compareTo(a.timestamp)); // Plus récent en premier
    } catch (e) {
      print(
          'Erreur lors de la récupération de l\'historique de basculement: $e');
      return [];
    }
  }

  /// Nettoie l'historique des basculements (garde les 30 derniers jours)
  static Future<void> cleanupFailoverHistory() async {
    try {
      final history = await getFailoverHistory();
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));

      final recentHistory = history
          .where((event) => event.timestamp.isAfter(cutoffDate))
          .toList();

      final storageService = StorageService();
      final historyJson = recentHistory.map((e) => e.toJson()).toList();
      await storageService.saveData(
          'failover_history', jsonEncode(historyJson));
    } catch (e) {
      print('Erreur lors du nettoyage de l\'historique de basculement: $e');
    }
  }

  /// Vérifie si un nœud a des routes en backup HA
  static bool hasHaBackupRoutes(Node node, List<Node> allNodes) {
    for (var route in node.availableRoutes) {
      // Ignorer les routes exit node
      if (route == '0.0.0.0/0' || route == '::/0') continue;

      // Vérifier si cette route est déjà active chez un autre nœud du même utilisateur
      final isActiveElsewhere = allNodes.any((otherNode) =>
          otherNode.id != node.id &&
          otherNode.user == node.user &&
          otherNode.online &&
          otherNode.sharedRoutes.contains(route));

      if (isActiveElsewhere) {
        return true;
      }
    }
    return false;
  }

  /// Obtient les statistiques de basculement pour un utilisateur
  static Future<Map<String, dynamic>> getFailoverStats(String user) async {
    final history = await getFailoverHistory();
    final userHistory = history.where((event) => event.user == user).toList();

    final last30Days = DateTime.now().subtract(const Duration(days: 30));
    final recentHistory = userHistory
        .where((event) => event.timestamp.isAfter(last30Days))
        .toList();

    // Compter les basculements par route
    final Map<String, int> routeFailovers = {};
    for (var event in recentHistory) {
      routeFailovers[event.route] = (routeFailovers[event.route] ?? 0) + 1;
    }

    return {
      'totalFailovers': userHistory.length,
      'recentFailovers': recentHistory.length,
      'routeFailovers': routeFailovers,
      'lastFailover':
          userHistory.isNotEmpty ? userHistory.first.timestamp : null,
    };
  }

  /// Exécute un basculement manuel d'une route HA.
  static Future<void> performManualFailover({
    required String route,
    required Node newPrimaryNode,
    required List<Node> allNodes,
    required AppProvider appProvider,
  }) async {
    final apiService = appProvider.apiService;
    List<Node> updatedNodes = List.from(allNodes);

    // 1. Trouver l'ancien nœud primaire pour cette route
    final oldPrimaryNode = RouteConflictService.getActiveNodeForRoute(
        route, newPrimaryNode.user, allNodes);

    // 2. Désactiver la route sur l'ancien nœud primaire (s'il existe et est différent)
    if (oldPrimaryNode != null && oldPrimaryNode.id != newPrimaryNode.id) {
      final oldPrimaryRoutes = List<String>.from(oldPrimaryNode.sharedRoutes)
        ..remove(route);
      await apiService.setNodeRoutes(oldPrimaryNode.id, oldPrimaryRoutes);

      // Mettre à jour l'état local
      final oldNodeIndex =
          updatedNodes.indexWhere((n) => n.id == oldPrimaryNode.id);
      if (oldNodeIndex != -1) {
        updatedNodes[oldNodeIndex] = Node(
            id: oldPrimaryNode.id,
            machineKey: oldPrimaryNode.machineKey,
            hostname: oldPrimaryNode.hostname,
            name: oldPrimaryNode.name,
            user: oldPrimaryNode.user,
            ipAddresses: oldPrimaryNode.ipAddresses,
            online: oldPrimaryNode.online,
            lastSeen: oldPrimaryNode.lastSeen,
            sharedRoutes: oldPrimaryRoutes, // Mis à jour
            availableRoutes: oldPrimaryNode.availableRoutes,
            isExitNode: oldPrimaryNode.isExitNode,
            isLanSharer:
                oldPrimaryRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
            tags: oldPrimaryNode.tags,
            baseDomain: oldPrimaryNode.baseDomain,
            endpoint: oldPrimaryNode.endpoint);
      }
    }

    // 3. Activer la route sur le nouveau nœud primaire
    final newPrimaryRoutes = List<String>.from(newPrimaryNode.sharedRoutes);
    if (!newPrimaryRoutes.contains(route)) {
      newPrimaryRoutes.add(route);
    }
    await apiService.setNodeRoutes(newPrimaryNode.id, newPrimaryRoutes);

    // Mettre à jour l'état local
    final newNodeIndex =
        updatedNodes.indexWhere((n) => n.id == newPrimaryNode.id);
    if (newNodeIndex != -1) {
      updatedNodes[newNodeIndex] = Node(
          id: newPrimaryNode.id,
          machineKey: newPrimaryNode.machineKey,
          hostname: newPrimaryNode.hostname,
          name: newPrimaryNode.name,
          user: newPrimaryNode.user,
          ipAddresses: newPrimaryNode.ipAddresses,
          online: newPrimaryNode.online,
          lastSeen: newPrimaryNode.lastSeen,
          sharedRoutes: newPrimaryRoutes, // Mis à jour
          availableRoutes: newPrimaryNode.availableRoutes,
          isExitNode: newPrimaryNode.isExitNode,
          isLanSharer:
              newPrimaryRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
          tags: newPrimaryNode.tags,
          baseDomain: newPrimaryNode.baseDomain,
          endpoint: newPrimaryNode.endpoint);
    }

    // 4. Désactiver la route sur tous les autres nœuds du groupe (au cas où)
    final otherBackupNodes = allNodes.where((n) =>
        n.user == newPrimaryNode.user &&
        n.id != newPrimaryNode.id &&
        n.id != (oldPrimaryNode?.id ?? ''));

    for (var node in otherBackupNodes) {
      if (node.sharedRoutes.contains(route)) {
        final backupRoutes = List<String>.from(node.sharedRoutes)
          ..remove(route);
        await apiService.setNodeRoutes(node.id, backupRoutes);

        // Mettre à jour l'état local
        final backupNodeIndex =
            updatedNodes.indexWhere((n) => n.id == node.id);
        if (backupNodeIndex != -1) {
          updatedNodes[backupNodeIndex] = Node(
              id: node.id,
              machineKey: node.machineKey,
              hostname: node.hostname,
              name: node.name,
              user: node.user,
              ipAddresses: node.ipAddresses,
              online: node.online,
              lastSeen: node.lastSeen,
              sharedRoutes: backupRoutes, // Mis à jour
              availableRoutes: node.availableRoutes,
              isExitNode: node.isExitNode,
              isLanSharer:
                  backupRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
              tags: node.tags,
              baseDomain: node.baseDomain,
              endpoint: node.endpoint);
        }
      }
    }

    // 5. Régénérer et appliquer les ACLs avec l'état local mis à jour
    final allUsers = await apiService.getUsers();
    final tempRules = await appProvider.storageService.getTemporaryRules();

    final aclGenerator = NewAclGeneratorService();
    final newPolicyMap = aclGenerator.generatePolicy(
        users: allUsers, nodes: updatedNodes, temporaryRules: tempRules);
    final newPolicyJson = jsonEncode(newPolicyMap);
    await apiService.setAclPolicy(newPolicyJson);
  }
}
