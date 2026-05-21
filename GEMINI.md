# Headscale Manager - AI Brain & Architecture Guide

Ce fichier est le guide d'architecture de référence du projet **Headscale Manager**. Il a été conçu spécifiquement pour servir de point d'entrée complet à tout nouvel agent d'IA (ou développeur humain) démarrant une conversation vierge. Il détaille la structure, les mécanismes de synchronisation, les modèles de données, le moteur d'ACL et les flux de travail clés pour vous permettre d'apporter des modifications fiables et immédiates sans historique de conversation préalable.

---

## 🎯 1. Vue d'ensemble & Philosophie de Conception

**Headscale Manager** est un client multiplateforme (Android, iOS, macOS, Windows, Web) écrit en **Flutter** permettant d'administrer graphiquement un serveur [Headscale](https://github.com/juanfont/headscale) (l'alternative open-source auto-hébergée au plan de contrôle Tailscale).

### Principes directeurs :
1. **API First** : L'état local n'est pas le maître absolu. Les actions de l'utilisateur effectuent des requêtes HTTP directes via le repository API pour s'assurer que les données du serveur Headscale sont à jour.
2. **Centralisation de l'État** : Tout passe par `AppProvider` (`provider`). Les widgets ne doivent jamais instancier ou manipuler l'API directement, ils écoutent ou lisent `AppProvider`.
3. **Sécurité stricte** : Aucun mot de passe ou clé API n'est stocké en texte clair ou dans les logs. Tout passe par `StorageService` (`flutter_secure_storage`).
4. **Bilingue natif** : Traduction complète et dynamique en Français (`fr`) et Anglais (`en`).

---

## 📁 2. Structure Détaillée du Code & Rôle des Fichiers

```
lib/
├── api/
│   └── headscale_api_service.dart     # Repository central REST client
├── models/
│   ├── node.dart                      # Modèle pour un équipement connecté (machine)
│   ├── user.dart                      # Modèle pour un utilisateur
│   ├── pre_auth_key.dart              # Modèle pour une clé de pré-authentification
│   ├── api_key.dart                   # Modèle pour les clés API du serveur
│   ├── server.dart                    # Infos de connexion d'un serveur configuré
│   ├── taildrive_share.dart           # Modèle de partage WebDAV (Taildrive)
│   └── version_info.dart              # Analyse de la version de l'instance Headscale
├── providers/
│   └── app_provider.dart              # Le "Brain". Gestionnaire d'état réactif (ChangeNotifier)
├── services/
│   ├── storage_service.dart           # Persistance sécurisée multi-serveurs
│   ├── standard_acl_generator_service.dart # Générateur d'ACL standard moderne (Recommandé)
│   ├── new_acl_generator_service.dart      # Générateur d'ACL alternatif
│   ├── acl_parser_service.dart        # Parseur et décodeur de la politique d'ACL active
│   ├── route_conflict_service.dart    # Détecteur de conflits d'IP et sous-réseaux
│   ├── notification_service.dart      # Tâches en arrière-plan (Workmanager/Notifications)
│   └── tag_migration_service.dart     # Service d'aide à la migration de tags
├── screens/
│   ├── dashboard_screen.dart          # Page principale (Nettoyage automatique & Approbations)
│   ├── acl_screen.dart                # Éditeur de règles d'accès & Générateur
│   ├── acl_manager_screen.dart        # Représentation visuelle de la topologie (GraphView)
│   ├── taildrive_manager_screen.dart  # Gestion des partages de dossiers (Taildrive WebDAV)
│   ├── network_overview_screen.dart   # Outil de ping & Traçage d'exit node
│   └── dns_screen.dart                # MagicDNS de chaque nœud
└── utils/
    ├── string_utils.dart              # Normalisation des chaînes de caractères (indispensable)
    └── ip_utils.dart                  # Outils d'aide au parsing et validation des IPs/CIDRs
```

---

## 🧠 3. Le Cœur du Projet : Flux de Données & Gestion d'État

### 3.1. `AppProvider` (lib/providers/app_provider.dart)
C'est le pivot central. Il instancie et détient le service d'API actif `HeadscaleApiService`.
* **Multi-Serveurs** : Il stocke la liste des serveurs configurés par l'utilisateur (`_servers`) et le serveur actif actuel (`_activeServer`).
* **Initialisation** : Lors de sa création, il charge séquentiellement la locale, les serveurs, la configuration de l'ACL, et auto-détecte de manière asynchrone la version du serveur (`_detectServerVersion()`).
* **Auto-Détection du Moteur d'ACL** : Il inspecte les tags des nœuds au lancement : si des tags au format standard (`-exit-node`) sont trouvés sans tags hérités fusionnés (`;exit-node`), il active automatiquement le moteur d'ACL standard moderne.

### 3.2. `HeadscaleApiService` (lib/api/headscale_api_service.dart)
Gère l'intégralité du protocole REST. 
* **Headers** : Injecte systématiquement le jeton d'autorisation : `Authorization: Bearer <API_KEY>`.
* **Mapping Robuste** : Les réponses JSON sont décodées et directement converties en instances de modèles Dart. Lors du chargement des nœuds, le `baseDomain` extrait de l'URL du serveur est injecté pour calculer à la volée le MagicDNS complet de chaque nœud.

