# Sous-Plan d'Action 09-C — 4ème Moteur `Sans Tags` (`AclEngineMode.tagless`) & Adaptation de Tous les Constructeurs Manuels

**Date de création** : 17 novembre 2026 *(Audit complet & découpage en 2 lots : 18 novembre 2026)*  
**Version cible** : `2.6.0+170` *(Étape 4.C — Publication publique #2 ; voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Branche Git dédiée** : `feat/acl-09-c-tagless-and-builders` *(créée depuis `master` après publication `2.5.2+169`)*  
**Prérequis** : Sous-Plans `09-0`, `09-A` et `09-B` validés, mergés et publiés (`2.5.2+169`)  
**Plan parent** : [plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md)  
**Niveau de risque** : 🟡 **Moyen** *(ajoute le 4ème moteur opt-in, couvre toutes les combinaisons Taggé/Sans Tag/Hybride × Grants/Classique, adapte les règles tierces dépendantes et tous les constructeurs manuels)*

---

## 1. Objectif & Matrice de Compatibilité Complète du Sous-Plan 09-C

### 1.1. Matrice des 8 architectures supportées (Zéro régression si l'admin ne change pas d'architecture)
| Moteur sélectionné | Serveur Headscale | Parc 100 % Taggé | Parc Hybride (Taggé + Sans Tag) | Parc 100 % Sans Tag / OIDC |
|---|---|---|---|---|
| **Legacy** (`legacy`) | Toutes versions | `acls` tags `;` fusionnés | `acls` tags `;` | Non applicable |
| **Standard** (`standard`) | `< 0.29` ou `>= 0.29` (choix admin `acls`) | `acls` `tag:<user>-*` + `group:<user>` → `tag:*` | `acls` union `[tag:<user>-*, group:<user>]` + `hosts` | `acls` `group:<user>` + `hosts` |
| **Grants V29** (`grantsV29`) | `>= 0.29` *(fallback `standard` si `< 0.29`)* | `grants` `tag:<user>-*` avec `via` | `grants` union `[tag:<user>-*, group:<user>]`, `via` si routeur tagué / direct si routeur sans tag | `grants` `group:<user>` direct + `hosts` |
| **Sans Tags** (`tagless`) **[Nouveau]** | `>= 0.29` $\rightarrow$ **`grants`**<br>`< 0.29` $\rightarrow$ **`acls`** | Tolérance hybride (`[group:<user>, ...activeTags]`, `tagOwners` actifs conservés) | Union `[group:<user>, ...activeTags]`, `tagOwners` limité aux seuls tags actifs | Pur `group:<user>` + `hosts` (`host-<user>-<node>`), `tagOwners: {}` vide |

1. Introduire le 4ème moteur officiel **`AclEngineMode.tagless` ("Sans Tags — Utilisateurs")**, capable de générer :
   - Des **`grants`** si le serveur est en Headscale $\ge 0.29.0$.
   - Des **`acls`** si le serveur est en Headscale $< 0.29.0$.
   - Tout en conservant une **tolérance hybride automatique** si certaines machines du parc portent encore d'anciens tags !
2. **Adapter tous les constructeurs de règles manuelles** de l'application pour qu'ils fonctionnent aussi bien avec des tags, sans tags, ou en mode hybride :
   - **Composeur Guidé de Grants (`GrantComposerSheet` & `GrantEditSheet`)**
   - **Vue Puzzle (`AclPuzzleScreen` & `AclPuzzleService`)**
   - **Règles Spécifiques / Exceptions (`AclScreen._buildTemporaryRulesSection`)**
   - **Constructeur Tailscale SSH (`SshRulesListView`)**

---

## 2. Détails Techniques (Découpage Sûr en 2 Lots)

> [!IMPORTANT]
> **Principe zéro-régression :** Les 3 moteurs existants (`Legacy`, `Standard`, `Grants V29`) restent **strictement inchangés**. Aucun comportement existant ne change tant que l'administrateur ne sélectionne pas explicitement le 4ème moteur `Sans Tags` (`AclEngineMode.tagless`).

### Lot 1 — Tâche 09-C.1 : Le 4ème Moteur `AclEngineMode.tagless` Isolé & Sélecteur UI
*(Ce lot n'affecte ni `PolicyPreserver`, ni le Composeur, ni le Puzzle.)*
- Ajouter `tagless` à l'enum `AclEngineMode` dans `lib/models/acl_engine_mode.dart`.
- Créer `lib/services/acl/tagless_acl_generator.dart` et le brancher dans `lib/services/acl/acl_policy_orchestrator.dart` :
  - **`groups`** : construit `group:<normUser>` avec `resolveAclGroupMembers` (`"user@"` + email OIDC).
  - **`hosts`** : génère les alias DNS-1123 `"host-<normUser>-<sanitizedNodeName>": "<ipv4>"` pour chaque machine sans tag (permettant de cibler une machine individuelle dans les constructeurs manuels).
  - **`autoApprovers`** : déclare `group:<normUser>` (et les éventuels tags résiduels si parc en cours de transition) pour les routes partagées.
  - **`tagOwners`** : n'émet des `tagOwners` que pour les machines qui possèdent encore effectivement un tag sur le serveur (zéro bruit inutile si le parc est 100 % sans tag, zéro coupure s'il reste des machines taguées).
  - **Règles (`grants` si serveur $\ge 0.29.0$, sinon `acls`)** :
    - Pour chaque utilisateur ayant au moins un nœud :
      - Sujets de l'utilisateur : `["group:<normUser>", ...activeUserTags]` (tolérance hybride intégrée).
      - Autorise la communication intra-utilisateur, l'Exit Node (`autogroup:internet`) et les routes LAN partagées (avec `via` si le routeur a encore un tag sur $\ge 0.29$, ou sans `via` s'il est sans tag).
    - Intègre les partages `TaildriveBuilder` et les `temporaryRules`.
