# Sous-Plan d'Action 09-C — 4ème Moteur `Sans Tags` (`AclEngineMode.tagless`) & Adaptation de Tous les Constructeurs Manuels

**Date de création** : 17 novembre 2026  
**Version cible** : `2.6.0+165` *(Étape 4.C — voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Branche Git dédiée** : `feat/acl-09-c-tagless-and-builders` *(créée depuis `master` après merge de `09-B`)*  
**Prérequis** : Sous-Plans `09-0`, `09-A` et `09-B` validés et mergés  
**Plan parent** : [plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md)  
**Niveau de risque** : 🟡 **Moyen** *(ajoute le 4ème moteur opt-in et enrichit le Composeur, la Vue Puzzle, les Règles Spécifiques et l'éditeur SSH)*

---

## 1. Objectif du Sous-Plan 09-C

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

## 2. Détails Techniques

### Tâche 09-C.1 — Le 4ème Moteur `AclEngineMode.tagless` & `TaglessAclGeneratorService`
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

---

### Tâche 09-C.2 — Adaptation des 4 Constructeurs Manuels à l'Hybridation & au Mode Sans Tags

#### 1. Composeur Guidé & Éditeur de Grants (`GrantComposerService`, `GrantComposerSheet`, `GrantEditSheet`, `GrantsV29Gate`)
- **`GrantsV29Gate.isAvailable`** : autoriser l'ouverture du Composeur et de l'Éditeur de Grants sur tout serveur Headscale $\ge 0.29.0$ en mode `grantsV29` **OU `tagless`** (et même en `standard` si la policy contient des `grants`).
- **`GrantComposerService.sourceTagOptions()`** :
  - Pour chaque utilisateur :
    - S'il possède uniquement des machines taguées $\rightarrow$ proposer `tag:<user>-client`.
    - S'il possède uniquement des machines sans tags $\rightarrow$ proposer `group:<user>` *(ex: `group:jean — Appareils de Jean (sans tag)`)*.
    - S'il possède un parc **hybride** (machines taguées + machines sans tags) $\rightarrow$ proposer `group:<user>`, `tag:<user>-client`, ainsi que les machines individuelles sans tags via leur alias `host-<user>-<machine>`.
- **`GrantComposerService.routerOptions()` & Étape `via` dans `GrantComposerSheet`** :
  - Si le routeur choisi (Exit Node ou LAN) possède un tag (`tag:<user>-lan-sharer`), remplir `"via": [viaTag]`.
  - Si le routeur choisi est **sans tag**, afficher dans le composeur : *"Routeur sans tag (${node.name}) — Routage direct sans via"* et construire le Grant sans clé `"via"` (car Headscale interdit `group:` ou `host` dans `"via"`).
- **`GrantComposerService.destinationOptions()`** :
  - En mode `intraFleet` ou `targetedIp` : proposer `group:<user>`, `tag:<user>-client`, ainsi que chaque machine sans tag via son alias **`host-<user>-<machine>`** (en plus de son IP).

#### 2. Vue Puzzle (`AclPuzzleScreen` & `AclPuzzleService`)
- Dans `lib/screens/acl_puzzle_screen.dart` (`_buildAvailableEntities`) :
  - **Corriger le bug de normalisation** : remplacer `'group:${user.name}'` par `'group:${normalizeUserName(user.name)}'` !
  - Ajouter dans la palette des briques Puzzle chaque machine sans tag sous la forme d'une entité `PuzzleEntityType.host` ayant pour valeur son alias `host-<normUser>-<sanitizedNodeName>` et pour libellé `"Appareil : ${node.name} (${user.name})"`.
- Dans `lib/services/acl_puzzle_service.dart` :
  - Mettre à jour `_inferType(String value)` pour reconnaître toute clé commençant par `host-` ou présente dans `basePolicy['hosts']` comme `PuzzleEntityType.host`.
  - En mode `tagless` sur Headscale $\ge 0.29.0$, passer `emitGrants: true` lors de la sauvegarde depuis le Puzzle, tout en conservant les commentaires HuJSON `// nom de la règle`.

#### 3. Constructeur "Autorisations Spécifiques / Exceptions manuelles" (`AclScreen._buildTemporaryRulesSection`)
- Dans `lib/screens/acl_screen.dart` :
  - Utiliser `PolicyInfrastructureBuilder.nodeBelongsToUser` pour identifier le propriétaire de chaque nœud (corrige le filtre Source $\neq$ Destination pour les nœuds OIDC sans tags).
  - Permettre de cibler un nœud sans tag via son alias `host-<user>-<machine>` (ou son IP) dans `_temporaryRules`.

#### 4. Constructeur Tailscale SSH (`SshRulesListView` & `SshRuleDialog`)
- Dans `lib/widgets/acl/ssh_rules_list_view.dart` :
  - Ajouter un bouton d'insertion rapide **"⚡ Modèle Sans Tag : SSH vers ses propres appareils (`autogroup:member` → `autogroup:self`)"** qui pré-remplit une règle SSH conforme aux exigences Tailscale/Headscale pour les machines appartenant à un utilisateur humain (`src: ["autogroup:member"], dst: ["autogroup:self"], users: ["autogroup:nonroot", "root"]`).
  - Dans `SshRuleDialog`, proposer les `group:<user>` en source et destination (avec rappel visuel que pour une cible `group:<user>`, Tailscale SSH impose `src == dst` ou `dst == autogroup:self`).

#### 5. Filtre intelligent dans `AclScreen._preserveCustomRulesOnRegenerate`
- Lorsqu'un administrateur change volontairement de moteur (ex: `Grants V29` $\rightarrow$ `Sans Tags`) et clique sur **"Générer Politique"**, ne pas considérer les anciennes règles purement auto-générées intra-utilisateur (`src == dst` du même user) comme des règles personnalisées à empiler, mais **conserver 100 % des règles inter-utilisateurs, règles Composeur, règles Puzzle et exceptions de ports** !

---

## 3. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/services/acl/tagless_acl_generator.dart` | Générateur 4ème mode `Sans Tags` (`grants` $\ge 0.29$, `acls` $< 0.29$, `hosts`, tolérance hybride) |
| **Modifié** | `lib/models/acl_engine_mode.dart` | Ajout de `AclEngineMode.tagless` |
| **Modifié** | `lib/services/acl/acl_policy_orchestrator.dart` | Routage `AclEngineMode.tagless` vers `TaglessAclGeneratorService` |
| **Modifié** | `lib/screens/home_screen.dart` & `lib/providers/app_provider.dart` | Bloquer la popup/bascule auto `Grants V29` si mode `tagless` |
| **Modifié** | `lib/utils/grants_v29_gate.dart` | Ouvrir le Composeur/Éditeur de Grants au mode `tagless` ($\ge 0.29$) |
| **Modifié** | `lib/services/acl/grant_composer_service.dart` | Options `group:<user>`, `host-<user>-<node>` et routeurs sans tags |
| **Modifié** | `lib/widgets/acl/grant_composer_sheet.dart` & `grant_edit_sheet.dart` | Étape `via` optionnelle si routeur sans tag + sélection `group:` / `host-` |
| **Modifié** | `lib/screens/acl_puzzle_screen.dart` & `lib/services/acl_puzzle_service.dart` | Normalisation `group:`, briques `host-<user>-<node>`, support `emitGrants` en `tagless` $\ge 0.29$ |
| **Modifié** | `lib/widgets/acl/ssh_rules_list_view.dart` | Modèle rapide SSH sans tag (`autogroup:self`) |
| **Modifié** | `lib/screens/acl_screen.dart` | Adaptation exceptions manuelles + filtre anti-doublon dans `_preserveCustomRulesOnRegenerate` |
| **Modifié** | `lib/screens/settings_screen.dart` & `lib/widgets/acl/acl_engine_banner.dart` | Sélecteur du 4ème mode *"Sans Tags (Utilisateurs)"* + toggle d'inclusion hybride |
| **Tests** | `test/services/acl/tagless_acl_generator_test.dart` | Tests unitaires complets du moteur `tagless` ($\ge 0.29$ et $< 0.29$), du Composeur et du Puzzle *(Nouveau)* |

---

## 4. Gate de Validation `09-C`
- [ ] `flutter analyze` $\rightarrow$ `0 issue`.
- [ ] Tests unitaires `tagless_acl_generator_test.dart` $\rightarrow$ `100% OK`.
- [ ] Tester le sélecteur **Paramètres > Moteur ACL > Sans Tags (Utilisateurs)** : aucune popup `Grants V29` intempestive au redémarrage.
- [ ] Tester la génération en mode `Sans Tags` : vérifier dans le Diff Visuel que `groups`, `hosts` (`host-<user>-<node>`), `autoApprovers` et `grants` sont propres et que les machines déjà taguées restent incluses sans coupure.
- [ ] Tester le **Composeur de règles**, la **Vue Puzzle**, les **Règles Spécifiques** et l'**Onglet SSH** avec des appareils sans tags.
