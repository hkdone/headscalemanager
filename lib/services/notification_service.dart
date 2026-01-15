import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const String backgroundTaskName = "headscaleManager.checkNodeStatus";
const String taskUniqueName = "checkNodeStatusTask";

const String languageKey = 'APP_LANGUAGE';

// Helper function to get translations
Map<String, String> _getTranslations(String lang, String nodeName,
    {bool? isOnline}) {
  final onlineStatus = isOnline ?? false;
  if (lang == 'en') {
    return {
      'approval_title': 'Approval Required',
      'approval_body': 'Node "$nodeName" is requesting new permissions.',
      'cleanup_title': 'Route Deletion Warning',
      'cleanup_body':
          'Node "$nodeName" has orphaned routes that need to be deleted.',
      'status_title': 'Status Change',
      'status_body':
          'Node "$nodeName" is now ${onlineStatus ? 'online' : 'offline'}.',
    };
  }
  // Default to French
  return {
    'approval_title': 'Approbation Requise',
    'approval_body': 'Le nœud "$nodeName" demande de nouvelles permissions.',
    'cleanup_title': 'Avertissement de Suppression',
    'cleanup_body': 'Le nœud "$nodeName" a des routes orphelines à supprimer.',
    'status_title': 'Changement de Statut',
    'status_body':
        'Le nœud "$nodeName" est maintenant ${onlineStatus ? 'en ligne' : 'hors ligne'}.',
  };
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == backgroundTaskName) {
      // print("Background task started: Checking node statuses...");
      await NotificationService.showPersistentNotification(
        'Vérification en cours',
        'Analyse des changements réseau...',
      );
      try {
        final storageService = StorageService();
        await storageService.init(); // Important for migration

        final servers = await storageService.getServers();
        final activeServerId = await storageService.getActiveServerId();

        if (servers.isEmpty || activeServerId == null) {
          // print("No active server configured. Exiting background task.");
          return Future.value(true);
        }

        final activeServer = servers.firstWhere((s) => s.id == activeServerId);

        final apiService = HeadscaleApiService(
          apiKey: activeServer.apiKey,
          baseUrl: activeServer.url,
        );
        final List<Node> nodes = await apiService.getNodes();
        final prefs = await SharedPreferences.getInstance();

        final lang = prefs.getString(languageKey) ?? 'fr';

        // --- Logic for Approval/Cleanup notifications ---
        final approvalNotifiedIds =
            prefs.getStringList('approvalNotifiedIds') ?? [];
        final cleanupNotifiedIds =
            prefs.getStringList('cleanupNotifiedIds') ?? [];
        List<String> newApprovalIds = [];
        List<String> newCleanupIds = [];

        // --- Logic for Status Monitoring notifications ---
        final monitoredNodeIds = prefs.getStringList('monitoredNodeIds') ?? [];

        for (final node in nodes) {
          final translations =
              _getTranslations(lang, node.name, isOnline: node.online);

          // 1. Check for pending approvals
          final hasPendingApproval =
              node.availableRoutes.any((r) => !node.sharedRoutes.contains(r));
          if (hasPendingApproval) {
            newApprovalIds.add(node.id);
            if (!approvalNotifiedIds.contains(node.id)) {
              // print("Found new pending node: ${node.name}");
              await NotificationService.showNotification(
                translations['approval_title']!,
                translations['approval_body']!,
              );
            }
          }

          // 2. Check for desynchronization (cleanup needed)
          final hasDesync =
              node.sharedRoutes.any((r) => !node.availableRoutes.contains(r));
          if (hasDesync) {
            newCleanupIds.add(node.id);
            if (!cleanupNotifiedIds.contains(node.id)) {
              // print("Found desynchronized node: ${node.name}");
              await NotificationService.showNotification(
                translations['cleanup_title']!,
                translations['cleanup_body']!,
              );
            }
          }

          // 3. Check for status change on monitored nodes
          if (monitoredNodeIds.contains(node.id)) {
            final lastKnownStatusKey = 'monitoredNode_${node.id}_status';
            final lastKnownStatus = prefs.getBool(lastKnownStatusKey);

            if (lastKnownStatus != null && node.online != lastKnownStatus) {
              // print("Status change for ${node.name}: now ${node.online ? 'online' : 'offline'}");
              await NotificationService.showNotification(
                translations['status_title']!,
                translations['status_body']!,
              );
              // Update the status to prevent re-notifying
              await prefs.setBool(lastKnownStatusKey, node.online);
            }
          }
        }

        // Save the new state lists back to storage
        await prefs.setStringList('approvalNotifiedIds', newApprovalIds);
        await prefs.setStringList('cleanupNotifiedIds', newCleanupIds);
        // print("Background task finished.");
      } catch (e) {
        // print("Error in background task: $e");
        return Future.value(false);
      } finally {
        await NotificationService.hidePersistentNotification();
      }
    }
    return Future.value(true);
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _persistentNotificationId = 0;
  static const String _foregroundChannelId = 'headscale_foreground_channel';

  static Future<void> initialize() async {
    // Create a separate channel for the foreground service
    const AndroidNotificationChannel foregroundChannel =
        AndroidNotificationChannel(
      _foregroundChannelId,
      'Tâches de fond', // title
      description:
          'Notifications pour les tâches de fond actives.', // description
      importance: Importance.low, // Use low importance to be less intrusive
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(foregroundChannel);
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);

    // Request notification permissions on Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    await Workmanager().initialize(
      callbackDispatcher,
      // isInDebugMode: true, // Removed deprecated parameter
    );
  }

  static Future<void> enableBackgroundTask(bool enabled) async {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        taskUniqueName,
        backgroundTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      // print("Background task enabled and registered.");
    } else {
      await Workmanager().cancelByUniqueName(taskUniqueName);
      // print("Background task cancelled.");
    }
  }

  static Future<void> showNotification(String title, String body) async {
    final int id = title.hashCode + body.hashCode;
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'headscale_manager_channel',
      'Mises à jour Headscale',
      channelDescription: 'Notifications sur l\'état du réseau Headscale.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> showPersistentNotification(
      String title, String body) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _foregroundChannelId,
      'Tâches de fond',
      channelDescription: 'Notification persistante pour les tâches de fond.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      _persistentNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  static Future<void> hidePersistentNotification() async {
    await _notificationsPlugin.cancel(_persistentNotificationId);
  }
}