- **Suppression de la popup/bascule forcée vers `Grants V29`** :
  - Dans `lib/screens/home_screen.dart` (`_checkForGrantsMigration`) et `lib/providers/app_provider.dart` (`_maybeAutoEnableGrantsEngine`) : ne jamais déclencher la popup ou la bascule automatique vers `Grants V29` si le serveur est configuré en `AclEngineMode.tagless` (ou si un moteur explicite a été enregistré pour ce serveur).
- **Intégration UI du sélecteur `Sans Tags`** :
  - `SettingsScreen` & `AclEngineBanner` : 4ème mode *"Sans Tags (Utilisateurs)"* (`AclEngineMode.tagless`) avec badge/couleur dédiés et mention du format actif (`Grants ≥ 0.29` ou `ACLs < 0.29`).
  - `AclMigrationCenterScreen` (Onglet 3 — Parcours C Serveur) : ajouter le bouton **"Appliquer Sans Tags (Diff)"** aux côtés de `Grants V29` et `Standard`.
  - `AlignmentDiagnosticService._checkEngineVersionCompatibility` : prendre en charge `AclEngineMode.tagless` (`grants` sur $\ge 0.29$, `acls` sur $< 0.29$).

---

### Lot 2 — Tâche 09-C.2 : Adaptation des 4 Constructeurs Manuels & `PolicyPreserver` Sécurisé

#### 1. Composeur Guidé & Éditeur de Grants (`GrantComposerService`, `GrantComposerSheet`, `GrantEditSheet`, `GrantsV29Gate`, `GrantsMigrationBanner`)
- **`GrantsV29Gate.isAvailable`** : autoriser l'ouverture du Composeur et de l'Éditeur de Grants sur tout serveur Headscale $\ge 0.29.0$ en mode `grantsV29` **OU `tagless`**.
- **`GrantsMigrationBanner`** : n'afficher le bandeau *"Policy migrée en Grants V29"* que si `engineMode == AclEngineMode.grantsV29` (ne pas l'afficher en mode `tagless`).
- **`GrantComposerService.sourceTagOptions()`** :
  - Pour chaque utilisateur :
    - S'il possède uniquement des machines taguées $\rightarrow$ proposer `tag:<user>-client`.
    - S'il possède uniquement des machines sans tags $\rightarrow$ proposer `group:<user>` *(ex: `group:jean — Appareils de Jean (sans tag)`)*.
    - S'il possède un parc **hybride** (machines taguées + machines sans tags) $\rightarrow$ proposer `group:<user>`, `tag:<user>-client`, ainsi que les machines individuelles sans tags via leur alias `host-<user>-<machine>`.
