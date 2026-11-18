# Suivi d'Implémentation — Ordre Logique & Graduel (du moins risqué au plus risqué)

**Branche de référence (stable) :** `master` *(version prête pour Publication publique #1 : `2.5.2+169`)*  
**Dernière mise à jour :** 18 novembre 2026  
**Registre de dépréciation :** [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md)

---

## 1. Ordre d'Exécution Recommandé & Dépendances

L'ordre ci-dessous classe les plans **du risque de casse en production le plus faible au plus élevé**, tout en respectant strictement les **dépendances techniques** :

```text
[Étape 1] Plan 10 : Cybersécurité & Résilience (✅ Validé, Mergé & Publié)
    ▼
[Étape 2] Plan 08 : Compatibilité Multi-Versions & Fusion Non-Destructive (✅ Validé, Mergé & Publié)
    ▼
[Étape 3] Plan 11 : Outils Visuels (Diff, Simulateur, SSH) & API (✅ Validé, Mergé & Publié — 2.4.0+161)
    ▼
[Étape 4.0] Sous-Plan 09-0 : Dépréciation N-2 (Bandeau Rouge <= 0.27), Purge < 0.26 & Diagnostic Intelligent d'Alignement
    │       Branche : feat/acl-09-0-deprecation-and-alignment (Risque 🟢 Très Faible)
    ▼
[Étape 4.A] Sous-Plan 09-A : Cœur Hybride Zéro-Coupure (Tags + Sans Tags + OIDC) & Résolution Simulateur/Graphe
    │       Branche : feat/acl-09-a-hybrid-core (Risque 🟢 Faible)
    ▼
[Étape 4.B] Sous-Plan 09-B : Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud
    │       Branche : feat/acl-09-b-stop-autotag-and-wizard (Risque 🟡 Faible à Moyen)
    ▼
[Étape 4.C] Sous-Plan 09-C : 4ème Moteur "Sans Tags" (AclEngineMode.tagless) & Adaptation des Constructeurs Manuels
            Branche : feat/acl-09-c-tagless-and-builders (Risque 🟡 Moyen)
```

> [!IMPORTANT]
> **Règle d'or entre chaque sous-étape :**
> - Créer la branche dédiée depuis `master` à jour.
> - Consulter [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md) lors de chaque évolution de version serveur.
> - **Ne jamais démarrer la sous-étape suivante avant d'avoir validé le Point de contrôle de la sous-étape en cours.**

---

## 2. Tableau de Bord des Étapes & Branches

| Ordre | Plan / Sous-Plan | Version cible | Branche Git dédiée | Dépendances | Risque Prod | Statut |
|---|---|---|---|---|---|---|
| **1** | [Plan 10 — Cybersécurité & Résilience](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_10_v2.4.0_cybersecurite_et_resilience.md) | `2.2.0+157` | `sec/hardening-pin-network-sast` | Aucune | 🟢 Très Faible | ✅ Validé & Mergé |
| **2** | [Plan 08 — Compatibilité & Non-Destructif](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_08_v2.2.0_compatibilite_et_securite_acl.md) | `2.3.0+158` | `fix/compat-non-destructive-acl` | Aucune | 🟡 Moyen | ✅ Validé & Mergé |
| **3** | [Plan 11 — Diff, Simulateur, SSH & API](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_11_v2.5.0_simulateur_diff_ssh_et_api.md) | `2.4.0+161` | `feat/acl-simulator-diff-ssh-api` | Plan 08 | 🟢 Très Faible | ✅ Validé, Mergé & Publié |
| **4.0** | [Sous-Plan 09-0 — Dépréciation $N-2$ & Diagnostic d'Alignement](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_0_deprecation_audit_et_alignement.md) | `2.5.0+165` | `feat/acl-09-0-deprecation-and-alignment` | Plan 11 | 🟢 Très Faible | ✅ Validé, Mergé & Test interne OK |
| **4.A** | [Sous-Plan 09-A — Cœur Hybride & Résolution Simulateur/Graphe](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_A_coeur_hybride_et_groupes.md) | `2.5.1+166` | `feat/acl-09-a-hybrid-core` | Sous-Plan 09-0 | 🟢 Faible | ✅ Validé & Mergé |
| **4.B** | [Sous-Plan 09-B — Stop Auto-Tagging & Centre de Bascule Guidée](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_B_arret_autotagging_et_assistant_bascule.md) | `2.5.2+169` | `feat/acl-09-b-stop-autotag-and-wizard` | Sous-Plan 09-A | 🟡 Faible-Moyen | ✅ Validé & Mergé *(Publication #1)* |
| **4.C** | [Sous-Plan 09-C — Moteur `Sans Tags` & Constructeurs Manuels](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_C_moteur_tagless_et_constructeurs.md) | `2.6.0+170` | `feat/acl-09-c-tagless-and-builders` | Sous-Plan 09-B | 🟡 Moyen | ⬜ À faire *(Publication #2)* |

**Légende des statuts :** `⬜ À faire` • `🔄 En cours` • `🧪 En test interne` • `✅ Validé & Mergé` • `⏪ Rollback effectué`

---

## 3. Checklists Détaillées par Étape

### Étape 1 — Plan 10 (`sec/hardening-pin-network-sast` → `2.2.0+157`)
- [x] **10.1 à 10.4** Hardening PIN PBKDF2, auto-lock, timeouts HTTP 20s, SAST 100/100, diagnostic opt-in.
- [x] **Point de contrôle 1** : Validé et mergé dans `master` ✅

### Étape 2 — Plan 08 (`fix/compat-non-destructive-acl` → `2.3.0+158`)
- [x] **08.1 à 08.6** `PolicyPreserver`, `TagCapabilityHelper`, `RouteConflictService`, `JsonUtils` HuJSON, `PreAuthKey` v0.28+, `aclEngineMode` par serveur, `PolicyOrphanCleaner`, `HuJsonCommentService`.
- [x] **Point de contrôle 2** : Validé et mergé dans `master` ✅

### Étape 3 — Plan 11 (`feat/acl-simulator-diff-ssh-api` → `2.4.0+161`)
- [x] **11.1 à 11.4** `JsonDiffUtils` + `PolicyDiffDialog` v2 (JSON & Puzzle), `AclSimulatorSheet` + `"tests"` port unique, Onglet SSH, `expireNode` + `backfillNodeIps`, préservation OIDC & règles personnalisées.
- [x] **Point de contrôle 3** : Validé, mergé dans `master` et publié (`2.4.0+161`) ✅

---

### Étape 4.0 — Sous-Plan 09-0 (`feat/acl-09-0-deprecation-and-alignment` → `2.5.0+162`)
- [x] **09-0.1** `VersionInfo.isServerDeprecated` + `DeprecatedServerBanner` (bandeau rouge sur Dashboard et Paramètres pour tout serveur $\le 0.27$, soit $\le N-2$)
- [x] **09-0.2** Purge des règles pré-v0.26 obsolètes + alignement de `resolveAclGroupMembers` sur Policy v2 (`"user@"` pour les comptes locaux sans email, email pour OIDC)
- [x] **09-0.3** `AlignmentDiagnosticService` + `AlignmentAssistantDialog` : détection et mise en conformité assistée avec accord utilisateur et aperçu Diff (unification double profil Local + Mobile OIDC, `groups` mal formés, `tagOwners` incomplets, `exitNodes` pré-0.26, tags `;`/`.`, noms DNS-1123)
- [x] **Point de contrôle 4.0 (Validation avant merge)** : `flutter analyze` (0 issue) ✅ • Tests unitaires (`resolveAclGroupMembers`, gouvernance $N-2$ & `AlignmentDiagnosticService` avec répercussion en cascade et prise en compte version/moteur) ✅ (70/70) • Tests réels sur serveur `0.29.2` (rapprochement ACL, fix Backfill IPs, normalisation `v0.29.2`) ✅ • Mergé dans `master` (`2.5.0+162`) ✅

### Étape 4.A — Sous-Plan 09-A (`feat/acl-09-a-hybrid-core` → `2.5.1+166`)
- [x] **09-A.1** Union hybride `[...sortedTags, groupName]` dans `GrantsV29GeneratorService` et `StandardAclGeneratorService` pour les parcs mixtes (machines taguées + machines sans tags) + gestion conditionnelle de `"via"` (avec ou sans tag routeur) + réglage `includeUntaggedNodes` dans Paramètres
- [x] **09-A.2** `PolicyInfrastructureBuilder` : `autoApprovers` hybrides (`group:` pour routes de nœuds sans tags) + génération et nettoyage automatique des alias `hosts` (`"host-<user>-<node>"`) dans `PolicyPreserver._mergeHosts` et `PolicyOrphanCleaner`
- [x] **09-A.3** `AclParserService` : résolution de `aclPolicy['hosts']`, `"user@"`, emails OIDC, `autogroup:member` et ports `tag:`/`group:`/`autogroup:` dans le Simulateur de flux et le Graphe Visuel ACL + rattachement `nodeBelongsToUser` dans `DashboardScreen`, `UserDetailScreen` et `TaildriveBuilder`
- [x] **Point de contrôle 4.A (Validation avant merge)** : `flutter analyze` (0 issue) ✅ • Tests unitaires parc 100% tagué, 100% sans tag, mixte, hybridation auto des règles inter-utilisateurs et Simulateur ✅ (79/79) • Test réel validé sur serveur `0.29.2` (`dkdone` basculé sans tag sous `ely@synology.me` vers `jean`) ✅ • Mergé dans `master` (`2.5.1+166`) ✅

### Étape 4.B — Sous-Plan 09-B (`feat/acl-09-b-stop-autotag-and-wizard` → `2.5.2+169`)
- [x] **09-B.1** Arrêt de l'auto-tagging forcé dans `CreatePreAuthKeyDialog` (interrupteur optionnel), `registration_dialogs.dart`, `DashboardScreen`, `NodeDetailScreen`, `ExitNodeCommandDialog`, `ShareSubnetDialog` et `MoveNodeDialog`
- [x] **09-B.2** Création du Centre d'Assistance à la Bascule (`AclMigrationCenterScreen`) accessible sans intrusion depuis Paramètres, le menu `⋮` ACL, `AclEngineBanner` et la fiche d'un Nœud (`NodeDetailScreen` / `EditTagsDialog`)
- [x] **09-B.3** Parcours guidés nœud par nœud (Parcours A : Taggé $\rightarrow$ Sans Tag / OIDC en 3 étapes avec régénération ACL auto à l'étape 3 ; Parcours B : Sans Tag $\rightarrow$ Taggé en 1 clic API avec préservation & régénération ACL ; Parcours C : Bascule serveur Grants V29 / Hybride) avec **bouton de validation de fonctionnement en direct** (vérification API + simulation automatique des flux du nœud)
- [x] **Point de contrôle 4.B (Validation avant merge)** : `flutter analyze` (0 issue) ✅ • Tests unitaires (84/84) ✅ • Migration Flutter `3.50.0` (`material_ui`/`cupertino_ui`, Gradle `9.5.0`, AGP `9.1.1`, Kotlin `2.4.20`) ✅ • Tests réels sur appareil validés (Parcours A & B Taggé $\leftrightarrow$ Sans Tag avec l'assistant) ✅ • Documentation externe & interne (`README.md`, `README.En.md`, `HelpScreen`, `HelpScreenEn`, `WhatsNewData`) et montée en `2.5.2+169` pour Publication publique #1 ✅ • Mergé dans `master` (`2.5.2+169`) ✅

### Étape 4.C — Sous-Plan 09-C (`feat/acl-09-c-tagless-and-builders` → `2.6.0+170`)
- [ ] **Lot 1 (`09-C.1`) — Moteur `Sans Tags` isolé & Sélecteur UI** : ajout de `AclEngineMode.tagless` + `TaglessAclGeneratorService` (`grants` sur $\ge 0.29$, `acls` sur $< 0.29$, `hosts`, tolérance hybride) sans toucher aux 3 moteurs existants + blocage de la popup/bascule auto `Grants V29` en mode `tagless` + UI `SettingsScreen`, `AclEngineBanner`, Parcours C et `AlignmentDiagnosticService`
- [ ] **Lot 2 (`09-C.2`) — Adaptation des constructeurs manuels & `PolicyPreserver` sécurisé** :
  - Composeur & Éditeur de Grants (`group:<user>`, `host-<user>-<node>`, routeurs sans tags `direct:<nodeId>`, préservation `uniqueSrc`, masquage `GrantsMigrationBanner` en `tagless`)
  - Vue Puzzle (normalisation `group:`, briques `host-<user>-<node>`, séparation `router_*` vs `host_*`, `isGrant: useGrants`, `emitGrants` en `tagless` $\ge 0.29$)
  - Règles Spécifiques / Exceptions (`nodeBelongsToUser` + alias `host-`)
  - Onglet Tailscale SSH (modèle rapide 1-clic `autogroup:member` $\rightarrow$ `autogroup:self`)
  - `PolicyPreserver` sécurisé : hybridation avant `_hasValidRuleReferences`, remplacement tags morts (`0` nœud tagué), bascule auto routeur tiers passé sans tag avec **garde-fou anti-élargissement en cas de conflit multi-Exit-Node / multi-LAN CIDR**, et **filtre anti-doublon inter-moteurs strictement borné** (préservation 100 % des règles avec ports/protocoles/IPs ou inter-utilisateurs)
- [ ] **Point de contrôle 4.C (Validation avant Publication publique #2)** : `flutter analyze` (0 issue) • Tests unitaires `tagless_acl_generator_test.dart` (8 architectures vérifiées par `AclParserService`) • Tests réels non destructifs sur appareil (non-régression `Grants V29`, Diff à blanc `Sans Tags`, Composeur, Puzzle et SSH)

---

## 4. Journal de Progression & Incidents

| Date | Étape / Plan | Branche | Résultat / Observations de test interne |
|---|---|---|---|
| 2026-11-16 | Initialisation & Audit | `master` | Création et audit croisé des plans 08 à 11 ; mise en place de l'ordre graduel 10 $\rightarrow$ 08 $\rightarrow$ 11 $\rightarrow$ 09. |
| 2026-11-16 | Étape 1 — Plan 10 | `sec/hardening-pin-network-sast` | Implémentation PBKDF2 + migration PIN, lockout, auto-lock arrière-plan, timeouts HTTP 20s, alerte HTTP, diagnostic opt-in, remédiation SAST. `flutter analyze` (0 issue), 36/36 tests passés. Mergé dans `master`. |
| 2026-11-16 | Étape 2 — Plan 08 | `fix/compat-non-destructive-acl` | Implémentation `PolicyPreserver`, `TagCapabilityHelper`, `RouteConflictService`, parseur HuJSON (`JsonUtils`), API PreAuthKey v0.28+, isolation `aclEngineMode` par `serverId`, `PolicyOrphanCleaner`, `HuJsonCommentService`. `flutter analyze` (0 issue) & 55/55 tests passés (`2.3.0+158`). Mergé dans `master`. |
| 2026-11-16 | Étape 3 — Plan 11 | `feat/acl-simulator-diff-ssh-api` | Implémentation `JsonDiffUtils` + `PolicyDiffDialog` v2, `AclSimulatorSheet` + `"tests"` port unique, onglet SSH, `expireNode` + `backfillNodeIps`, fix matching OIDC + préservation des règles personnalisées. `flutter analyze` (0 issue) & 64/64 tests passés (`2.4.0+161`). Mergé et publié. |
| 2026-11-17 | Découpage Plan 09 | `master` | Création de `REGISTRE_DEPRECATION_HEADSCALE.md` et découpage du Plan 09 en 4 sous-plans atomiques (`09-0`, `09-A`, `09-B`, `09-C`) avec branches dédiées. |
| 2026-11-17 | Étape 4.0 — Sous-Plan 09-0 | `feat/acl-09-0-deprecation-and-alignment` | Bandeau rouge $N-2$ ($\le 0.27$), alignement Policy v2 (`"nom@"`), `AlignmentDiagnosticService` sensible à la version/moteur avec répercussion en cascade (`groups`, `tagOwners`, `grants`, `acls`, `ssh`, `nodeAttrs`, `tests`, commentaires HuJSON, règles locales, Taildrive), fix Backfill IPs (confirmation directe `?confirmed=true`) & normalisation `(v0.29.2)`. `flutter analyze` (0 issue), 70/70 tests passés (`2.5.0+162`). Validé et mergé dans `master`. |
| 2026-11-17 | Étape 4.A — Sous-Plan 09-A | `feat/acl-09-a-hybrid-core` | Correctif préservation globale `grants`/`acls` dans `PolicyPreserver` (`EditTagsDialog` & co.), union hybride `[...tags, group]` dans `GrantsV29` & `Standard`, `autoApprovers` + `hosts` gérés (`host-*`), résolution `hosts`/`user@`/OIDC/`autogroup:member` dans `AclParserService`, hybridation automatique des règles inter-utilisateurs existantes et options `group:`/`host-` dans `GrantComposerService`. `flutter analyze` (0 issue), 79/79 tests passés, test réel validé (`dkdone` sans tag sous `ely@synology.me`). Mergé dans `master` (`2.5.1+166`). |
| 2026-11-18 | Étape 4.B — Sous-Plan 09-B | `feat/acl-09-b-stop-autotag-and-wizard` | Arrêt de l'auto-tagging forcé, `showTaglessRouteChoiceDialog`, Centre d'Assistance `AclMigrationCenterScreen` (Parcours A/B/C avec régénération ACL auto en fin de Parcours A et en Parcours B), migration Flutter `3.50.0` (`material_ui`/`cupertino_ui`, Gradle `9.5.0`, AGP `9.1.1`, Kotlin `2.4.20`). `flutter analyze` (0 issue), 84/84 tests passés, `.aab` `2.5.2+168` généré et testé sur appareil (Parcours A & B validés). Mergé dans `master` (`2.5.2+168`). |
| 2026-11-18 | Préparation Publication #1 (`2.5.2+169`) | `master` | Mise à jour documentaire complète (`README.md`, `README.En.md`, `help_screen.dart`, `help_screen_en.dart`, `whats_new_data.dart`), consolidation et découpage sécurisé en 2 lots du Plan `09-C` (`2.6.0+170`), passage en `2.5.2+169` prêt pour build et publication publique #1. |

---

## 5. Chantiers Techniques & Échéances Annexes (Hors Plans ACL)

* **🔀 Intégré au Lot 2 (`09-C.2`) — Bascule automatique d'un routeur tiers (`Exit Node` / `LAN`) vers le mode sans tag** :
  - Pris en charge dans `PolicyPreserver` (`09-C.2`) : si un utilisateur **tiers** servant d'`Exit Node` ou de routeur `LAN` (`via: ["tag:<tiers>-exit-node"]` / `["tag:<tiers>-lan-sharer"]` ou `dst: ["tag:<tiers>-*"]`) passe **à 100 % sans tag**, bascule vers `group:<tiers>` dans `src`/`dst`, et retrait automatique de `via` **uniquement sans ambiguïté** (un seul utilisateur publie `autogroup:internet` ou ce CIDR LAN ; en cas de conflit multi-utilisateurs, alerte explicite dans le diagnostic / Diff Visuel sans élargissement silencieux).

* **⏳ Avant Février 2027 — Optimisation Android DEX / R8 & ProGuard (Play Console)** :
  - Activer `isMinifyEnabled = true` et `isShrinkResources = true` dans [build.gradle.kts](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/android/app/build.gradle.kts) avec un `proguard-rules.pro` vérifié pour `workmanager`, `flutter_local_notifications`, `flutter_secure_storage`, `local_auth`, et tester en APK `--release` sur appareil physique avant upload `.aab` (`mapping.txt`).
* **🔮 Post-`0.30` (avant suppression `/api/v1` en `0.33`) — Migration `/api/headscale/v0`** :
  - Pagination (`pageSize=1000`), `ETag`/`If-Match`, `PUT /policy?dryRun=true`, `GET /whoami`, et gestion `owner_conflict` / `tags_not_permitted`.
