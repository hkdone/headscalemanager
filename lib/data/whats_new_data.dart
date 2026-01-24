class WhatsNewVersion {
  final String version;
  final String title;
  final String description;
  final String verification;

  const WhatsNewVersion({
    required this.version,
    required this.title,
    required this.description,
    required this.verification,
  });

  static List<WhatsNewVersion> getVersions(bool isFr) {
    return [
      WhatsNewVersion(
        version: '1.4.96',
        title: isFr
            ? 'Historique des Versions & Nettoyage'
            : 'Version History & Cleanup',
        description: isFr
            ? 'Ajout de cet écran "Nouveautés" pour suivre les évolutions de l\'application. Nettoyage du code et suppression des fichiers de tests obsolètes pour une meilleure stabilité.'
            : 'Added this "What\'s New" screen to track application changes. Code cleanup and removal of obsolete test files for better stability.',
        verification: isFr
            ? 'Vous consultez actuellement cet écran !'
            : 'You are currently viewing this screen!',
      ),
      WhatsNewVersion(
        version: '1.4.95',
        title: isFr ? 'Transition vers v0.28' : 'Transition to v0.28',
        description: isFr
            ? 'Support des changements de l\'API Headscale v0.28. La génération de clés utilise désormais le nouveau système basé sur des ID. La fonctionnalité "Déplacer un nœud" a été supprimée car elle n\'est plus supportée par Headscale.'
            : 'Support for the new Headscale v0.28 API changes. Key generation now uses the new ID-based system. The "Move Node" feature has been removed as it is no longer supported by Headscale.',
        verification: isFr
            ? 'Les nouvelles clés API s\'afficheront avec le préfixe confidentiel "hskey-auth-".'
            : 'New API keys will show with the confidential prefix "hskey-auth-".',
      ),
      WhatsNewVersion(
        version: '1.4.94',
        title: isFr
            ? 'Transition vers v0.27 (Validation)'
            : 'Transition to v0.27 (Validation)',
        description: isFr
            ? 'Implémentation d\'ajustements stricts des noms pour respecter la RFC 1123. Le générateur ACL a été mis à jour pour garantir que toutes les règles ont des ports explicites.'
            : 'Implementation of strict name adjustments to comply with RFC 1123. The ACL generator has been updated to ensure all rules have explicit ports.',
        verification: isFr
            ? 'Les nœuds avec des noms invalides (ex: underscores) afficheront une icône d\'avertissement.'
            : 'Nodes with invalid names (e.g., underscores) will display a warning icon.',
      ),
      WhatsNewVersion(
        version: '1.4.93',
        title: isFr
            ? 'Transition vers v0.26 (Tags)'
            : 'Transition to v0.26 (Tags)',
        description: isFr
            ? 'Préparation aux changements d\'isolation des tags. Sécurité accrue lors de la création d\'utilisateurs pour éviter les doublons de tags causant des conflits ACL.'
            : 'Preparation for tag isolation changes. Enhanced user creation safety to prevent duplicate tags which could cause ACL conflicts.',
        verification: isFr
            ? 'Essayez de créer un utilisateur avec un nom en conflit (ex: "Alice" vs "alice").'
            : 'Try creating a user with a name that conflicts with an existing one (e.g., "Alice" vs "alice").',
      ),
      WhatsNewVersion(
        version: '1.4.92',
        title:
            isFr ? 'Détection de Version Serveur' : 'Server Version Detection',
        description: isFr
            ? 'Ajout de la détection automatique de la version du serveur Headscale. Cela permet à l\'application d\'adapter son comportement ("Support Hybride") entre les serveurs v0.25 et v0.28.'
            : 'Added automatic detection of the Headscale server version. This allows the app to adapt its behavior ("Hybrid Support") between v0.25 and v0.28 servers.',
        verification: isFr
            ? 'La version du serveur est désormais affichée dans les écrans Paramètres et Liste des Serveurs.'
            : 'The server version is now displayed in the Settings and Server List screens.',
      ),
    ];
  }
}