- **`GrantComposerService.routerOptions()` & Étape `via` dans `GrantComposerSheet`** :
  - Inclure à la fois les routeurs **tagués** (`viaTag: 'tag:<user>-lan-sharer'` / `'tag:<user>-exit-node'`) ET les routeurs **sans tag** (`viaTag: ''`, `selectionKey: 'direct:${node.id}'`, `isTagless: true`).
  - Si le routeur choisi possède un tag, remplir `"via": [viaTag]`.
  - Si le routeur choisi est **sans tag**, débloquer le bouton *Suivant* à l'étape 2, afficher *"Routeur sans tag (${node.name}) — Routage direct sans via"*, conserver le filtre de sous-réseaux LAN de ce routeur à l'étape 3 (`_routerOwnerNorm()`), et construire le Grant sans clé `"via"` (car Headscale interdit `group:` ou `host` dans `"via"`).
- **`GrantComposerService.destinationOptions()`** :
  - Passer `users` pour résoudre les propriétaires OIDC via `PolicyInfrastructureBuilder.findOwnerUser` et `buildManagedHosts`.
  - En mode `intraFleet` ou `targetedIp` : proposer `group:<user>`, `tag:<user>-client`, ainsi que chaque machine sans tag via son alias **`host-<user>-<machine>`** (en plus de son IP).
- **`GrantEditSheet`** :
  - Préserver dans la liste `Source(s)` toute entrée `src` déjà présente dans le grant édité (`uniqueSrc`, symétrique à `uniqueDst`) pour éviter toute perte silencieuse lors de l'édition d'un grant personnalisé.

#### 2. Vue Puzzle (`AclPuzzleScreen` & `AclPuzzleService`)
- Dans `lib/screens/acl_puzzle_screen.dart` (`_buildAvailableEntities`, `_applyPolicy`, `_RuleEditorDialog`) :
  - **Corriger le bug de normalisation** : remplacer `'group:${user.name}'` par `'group:${normalizeUserName(user.name)}'` !
  - Ajouter dans la palette des briques Puzzle chaque machine sans tag sous la forme d'une entité `PuzzleEntityType.host` (`id: 'host_${node.id}'`) ayant pour valeur son alias `host-<normUser>-<sanitizedNodeName>` et pour libellé `"Appareil : ${node.name} (${ownerName})"`.
  - Dans `_buildEntityList` : n'afficher les briques routeurs `router_*` (`viaTag`) qu'à l'étape `VIA` (`_currentStep == 1 && useGrants`), et n'afficher les briques appareils `host_*` (`host-<user>-<node>`) qu'aux étapes `Source` et `Destination`.
  - **Corriger `useGrants` et `emitGrants`** : activer le mode Grants dans le Puzzle si `(aclEngineMode == AclEngineMode.grantsV29 || aclEngineMode == AclEngineMode.tagless) && VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0')`.
  - **Corriger `isGrant` à la création d'une pièce (`_RuleEditorDialog`)** : lorsque `useGrants == true`, toute nouvelle pièce créée doit avoir `isGrant: true` (même sans `via` et même vers un `group:` / `tag:` / `host-`), afin d'être émise dans `"grants"` et non dans `"acls"`.
- Dans `lib/services/acl_puzzle_service.dart` :
  - Mettre à jour `_inferType(String value)` pour reconnaître toute clé commençant par `host-` ou présente dans `basePolicy['hosts']` comme `PuzzleEntityType.host`.
  - En mode `tagless` sur Headscale $\ge 0.29.0$, passer `emitGrants: true` lors de la sauvegarde depuis le Puzzle, tout en conservant les commentaires HuJSON `// nom de la règle`.

#### 3. Constructeur "Autorisations Spécifiques / Exceptions manuelles" (`AclScreen._buildTemporaryRulesSection`)
- Dans `lib/screens/acl_screen.dart` :
  - Utiliser `PolicyInfrastructureBuilder.findOwnerUser` / `nodeBelongsToUser` pour identifier le propriétaire de chaque nœud (corrige le filtre Source $\neq$ Destination pour les nœuds OIDC sans tags).
  - Permettre de cibler un nœud sans tag via son IP (ou son alias `host-<user>-<machine>`) dans `_temporaryRules`.

#### 4. Constructeur Tailscale SSH (`SshRulesListView` & `SshRuleDialog`)
- Dans `lib/widgets/acl/ssh_rules_list_view.dart` :
  - Ajouter un bouton d'insertion rapide **"⚡ Modèle Sans Tag : SSH vers ses propres appareils (`autogroup:member` → `autogroup:self`)"** qui pré-remplit une règle SSH conforme aux exigences Tailscale/Headscale pour les machines appartenant à un utilisateur humain (`action: "accept", src: ["autogroup:member"], dst: ["autogroup:self"], users: ["autogroup:nonroot", "root"]`).
  - Dans `SshRuleDialog`, proposer les `group:<user>` en source et destination (avec rappel visuel que pour une cible `group:<user>`, Tailscale SSH impose `src == dst` ou `dst == autogroup:self`).

