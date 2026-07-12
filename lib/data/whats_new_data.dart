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
        version: '2.1.3',
        title: isFr
            ? 'Release 2.1.3 — Puzzle & persistance'
            : 'Release 2.1.3 — Puzzle & persistence',
        description: isFr
            ? 'Correction de la sauvegarde des noms et icônes dans le Puzzle ACL (SharedPreferences + migration des clés Grants V29). Renommage possible sur la colonne Via.'
            : 'Fixed ACL Puzzle name and icon persistence (SharedPreferences + Grants V29 key migration). Rename enabled on Via column.',
        verification: isFr
            ? 'Puzzle > personnaliser une règle > fermer l\'app > rouvrir'
            : 'Puzzle > customize a rule > close app > reopen',
      ),
      WhatsNewVersion(
        version: '2.1.2',
        title: isFr
            ? 'Release 2.1.2 — ACL plus clair'
            : 'Release 2.1.2 — Clearer ACL UI',
        description: isFr
            ? 'Écran ACL simplifié : guide pas-à-pas en brouillon, défilement sur toute la page, formulaire avancé replié, bandeau migration sans lien Rollback confus, SafeArea corrigé sur le composeur de grants.'
            : 'Simplified ACL screen: step-by-step draft guide, full-page scroll, collapsed advanced form, migration banner without confusing Rollback link, SafeArea fix on grant composer.',
        verification: isFr
            ? 'ACL > brouillon local : guide 4 étapes | Composeur : bouton Suivant visible'
            : 'ACL > local draft: 4-step guide | Composer: Next button visible',
      ),
      WhatsNewVersion(
        version: '2.1.1',
        title: isFr
            ? 'Release 2.1.1 — Backup & brouillon ACL'
            : 'Release 2.1.1 — ACL Backup & Draft',
        description: isFr
            ? 'Export et import de la policy ACL en JSON (backup daté), workflow « repartir de zéro » en brouillon local (tout autoriser sans toucher au serveur), bandeau brouillon non publié, et correction des radios du composeur d\'édition.'
            : 'Export and import ACL policy as JSON (dated backup), « start from scratch » workflow as local draft (allow all without touching the server), unpublished draft banner, and edit composer radio fixes.',
        verification: isFr
            ? 'ACL > ⋮ > Exporter backup JSON | Importer depuis JSON | Repartir : tout autoriser… > Brouillon local'
            : 'ACL > ⋮ > Export JSON Backup | Import from JSON | Start over: allow all… > Local draft',
      ),
      WhatsNewVersion(
        version: '2.1.0',
        title: isFr
            ? 'Release 2.1.0 — Composeur de Grants'
            : 'Release 2.1.0 — Grant Composer',
        description: isFr
            ? 'Nouveau composeur guidé de règles Grants V29 (templates LAN, Internet, intra-flotte, IP), édition inline des grants, bandeau post-migration, et picker routeur par nœud dans le Puzzle. Disponible uniquement en mode Grants V29 sur Headscale ≥ 0.29.'
            : 'New guided Grants V29 rule composer (LAN, Internet, intra-fleet, IP templates), inline grant editing, post-migration banner, and per-node router picker in Puzzle. Available only in Grants V29 mode on Headscale ≥ 0.29.',
        verification: isFr
            ? 'ACL > Composeur | Tap grant pour éditer | Fiche nœud > icône baguette'
            : 'ACL > Composer | Tap grant to edit | Node detail > wand icon',
      ),
      WhatsNewVersion(
        version: '2.0.0',
        title: isFr
            ? 'Release 2.0.0 — Grants, Via & UI ACL'
            : 'Release 2.0.0 — Grants, Via & ACL UI',
        description: isFr
            ? 'Refonte complète de l\'écran ACL (onglets Grants/ACLs/JSON), Puzzle 3 colonnes avec routage via, graphe ACL enrichi, wizard de migration Grants V29, rollback moteur, et avertissements utilisateurs sans nœud tagué.'
            : 'Full ACL screen overhaul (Grants/ACLs/JSON tabs), 3-column Puzzle with via routing, enhanced ACL graph, Grants V29 migration wizard, engine rollback, and warnings for users without tagged nodes.',
        verification: isFr
            ? 'ACL > onglets | Puzzle > colonne Via | Paramètres > Migration Grants V29'
            : 'ACL > tabs | Puzzle > Via column | Settings > Grants V29 migration',
      ),
      WhatsNewVersion(
        version: '1.10.0',
        title: isFr
            ? 'Moteur Grants V29 (via)'
            : 'Grants V29 Engine (via)',
        description: isFr
            ? 'Nouveau moteur ACL basé sur les grants Headscale 0.29+ avec routage via pour les sous-réseaux LAN et exit nodes. Résout les collisions quand plusieurs utilisateurs partagent le même CIDR (ex. 192.168.1.0/24). Sélectionnable dans Paramètres > Moteur de génération ACL. Activation automatique sur serveurs ≥ 0.29 si aucun choix explicite.'
            : 'New ACL engine based on Headscale 0.29+ grants with via routing for LAN subnets and exit nodes. Resolves collisions when multiple users share the same CIDR (e.g. 192.168.1.0/24). Selectable in Settings > ACL Generation Engine. Auto-enabled on servers ≥ 0.29 when no explicit choice was made.',
        verification: isFr
            ? 'Paramètres > Moteur ACL > Grants V29. Nécessite Headscale 0.29.0+.'
            : 'Settings > ACL Engine > Grants V29. Requires Headscale 0.29.0+.',
      ),
      WhatsNewVersion(
        version: '1.9.0',
        title: isFr
            ? 'Support Officiel Taildrive (Headscale v0.29.0+)'
            : 'Official Taildrive Support (Headscale v0.29.0+)',
        description: isFr
            ? 'Taildrive est désormais pleinement supporté ! Intégration complète avec les nodeAttrs (drive:share, drive:access) et les grants (tailscale.com/cap/drive). La fonctionnalité est activée automatiquement pour les serveurs Headscale v0.29.0 et supérieurs. Accédez directement à la gestion des partages depuis le menu ACL (icône dossier partagé).'
            : 'Taildrive is now fully supported! Complete integration with nodeAttrs (drive:share, drive:access) and grants (tailscale.com/cap/drive). The feature is automatically enabled for Headscale servers v0.29.0 and above. Access share management directly from the ACL menu (shared folder icon).',
        verification: isFr
            ? 'Menu ACL > icône dossier partagé (📁). Nécessite Headscale v0.29.0+.'
            : 'ACL Menu > shared folder icon (📁). Requires Headscale v0.29.0+.',
      ),
      WhatsNewVersion(
        version: '1.8.0',
        title: isFr
            ? 'Personnalisation Utilisateurs & Appareils'
            : 'User & Device Personalization',
        description: isFr
            ? 'Affichage en Liste ou Grille persistant pour les utilisateurs. Mémos d\'administration persistants avec sauvegarde automatique intelligente dans le détail utilisateur. Auto-détection intelligente et sélecteur d\'icônes d\'appareils. Curseur de seuil de latence ping avec coloration dynamique des alertes dans les logs et graphique épuré.'
            : 'Persistent Grid/List toggle for the users screen. Administration notes with smart auto-save in user details. Default device icon auto-detection & manual selection override. Ping latency threshold slider with reactive visual highlights in logs and graphs.',
        verification: isFr
            ? 'Écran Utilisateurs > changer de vue ; Détails Utilisateur > zone mémos ; Détail Appareil > clic icône ou outils de diagnostic.'
            : 'Users Screen > toggle view; User Details > notes area; Device Details > click icon or diagnostic tools.',
      ),
      WhatsNewVersion(
        version: '1.7.1',
        title: isFr
            ? 'Stabilité Android & Puzzle ACL'
            : 'Android Stability & ACL Puzzle',
        description: isFr
            ? 'Correctif majeur résolvant un écran noir au démarrage causé par des erreurs de déchiffrement du Keystore Android lors des mises à jour. Ajout de la personnalisation riche des couleurs et icônes d\'en-têtes de blocs du Puzzle ACL avec adaptation automatique des contrastes (luminance) et retour à la ligne intelligent pour les noms longs. Désactivation explicative de Taildrive.'
            : 'Major hotfix resolving a black screen on startup caused by Android Keystore decryption errors during updates. Adds rich color and icon customization for ACL Puzzle block headers with automatic contrast adjustment (luminance) and smart text wrapping for long names. Explanatory Taildrive disabling.',
        verification: isFr
            ? 'Écran ACL > Puzzle View > Bouton de réglages (tune) sur chaque bloc'
            : 'ACL Screen > Puzzle View > settings button (tune) on each block',
      ),
      WhatsNewVersion(
        version: '1.6.0',
        title: isFr
            ? 'Partage de fichiers (Taildrive)'
            : 'File Sharing (Taildrive)',
        description: isFr
            ? 'Intégration de Taildrive ! Partagez des dossiers entre vos appareils directement via les ACL. Inclut un filtre de connectivité intelligent pour ne proposer que des partages fonctionnels.'
            : 'Taildrive Integration! Share folders between your devices directly via ACLs. Includes an intelligent connectivity filter to only suggest functional shares.',
        verification: isFr
            ? 'Écran ACL > Bouton (+) > Partages Taildrive'
            : 'User Screen > (+) Button > Taildrive Shares',
      ),
      WhatsNewVersion(
        version: '1.5.105',
        title: isFr
            ? 'Connexion OIDC & Corrections Importantes'
            : 'OIDC Connection & Important Fixes',
        description: isFr
            ? 'Nouveau : Choix entre connexion Classique et OIDC lors de l\u2019ajout d\u2019un appareil. Correction automatique des utilisateurs OIDC créés sans nom (email utilisé comme nom). Correction d\u2019un bug d\u2019affichage du graphe ACL. Suppression des warnings de dépréciation.'
            : 'New: Choose between Classic and OIDC connection when adding a device. Auto-fix for OIDC users created without a name (email used as name). Fixed ACL graph display bug. Removed deprecation warnings.',
        verification: isFr
            ? 'Écran Utilisateur > Nouvel Appareil > choisir le mode de connexion.'
            : 'User Screen > New Device > choose connection mode.',
      ),
      WhatsNewVersion(
        version: '1.5.104',
        title: isFr
            ? 'Gestion des Clés API Restaurée'
            : 'API Key Management Restored',
        description: isFr
            ? 'L\'écran de gestion des clés API est de retour ! Accessible depuis les Paramètres avec un design modernisé. Gérez vos clés d\'administration en toute sécurité.'
            : 'The API Key management screen is back! Accessible from Settings with a modernized design. Manage your admin keys securely.',
        verification: isFr
            ? 'Paramètres > Bouton (+) > Clés API'
            : 'Settings > (+) Button > API Keys',
      ),
      WhatsNewVersion(
        version: '1.5.103',
        title: isFr
            ? 'Support des Commentaires ACL (HuJSON)'
            : 'ACL Comments Support (HuJSON)',
        description: isFr
            ? 'Les commentaires (//) dans vos ACL sont désormais correctement gérés par les vues Graphique et Puzzle. Plus de crash lors de la visualisation de configurations complexes !'
            : 'Comments (//) in your ACLs are now correctly handled by Graph and Puzzle views. No more crashes when viewing complex configurations!',
        verification: isFr
            ? 'Ajoutez un commentaire "// test" dans l\'éditeur ACL et ouvrez la vue Puzzle.'
            : 'Add a "// test" comment in the ACL editor and open the Puzzle view.',
      ),
      WhatsNewVersion(
        version: '1.5.102',
        title:
            isFr ? 'Support OIDC Avancé & ACLs' : 'Advanced OIDC & ACL Support',
        description: isFr
            ? 'Mise à jour majeure pour OIDC ! Support des noms d\'utilisateurs type email (user@domaine.com) pour s\'aligner avec les ACLs. Correction des nœuds "orphelins" via matching par ID. Ajout de l\'auto-tagging pour les nouveaux appareils OIDC.'
            : 'Major OIDC update! Support for email-style usernames (user@domain.com) to align with ACLs. Fixed "orphaned" nodes via ID-based matching. Added auto-tagging for new OIDC devices.',
        verification: isFr
            ? 'Renommez votre utilisateur en "email" et voyez vos nœuds réapparaître automatiquement.'
            : 'Rename your user to "email" format and watch your nodes reappear automatically.',
      ),
      WhatsNewVersion(
        version: '1.4.97',
        title: isFr ? 'Renommer l\'Utilisateur (OIDC)' : 'Rename User (OIDC)',
        description: isFr
            ? 'Vous pouvez maintenant renommer les utilisateurs ! Idéal pour corriger les identifiants techniques (ID) générés par OIDC (Google) en noms lisibles (ex: "Jean").'
            : 'You can now rename users! Perfect for fixing technical IDs generated by OIDC (Google) into readable names (e.g., "John").',
        verification: isFr
            ? 'Option "Renommer" disponible dans le menu (...) de la liste des utilisateurs.'
            : '"Rename" option available in the User List (...) menu.',
      ),
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
    ];
  }
}