### 3.3. `StorageService` (lib/services/storage_service.dart)
Gère le stockage persistant :
* Utilise `flutter_secure_storage` pour la clé API et l'URL du serveur.
* Utilise `shared_preferences` pour les réglages de l'application moins sensibles comme la langue (`locale`), les préférences d'activation de l'arrière-plan, et le type de moteur ACL préféré.
* Utilise des clés préfixées (ex: `TAILDRIVE_SHARES_`) indexées par l'ID unique du serveur pour supporter l'isolation des données lors du changement de serveur.

---

## 🛡️ 4. Le Système de Génération d'ACL

La gestion des accès de Headscale est centralisée via la génération de la politique au format JSON. Headscale Manager propose un générateur intelligent qui élimine les erreurs de configuration manuelles.

Il existe deux moteurs configurables :
1. **Moteur Standard (`StandardAclGeneratorService`) [Recommandé]** : Utilise des tags distincts pour chaque fonctionnalité (`tag:user-client`, `tag:user-exit-node`, `tag:user-lan-sharer`).
2. **Moteur Alternatif (`NewAclGeneratorService`)** : Version alternative du moteur.

### ⚠️ Règle d'or de Normalisation (`string_utils.dart`)
Toutes les correspondances de groupes, tags, ou autoApprovers dans Headscale dépendent de la chaîne de l'utilisateur. 
> [!IMPORTANT]
> Headscale est sensible à la casse et n'accepte pas certains caractères spéciaux dans les noms de tags ou de groupes. Tout nom d'utilisateur **doit impérativement être normalisé** via `normalizeUserName(String name)` avant de l'injecter dans un tag ou un groupe ACL :
> - Convertit en minuscules.
> - Remplace `@` et `.` par des tirets `-`.
> - Retire tout caractère non alphanumérique restant (sauf les tirets).
> *Exemple : `Jean.Dupont@synology.me` devient `jean-dupont-synology-me`.*

### 📂 4.1. Le Support Spécifique de Taildrive (Partage de dossiers)
Taildrive permet le partage de dossiers locaux via WebDAV au travers du réseau chiffré Tailscale. 
Pour autoriser une machine à publier un partage et un utilisateur à le lire, le générateur d'ACL standard injecte dynamiquement deux blocs dans le fichier JSON final :
1. **`nodeAttrs`** : Octroie la capacité Taildrive à la machine hôte.
   ```json
   "nodeAttrs": [
     {
       "target": ["tag:jean-client"],
       "attr": ["cap:taildrive"]
     }
   ]
   ```
2. **`grants`** : Accorde les permissions de lecture (`ro`) ou d'écriture (`rw`) sur un partage nommé spécifique à un bénéficiaire (utilisateur ou groupe).
   ```json
   "grants": [
     {
       "src": ["group:clarisse"],
       "dst": ["tag:jean-client"],
       "app": {
         "tailscale.com/cap/taildrive": [
           {
             "share": "photos",
             "access": "rw"
           }
         ]
       }
     }
   ]
   ```

---

## 🔄 5. Scénarios & Flux de Travail Types pour l'Agent IA

Voici comment aborder des modifications ou de l'analyse sur ce projet sans historique de conversation :

### 🚀 Scénario A : Vous devez ajouter ou modifier une API Headscale
1. Ouvrez `ListeApiAvaible.md` (qui contient la spécification OpenAPI/Swagger complète de l'instance).
2. Ajoutez la méthode HTTP correspondante dans `lib/api/headscale_api_service.dart`.
3. Si un nouveau type de données est retourné, créez le modèle associé dans `lib/models/` avec un constructeur `fromJson` et sa méthode de sérialisation `toJson`.
4. Raccordez le tout à `lib/providers/app_provider.dart` si le résultat doit affecter l'état global ou nécessiter un rafraîchissement d'interface.

### 🛠️ Scénario B : Vous modifiez la logique d'ACL (Moteur Standard)
1. Modifiez la logique d'assemblage ou de filtrage dans `lib/services/standard_acl_generator_service.dart`.
2. Assurez-vous d'appliquer systématiquement `normalizeUserName` sur tous les noms d'utilisateurs injectés dans des chaînes de tags ou de groupes.
3. Vérifiez que les modifications sont correctement passées dans `lib/screens/acl_screen.dart` lors de l'appel à `generatePolicy(...)`.

### 📱 Scénario C : Vous travaillez sur l'Interface Utilisateur (UI)
1. **Aesthétiques** : Utilisez des couleurs issues du thème existant (harmonisation HSL/Hex, dégradés, micro-animations au clic).
2. **Support Multilingue** : Les écrans accèdent à la langue via `final isFr = appProvider.locale.languageCode == 'fr';`. Utilisez systématiquement des ternaires ou des dictionnaires locaux pour adapter tous les textes à la langue courante.
3. **Mise à Jour** : Après avoir modifié un fichier Dart, si vous êtes en cours d'exécution locale, vous devez **déclencher un Hot Restart** dans la console Flutter pour instancier les modifications du code métier ou de la génération de politique.

---

## 🧪 6. Procédures de Test & de Validation local
* **Analyse Statique** : Assurez-vous qu'aucun avertissement ou erreur de lint n'est présent en exécutant `flutter analyze` si vous avez la CLI Flutter à disposition.
* **Génération ACL** : Dans l'écran **ACL**, générez et inspectez visuellement le JSON résultant pour vous assurer que les structures `nodeAttrs` et `grants` sont bien présentes et correctement formatées si des partages Taildrive sont actifs.