#### 5. Préservation Intelligente, Bascule d'un Routeur Tiers (`Exit Node` / `LAN`) en Sans Tag & Filtre Anti-Doublon (`PolicyPreserver` & `AclScreen._preserveCustomRulesOnRegenerate`)
- **Ordre d'exécution dans `PolicyPreserver.extractExtraCustomRules`** :
  - Exécuter la réécriture/hybridation des règles personnalisées **avant** `_hasValidRuleReferences`, afin qu'une règle référençant `tag:<user>-client` ne soit jamais supprimée lorsque `tagOwners` est épuré en mode `tagless` ou quand `<user>` passe à 100 % sans tag.
  - Si un utilisateur `<user>` a **0 nœud tagué** (100 % sans tag), **remplacer** `tag:<user>-client` par `group:<user>` dans `src`/`dst`. S'il est en **parc mixte** (nœuds tagués + sans tag), conserver l'union `[tag:<user>-client, group:<user>]`.
- **Adaptation automatique des règles tierces quand un routeur (`Exit Node` / `LAN`) passe à 100 % sans tag (avec garde-fou anti-élargissement)** :
  - Si une règle personnalisée d'un utilisateur tiers contient `via: ["tag:<tiers>-exit-node"]` ou `via: ["tag:<tiers>-lan-sharer"]` (ou cible ce tag routeur dans `src`/`dst`), et que `<tiers>` n'a plus aucun nœud portant ce tag mais possède désormais son Exit Node ou routeur LAN **sans tag** :
    - Dans `grants['via']` : retirer automatiquement le `via` devenu obsolète pour basculer le Grant en routage direct (Headscale `0.29+` interdisant `group:`/`host` dans `via`) **uniquement s'il n'existe aucune ambiguïté** (un seul utilisateur du parc publie `autogroup:internet` ou ce CIDR LAN). **En cas de conflit** (plusieurs utilisateurs avec Exit Node ou même CIDR LAN), **ne jamais élargir l'accès silencieusement** : conserver le signalement pour alerter l'administrateur dans le diagnostic / Diff Visuel.
    - Dans `src`/`dst` (`grants` ou `acls`) : remplacer `tag:<tiers>-exit-node` / `tag:<tiers>-lan-sharer` par `group:<tiers>`.
- **Filtre anti-doublon lors d'un changement de moteur (`Standard` $\leftrightarrow$ `Grants V29` $\leftrightarrow$ `Sans Tags`)** :
  - Ne filtrer comme « ancienne règle auto-générée » **que** les règles correspondant strictement au gabarit par défaut (`action: accept`, sans `proto`, sans `app`, ports `*` uniquement, où tous les `src` et tous les `dst`/routes appartiennent au **même** utilisateur).
  - Lorsque le type de moteur (`acls` vs `grants`) ne change pas, ne rien filtrer de plus que la subsomption existante.
  - **Conserver 100 % des règles inter-utilisateurs, règles Composeur, règles Puzzle et exceptions avec ports/protocoles/IPs personnalisés**.

