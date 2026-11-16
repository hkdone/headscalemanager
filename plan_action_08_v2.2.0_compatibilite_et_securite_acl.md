# Plan d'Action 08 — Version 2.2.0 : Compatibilité Multi-Versions (v0.22–v0.29.7+), Fusion Non-Destructive & Cohérence des Tags

**Date de création** : 16 novembre 2026  
**Version cible** : `2.2.0+156` *(actuelle : `2.1.9+155`)*  
**Branche Git dédiée** : `fix/v2.2.0-compat-non-destructive-acl` *(créée depuis `master`)*  
**Priorité** : **P0 — Critique (Stabilité & Zéro Coupure en Production)**  
**Niveau de risque global** : 🟡 **Moyen** *(touche au pipeline d'export ACL et aux tags, sécurisé par fusion conservatrice et garde-fous)*

---

## 1. Objectif

Sécuriser et fiabiliser les mécanismes existants pour les administrateurs utilisant des versions hétérogènes de Headscale (`0.22` à `0.29.7+`) **sans modifier leur stratégie réseau actuelle et sans couper le trafic VPN en production** :

1. **Ne plus écraser les blocs manuels** (`ssh`, `tests`, `ipsets`, `derpMap`, `randomizeClientPort`, `hosts`, `nodeAttrs` non-Taildrive) présents sur le serveur lors d'une régénération d'ACL depuis l'application.
2. **Corriger les injections de tags Legacy (`;exit-node`, `;lan-sharer`)** dans les écrans/dialogues qui ignorent encore le moteur actif (`standard` ou `grantsV29`) ou qui nettoient mal les tags séparés `tag:<user>-lan-sharer`.
3. **Permettre les sous-réseaux identiques (ex: `192.168.1.0/24`) en mode `Grants V29`** (Headscale ≥ 0.29), actuellement bloqués à tort par `RouteConflictService`.
4. **Supporter intégralement le format HuJSON** (commentaires `//`, `/* ... */` et virgules finales `, }` / `, ]`) lors de la lecture/importation de politiques.
5. **Corriger les appels API `PreAuthKey` sur Headscale ≥ 0.28** (`serverVersion` non transmis) et l'encodage des paramètres d'URL.

---

## 2. Prise en compte de la Production Hétérogène (Zéro Coupure)

> [!IMPORTANT]
> **Garanties de non-régression pour les parcs en production :**
> - Aucun serveur existant ne change automatiquement de moteur ACL (`legacy`, `standard`, `grantsV29`).
> - Les nœuds déjà tagués en format `;` sur un serveur `legacy` gardent exactement ce format.
> - Si la récupération de la politique distante échoue avant une sauvegarde (ex: erreur réseau ou serveur vierge sans policy), l'application **avertit l'utilisateur** avant d'appliquer un remplacement complet.
> - En mode `legacy` ou `standard`, `RouteConflictService` **maintient** le blocage strict sur les CIDR dupliqués afin d'empêcher tout routage ambigu.

---

## 3. Détails Techniques

### Tâche 08.1 — Fusion Non-Destructive des Politiques (`PolicyPreserver`)
- Créer un helper `lib/services/acl/policy_preserver.dart` :
  - Prend en entrée `Map<String, dynamic> generatedPolicy` et `Map<String, dynamic>? serverPolicy`.
  - Préserve intégralement toutes les clés hors périmètre du générateur : `ssh`, `tests`, `ipsets`, `derpMap`, `randomizeClientPort`, ainsi que toute clé future inconnue.
  - Fusionne `hosts` : conserve les entrées manuelles du serveur et ajoute uniquement les nouvelles clés sans écraser l'existant.
  - Fusionne `nodeAttrs` : conserve les entrées existantes ne portant pas `drive:share` / `drive:access`, et y ajoute les `nodeAttrs` produits par `TaildriveBuilder`.
- Avant tout appel automatique à `setAclPolicy` (approbation depuis `DashboardScreen`, sauvegarde de routes dans `NodeDetailScreen`, `EditTagsDialog`, `ExitNodeCommandDialog`, `ShareSubnetDialog`, `MoveNodeDialog`, `AclScreen`, `AclPuzzleScreen`), récupérer d'abord la politique serveur via `getAclPolicy()`, la parser via `JsonUtils.cleanJsonComments()`, puis appeler `PolicyPreserver.merge(...)`.

### Tâche 08.2 — Centralisation et Correction de la Gestion des Tags (`TagCapabilityHelper`)
- Créer `lib/utils/tag_capability_helper.dart` pour supprimer les 4 copies divergentes de `_addCapabilities` / `_removeCapabilities` / `_cleanupObsoleteLanSharerTags`.
- Comportement piloté par `AclEngineMode` :
  - `AclEngineMode.legacy` : fusionne dans `tag:<user>-client;exit-node;lan-sharer`.
  - `AclEngineMode.standard` et `AclEngineMode.grantsV29` : manipule des tags séparés `tag:<user>-client`, `tag:<user>-exit-node`, `tag:<user>-lan-sharer`.
- **Correction spécifique** : `_removeCapabilities` doit aussi supprimer `tag:<user>-lan-sharer` (et pas seulement `tag:lan-sharer` ou `;lan-sharer` comme actuellement dans `dashboard_screen.dart:344`, `acl_screen.dart:1744`, `node_detail_screen.dart:1098`, `acl_puzzle_screen.dart:501`).
- Mettre à jour `registration_dialogs.dart` (`_showAddTagsDialog`, lignes 717-726) et `create_pre_auth_key_dialog.dart` (lignes 165-173) pour générer le format de tags correspondant au moteur actif du serveur.
- Mettre à jour `move_node_dialog.dart` (lignes 47-63) pour réattribuer aussi les tags séparés `-exit-node` et `-lan-sharer` lors d'un déplacement sur serveur < 0.26.

### Tâche 08.3 — Validation Contextuelle des Conflits de Routes (`RouteConflictService`)
- Enrichir `RouteConflictService.validateRouteApproval` avec `AclEngineMode engineMode` et `String? serverVersion`.
- Si `engineMode == AclEngineMode.grantsV29` et `VersionInfo.checkVersionAtLeast(serverVersion ?? '', '0.29.0')` :
  - Même route sur un **autre utilisateur** $\rightarrow$ retourner un nouvel état `RouteValidationType.warningSharedVia` (autorisé, avec message expliquant l'isolation par `via`).
  - Même route sur le **même utilisateur** $\rightarrow$ avertissement informatif HA/Failover (autorisé).
- Sinon (`legacy`, `standard`, ou serveur < 0.29) $\rightarrow$ maintien du blocage strict (`RouteValidationType.conflict`).
- **Garde-fou Rollback** : dans `SettingsScreen` lors du *Rollback Grants → Standard*, vérifier s'il existe des CIDR dupliqués entre utilisateurs ; si oui, afficher un avertissement bloquant ou explicite avant de repasser en `Standard`.

### Tâche 08.4 — Parseur HuJSON Complet (`JsonUtils`)
- Remplacer `JsonUtils.cleanJsonComments` par un parseur lexical caractère par caractère qui :
  1. Préserve intact le contenu des chaînes `"..."` (en gérant `\"` et `\\`).
  2. Retire les commentaires `//...` et `/* ... */` hors chaînes.
  3. Retire les virgules finales (*trailing commas*) avant `}` ou `]` hors chaînes.
- Appliquer systématiquement `JsonUtils.cleanJsonComments` dans `AclScreen._fetchAclPolicyFromServer()` (ligne 1360) et `HeadscaleApiService.setAclPolicy()` (ligne 167).

### Tâche 08.5 — Compatibilité API `PreAuthKey` v0.28+ & Encodage URL
- Transmettre `serverVersion: appProvider.serverVersion` et `keyId` dans :
  - `lib/screens/pre_auth_keys_screen.dart` (lignes 31 et 174)
  - `lib/screens/client_commands_screen.dart` (ligne 50)
  - `lib/widgets/delete_pre_auth_key_dialog.dart` (ligne 47)
- Utiliser `Uri.encodeComponent(...)` sur les paramètres interpolés dans `HeadscaleApiService` (`registerMachine`, `renameNode`, `renameUser`, `deleteApiKey`, `getPreAuthKeys`).

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/services/acl/policy_preserver.dart` | Fusion non-destructive des clés serveur (`ssh`, `tests`, `hosts`, `ipsets`, `derpMap`, `nodeAttrs`) |
| **Nouveau** | `lib/utils/tag_capability_helper.dart` | Gestion unifiée des tags Legacy vs Standard/GrantsV29 + nettoyage |
| **Modifié** | `lib/utils/json_utils.dart` | Support HuJSON complet (`//`, `/* */`, trailing commas) |
| **Modifié** | `lib/services/route_conflict_service.dart` | Autorisation sous avertissement en mode `grantsV29` ($\ge 0.29$) |
| **Modifié** | `lib/api/headscale_api_service.dart` | Encodage `Uri.encodeComponent` + nettoyage HuJSON |
| **Modifié** | `lib/screens/acl_screen.dart` | `PolicyPreserver`, HuJSON fetch, suppression doublon `_removeCapabilities` |
| **Modifié** | `lib/screens/dashboard_screen.dart` | `TagCapabilityHelper`, `PolicyPreserver`, `RouteConflictService` |
| **Modifié** | `lib/screens/node_detail_screen.dart` | `TagCapabilityHelper`, `PolicyPreserver`, `RouteConflictService` |
| **Modifié** | `lib/screens/acl_puzzle_screen.dart` | `TagCapabilityHelper`, `PolicyPreserver` |
| **Modifié** | `lib/screens/pre_auth_keys_screen.dart` | Passage de `serverVersion` et `keyId` |
| **Modifié** | `lib/screens/client_commands_screen.dart` | Passage de `serverVersion` |
| **Modifié** | `lib/screens/settings_screen.dart` | Alerte pré-rollback si CIDR dupliqués |
| **Modifié** | `lib/widgets/registration_dialogs.dart` | Respect de `aclEngineMode` à l'ajout des tags |
| **Modifié** | `lib/widgets/create_pre_auth_key_dialog.dart` | Respect de `aclEngineMode` pour `aclTags` |
| **Modifié** | `lib/widgets/edit_tags_dialog.dart` | `PolicyPreserver` lors de la régénération ACL |
| **Modifié** | `lib/widgets/exit_node_command_dialog.dart` | `TagCapabilityHelper` + `PolicyPreserver` |
| **Modifié** | `lib/widgets/share_subnet_dialog.dart` | `TagCapabilityHelper` + `PolicyPreserver` |
| **Modifié** | `lib/widgets/move_node_dialog.dart` | Réattribution tags séparés + `PolicyPreserver` |
| **Modifié** | `lib/widgets/delete_pre_auth_key_dialog.dart` | Passage de `serverVersion` et `keyId` |
| **Tests** | `test/utils/json_utils_test.dart`, `test/services/acl/policy_preserver_test.dart` | Tests unitaires dédiés *(Nouveaux)* |

---

## 5. Risques de Casse & Procédure de Rollback

| Risque identifié | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Parseur HuJSON altère une valeur string contenant `//`, `/*` ou `,}`** | Faible | Moyen | Automate à états qui ignore strictement tout caractère entre `"..."` (avec gestion des échappements `\"`). |
| **Serveur vierge retournant 404/vide sur `getAclPolicy()`** | Moyen | Faible | Si `getAclPolicy()` échoue avec 404/empty, `serverPolicy` est traité comme `null` sans bloquer la génération initiale ; en cas d'erreur réseau/500, on interrompt avant d'écraser. |
| **Cohabitation temporaire de nœuds `;exit-node` et `-exit-node`** | Moyen | Faible | `StandardAclGeneratorService` et `GrantsV29GeneratorService` gèrent déjà les deux formats simultanément dans `tagOwners`, `autoApprovers` et `acls`/`grants`. |
| **Rollback `Grants V29` $\rightarrow$ `Standard` avec CIDR dupliqués** | Moyen | Élevé | Détection bloquante/avertissement explicite dans `SettingsScreen` avant de basculer si deux utilisateurs partagent le même CIDR. |

### Commandes Git de branche & rollback :
```bash
# Création de la branche depuis master
git checkout master && git pull
git checkout -b fix/v2.2.0-compat-non-destructive-acl

# Rollback immédiat en cas de problème avant merge
git checkout master
git branch -D fix/v2.2.0-compat-non-destructive-acl

# Rollback après merge si régression détectée en test interne
git revert -m 1 <commit_merge_sha>
```
