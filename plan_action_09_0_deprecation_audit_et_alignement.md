# Sous-Plan d'Action 09-0 — Dépréciation $N-2$, Purge Pré-v0.26 & Diagnostic Intelligent d'Alignement

**Date de création** : 17 novembre 2026  
**Version cible** : `2.5.0+162` *(Étape 4.0 — voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md) et [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md))*  
**Branche Git dédiée** : `feat/acl-09-0-deprecation-and-alignment` *(créée depuis `master`)*  
**Plan parent** : [plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md)  
**Niveau de risque** : 🟢 **Très Faible** *(audit en lecture seule + corrections uniquement sur validation explicite de l'administrateur avec aperçu Diff)*

---

## 1. Objectif du Sous-Plan 09-0

Avant d'activer l'hybridation Tags / Sans Tags (`09-A`), de stopper l'auto-tagging (`09-B`) et d'ouvrir le nouveau moteur `Sans Tags` (`09-C`), ce sous-plan prépare et assainit le terrain :
1. **Prévenir les utilisateurs d'anciennes versions ($\le N-2$, soit $\le 0.27$)** via un **Bandeau Rouge d'avertissement** clair, adossé au fichier de suivi [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md).
2. **Purger les règles obsolètes pré-v0.26** (`< 0.26`) qui polluent les politiques ACL modernes.
3. **Mettre en place un Diagnostic Intelligent d'Alignement (`AlignmentDiagnosticService`)** qui détecte automatiquement les configurations utilisateur/serveur susceptibles de faire sauter les ACLs lors d'une bascule (passage à OIDC sur mobile, passage à `Grants V29`, ou passage en `Sans Tags`) et **les corrige en sécurité avec l'accord de l'administrateur**.

---

## 2. Détails Techniques

### Tâche 09-0.1 — Gouvernance $N-2$ (`VersionInfo`) & Bandeau Rouge d'Avertissement
- Dans `lib/models/version_info.dart` :
  - Définir `static const String currentReferenceVersion = '0.29.0';` et `static const String minActivelySupportedVersion = '0.28.0';` (correspondant à $N-1$).
  - Ajouter `static bool isServerDeprecated(String? serverVersion)` qui retourne `true` si la version du serveur est valide mais strictement inférieure à `0.28.0` (donc $\le 0.27$, soit $\ge 2$ versions majeures de retard sur `0.29`).
- Créer `lib/widgets/deprecated_server_banner.dart` :
  - Bandeau rouge haute visibilité affiché en haut de `DashboardScreen` et `SettingsScreen` lorsque `VersionInfo.isServerDeprecated(appProvider.serverVersion)` est vrai.
  - Message bilingue FR/EN :
    - **FR** : *"⚠️ Serveur Headscale obsolète (v${version}) : votre serveur a au moins 2 versions majeures de retard sur la version courante (v0.29). Veuillez mettre à jour votre serveur Headscale : la prise en charge des fonctions dépréciées pour cette version sera retirée lors de la prochaine mise à jour majeure de l'application."*
    - **EN** : *"⚠️ Outdated Headscale server (v${version}): your server is at least 2 minor versions behind the current release (v0.29). Please upgrade your Headscale server: deprecated compatibility features for this version will be removed in the next major app update."*

### Tâche 09-0.2 — Purge des Règles Obsolètes Pré-v0.26 (`< 0.26`)
- Conformément au Palier 1 de [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md) :
  - Aligner définitivement `resolveAclGroupMembers` dans `lib/utils/string_utils.dart` sur la spécification Headscale Policy v2 ($\ge 0.26$) :
    - Si `user.email` contient `@` $\rightarrow$ inclure `user.email!`.
    - Si `user.name` contient `@` $\rightarrow$ inclure `user.name`.
    - Si `user.name` ne contient **pas** de `@` (utilisateur local créé sans email, ex: `"jean"`) $\rightarrow$ inclure **`"${user.name}@"`** (avec `@` final vide, exigé par `hscontrol/types/users.go` et `policy/v2` pour reconnaître les nœuds sans tags d'un utilisateur local !).
  - Nettoyer toute génération d'ancien champ `autoApprovers.exitNodes` (pré-0.26) ou de propriétaires `tagOwners` sans `group:` ni `@`.

### Tâche 09-0.3 — Système Intelligent de Détection & d'Alignement Assisté (`AlignmentDiagnosticService`)
Créer `lib/services/acl/alignment_diagnostic_service.dart` et le dialogue interactif `lib/widgets/acl/alignment_assistant_dialog.dart`.

Ce service inspecte en lecture seule `{users, nodes, serverPolicy, serverVersion}` et détecte **6 types de désalignements** :

1. **🔥 Cas critique "Double profil Local + OIDC" (Protection anti-perte d'ACL sur mobile OIDC)** :
   - **Problème vécu** : Un utilisateur avait un compte local (ex: `jean` avec des machines `tag:jean-client`) puis, après activation d'OIDC, son téléphone mobile a été forcé de s'enregistrer via OIDC (créant ou utilisant `jean.dupont@gmail.com`, ou un nœud sans tag rattaché au compte OIDC). Lors d'une régénération ACL, les deux identités n'étaient pas reliées ou les nœuds sans tags OIDC perdaient leurs règles !
   - **Détection & Alignement automatique (avec accord admin)** :
     - Détecte les utilisateurs/nœuds partageant le même radical normalisé ou email, ou un utilisateur OIDC dont les nœuds viennent d'apparaître sans tags à côté d'anciennes machines taguées.
     - Propose en **1 clic (avec aperçu Diff)** d'unifier dans `groups["group:jean"]` à la fois l'identifiant local (`"jean@"`) et l'email OIDC (`"jean.dupont@gmail.com"`), et d'inclure `group:jean` aux côtés de `tag:jean-client` dans les règles de l'utilisateur.
     - Si deux comptes Headscale distincts existent sur le serveur (un ancien compte local vide ou partiel + le nouveau compte OIDC), guide l'administrateur étape par étape pour rapatrier ou aligner les tags sur le compte OIDC sans aucune coupure réseau.

2. **Membres de `"groups"` mal formés sur Headscale $\ge 0.26$** :
   - Détecte dans la policy active sur le serveur :
     - Les membres sans `@` (ex: `"jean"` hérité d'une v0.25) qui font échouer le parseur 0.26+.
     - Les membres locaux ayant reçu un faux domaine `"jean@domaine-serveur"` alors que l'utilisateur local Headscale n'a pas d'email (ce qui empêche Headscale de reconnaître ses machines sans tags car Headscale attend `"jean@"`).
   - **Action proposée (Auto-Fix API)** : Remplacer/compléter par `"jean@"` (et l'email OIDC réel s'il existe) avec validation via `PolicyDiffDialog`.

3. **Propriétaires `"tagOwners"` invalides ou incomplets** :
   - Détecte les propriétaires qui ne commencent ni par `group:`, ni par `autogroup:`, et ne contiennent pas `@` (cause de l'erreur `v2.OwnerEnc`), ainsi que les tags portés par des nœuds actifs mais absents de `tagOwners` (cause de `tags_not_permitted` en 0.29/0.30).
   - **Action proposée (Auto-Fix API)** : Normaliser en `group:<user>` et déclarer tous les tags actifs dans `tagOwners`.

4. **Ancien bloc `autoApprovers.exitNodes` (pré-0.26)** :
   - Détecte la présence de `exitNodes` dans `autoApprovers` sur la policy serveur.
   - **Action proposée (Auto-Fix API)** : Convertir automatiquement en `autoApprovers.routes["0.0.0.0/0"]` et `["::/0"]`.

5. **Tags Legacy fusionnés (`;exit-node`, `;lan-sharer`) ou contenant des points (`.`)** :
   - Détecte les nœuds portant encore des tags avec `;` ou `.` qui bloquent la bascule propre vers `Grants V29` ou isolent l'appareil.
   - **Action proposée (Auto-Fix API)** : Convertir en 1 clic les tags des nœuds concernés via `setTags` (après mise à jour de `tagOwners`) vers le format Standard séparé.

6. **Noms de machines non conformes RFC 1123 (`_`, majuscules, espaces)** :
   - Détecte les nœuds dont `node.name` viole la RFC 1123 (incompatible Headscale 0.27+ et alias `hosts`).
   - **Action proposée (Auto-Fix API)** : Renommer automatiquement via `renameNode(node.id, sanitizeDns1123Subdomain(node.name))` après confirmation de l'admin.

---

## 3. Où ce diagnostic s'affiche-t-il ? (Zéro intrusion, 100 % accessible)

1. **Automatiquement en pré-vérification (Pre-Flight Check)** avant toute bascule de moteur ACL (vers `Grants V29` ou vers `Sans Tags`) : si tout est aligné, la bascule continue ; si des anomalies sont détectées, l'assistant propose de les corriger d'abord en 1 clic !
2. **À la demande à tout moment** : via un badge/bouton **"🩺 Diagnostic & Alignement ACL"** dans l'en-tête de l'écran ACL (`AclEngineBanner`) et dans **Paramètres > Moteur ACL**.

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `REGISTRE_DEPRECATION_HEADSCALE.md` | Registre maître des versions dépréciées et code à purger |
| **Nouveau** | `lib/widgets/deprecated_server_banner.dart` | Bandeau rouge d'avertissement pour serveurs $\le N-2$ ($\le 0.27$) |
| **Nouveau** | `lib/services/acl/alignment_diagnostic_service.dart` | Moteur de détection des 6 familles de désalignements + correctifs automatiques |
| **Nouveau** | `lib/widgets/acl/alignment_assistant_dialog.dart` | Interface guidée d'alignement avec correction 1-clic et aperçu Diff |
| **Modifié** | `lib/models/version_info.dart` | Ajout de `isServerDeprecated` et constantes de fenêtre $N / N-2$ |
| **Modifié** | `lib/utils/string_utils.dart` | Alignement `resolveAclGroupMembers` sur `"user@"` (Policy v2 $\ge 0.26$) |
| **Modifié** | `lib/screens/dashboard_screen.dart` & `lib/screens/settings_screen.dart` | Affichage de `DeprecatedServerBanner` si serveur $\le 0.27$ + accès à l'assistant d'alignement |
| **Modifié** | `lib/screens/acl_screen.dart` | Bouton d'accès au Diagnostic d'Alignement + pre-flight check |
| **Tests** | `test/services/acl/alignment_diagnostic_service_test.dart` | Tests unitaires de détection et de correction automatique *(Nouveau)* |

---

## 5. Gate de Validation `09-0`
- [ ] `flutter analyze` $\rightarrow$ `0 issue`.
- [ ] Tests unitaires de `resolveAclGroupMembers` (`"user@"` pour local sans email, email complet pour OIDC) et de `AlignmentDiagnosticService` $\rightarrow$ `100% OK`.
- [ ] Test visuel : simulation d'une version `0.27.0` $\rightarrow$ le bandeau rouge s'affiche bien sur le Dashboard et dans Paramètres ; en `0.28.0` ou `0.29.0` $\rightarrow$ aucun bandeau rouge.
- [ ] Test du bouton **"🩺 Diagnostic & Alignement ACL"** sur ta policy actuelle : vérifie qu'il détecte proprement d'éventuels écarts et propose le Diff avant d'appliquer quoi que ce soit.