*(L'intégration UI de `SettingsScreen`, `AclEngineBanner`, Parcours C et `AlignmentDiagnosticService` est réalisée dès le **Lot 1 — Tâche 09-C.1**.)*

---

## 3. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/services/acl/tagless_acl_generator.dart` | Générateur 4ème mode `Sans Tags` (`grants` $\ge 0.29$, `acls` $< 0.29$, `hosts`, tolérance hybride) |
| **Modifié** | `lib/models/acl_engine_mode.dart` | Ajout de `AclEngineMode.tagless` |
| **Modifié** | `lib/services/acl/acl_policy_orchestrator.dart` | Routage `AclEngineMode.tagless` vers `TaglessAclGeneratorService` |
| **Modifié** | `lib/screens/home_screen.dart` & `lib/providers/app_provider.dart` | Bloquer la popup/bascule auto `Grants V29` si mode `tagless` |
| **Modifié** | `lib/utils/grants_v29_gate.dart` & `lib/widgets/acl/grants_migration_banner.dart` | Ouvrir le Composeur/Éditeur de Grants au mode `tagless` ($\ge 0.29$) sans afficher la bannière de migration `Grants V29` en mode `tagless` |
| **Modifié** | `lib/services/acl/policy_preserver.dart` | Hybridation avant `_hasValidRuleReferences`, remplacement des tags morts (`0` nœud tagué), adaptation auto des routeurs tiers (`Exit Node`/`LAN`) passés sans tag, et filtre anti-doublon inter-moteurs |
| **Modifié** | `lib/services/acl/grant_composer_service.dart` | Options `group:<user>`, `host-<user>-<node>` et routeurs sans tags (`direct:<nodeId>`) |
| **Modifié** | `lib/widgets/acl/grant_composer_sheet.dart` & `grant_edit_sheet.dart` | Étape `via` supportant les routeurs sans tag + filtre LAN du propriétaire + préservation `uniqueSrc` |
| **Modifié** | `lib/screens/acl_puzzle_screen.dart` & `lib/services/acl_puzzle_service.dart` | Normalisation `group:`, briques `host-<user>-<node>`, séparation `router_*` vs `host_*`, `isGrant: useGrants` et `emitGrants` en `tagless` $\ge 0.29$ |
| **Modifié** | `lib/widgets/acl/ssh_rules_list_view.dart` | Modèle rapide SSH sans tag (`autogroup:member` $\rightarrow$ `autogroup:self`) |
| **Modifié** | `lib/screens/acl_screen.dart` | Adaptation exceptions manuelles (`nodeBelongsToUser`) + préservation inter-moteurs dans `_preserveCustomRulesOnRegenerate` |
| **Modifié** | `lib/screens/settings_screen.dart`, `lib/widgets/acl/acl_engine_banner.dart`, `lib/screens/acl_migration_center_screen.dart` & `lib/services/acl/alignment_diagnostic_service.dart` | Sélecteur du 4ème mode *"Sans Tags (Utilisateurs)"*, bouton Parcours C et diagnostic de compatibilité |
| **Tests** | `test/services/acl/tagless_acl_generator_test.dart` | Tests unitaires complets (8 architectures : Taggé / Sans Tag / Hybride $\times$ `< 0.29` / $\ge 0.29$, routeur tiers passé sans tag, Composeur, Puzzle) *(Nouveau)* |

---

## 4. Point de Contrôle de Validation `09-C` (Stratégie en 2 Niveaux avant Publication Publique #2 `2.6.0`)

### Niveau A — Tests Automatisés (`flutter analyze` + `flutter test`) : couverture des 8 architectures
- [ ] `flutter analyze` $\rightarrow$ `0 issue`.
- [ ] Tests unitaires `tagless_acl_generator_test.dart` (vérifiés par `AclParserService`) couvrant :
  1. Serveur `< 0.29` (`0.28.0`) et `>= 0.29` (`0.29.2`) en `Legacy`, `Standard`, `Grants V29` et `Sans Tags` (`tagless`).
  2. Parcs `100 % Taggé`, `100 % Sans Tag` et `Hybride`.
  3. Non-régression stricte des sorties `Grants V29`, `Standard` et `Legacy` existantes.
  4. Routeur tiers (`Exit Node` / `LAN`) basculé à 100 % sans tag : retrait `via` sans ambiguïté **ET** refus d'élargissement silencieux en cas de conflit multi-Exit-Node ou multi-LAN CIDR.
  5. Préservation inter-moteurs des règles Composeur, Puzzle, SSH et exceptions à ports/protocoles/IPs personnalisés.

### Niveau B — Tests Appareil en Piste Interne (`2.6.0`)
- [ ] **Non-régression sur l'architecture actuelle (`Grants V29` hybride)** : ouvrir *ACLs → Générer Politique* et vérifier dans le **Diff Visuel** qu'aucune règle existante n'est altérée ou perdue.
- [ ] **Test à blanc du mode `Sans Tags` (sans exporter)** : activer temporairement *Paramètres > Moteur ACL > Sans Tags (Utilisateurs)*, vérifier l'absence de popup `Grants V29`, cliquer sur *Générer Politique*, inspecter le JSON / Diff Visuel (`groups`, `hosts` `host-<user>-<node>`, `tagOwners` épuré, `grants` + machines taguées conservées), puis annuler sans publier et revenir au moteur d'origine.
- [ ] **Test UI des constructeurs manuels** : tester le **Composeur de Grants** (routeur tagué et routeur sans tag), la **Vue Puzzle** (`group:` normalisé + briques `host-*`), les **Règles Spécifiques** et l'**Onglet SSH** (`autogroup:member` → `autogroup:self`) avant export.
