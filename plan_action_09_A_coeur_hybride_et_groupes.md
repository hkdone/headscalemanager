# Sous-Plan d'Action 09-A — Cœur Hybride Zéro-Coupure (Tags + Sans Tags + OIDC) & Résolution Simulateur/Graphe

**Date de création** : 17 novembre 2026  
**Version cible** : `2.5.1+163` *(Étape 4.A — voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Branche Git dédiée** : `feat/acl-09-a-hybrid-core` *(créée depuis `master` après merge de `09-0`)*  
**Prérequis** : Sous-Plan `09-0` validé et mergé  
**Plan parent** : [plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md)  
**Niveau de risque** : 🟢 **Faible** *(purement additif sur les moteurs existants : si 100 % des nœuds d'un utilisateur sont tagués, les règles générées restent strictement identiques ; dès qu'un nœud est sans tag, il est inclus automatiquement sans couper les nœuds tagués)*

---

## 1. Objectif du Sous-Plan 09-A

Garantir qu'un utilisateur possédant **à la fois** d'anciennes machines taguées (`tag:jean-client`, sous `tagged-devices`) **et** de nouvelles machines sans tags (ex: un smartphone connecté en OIDC ou un PC en cours de bascule vers le mode sans tag) :
1. Ne subisse **aucune coupure de communication** entre ses machines taguées et ses machines sans tags.
2. Puisse utiliser son **Exit Node** et ses **routes LAN** depuis ses machines sans tags comme depuis ses machines taguées (que le routeur lui-même soit tagué avec `via` ou sans tag en routage direct).
3. Voie ses flux **Sans Tags** et **Hybrides** correctement reconnus comme **Autorisés (ALLOW)** dans le **Simulateur de flux ACL** et dans le **Graphe Visuel ACL**.

---

## 2. Détails Techniques

### Tâche 09-A.1 — Union Hybride dans `GrantsV29GeneratorService` & `StandardAclGeneratorService`
- **Correction du piège du parc mixte** :
  - Actuellement, `GrantsV29GeneratorService` et `StandardAclGeneratorService` n'ajoutent `group:<user>` que si `activeUserTags.isEmpty`. Si un utilisateur a 2 machines taguées et 1 machine sans tag (ex: mobile OIDC), la machine sans tag était exclue de la règle intra-flotte, de l'Exit Node et du LAN !
  - **Nouvelle logique Hybride** :
    - Calculer `final hasUntaggedNodes = userNodes.any((n) => n.tags.isEmpty);`
    - Si `includeUntaggedNodes` est actif (activé par défaut, désactivable dans Paramètres si l'admin utilise l'absence de tag comme quarantaine) :
      - Construire la liste des identités de la flotte de l'utilisateur :
        `final fleetSubjects = <String>{...sortedTags, if (hasUntaggedNodes) groupName}.toList();`
      - **Communication intra-utilisateur** : `src: fleetSubjects`, `dst: fleetSubjects` (les machines taguées et non-taguées de l'utilisateur se voient mutuellement dans les deux sens !).
      - **Accès Internet (Exit Node)** :
        - En `Grants V29` : si le nœud Exit Node porte un tag (`activeExitTag != null`), émettre `src: fleetSubjects, dst: ['autogroup:internet'], via: [activeExitTag], ip: ['*']`. Si le nœud Exit Node de l'utilisateur est **sans tag** (`activeExitTag == null && hasActiveExitNodes`), émettre le Grant **sans `via`** (`src: fleetSubjects, dst: ['autogroup:internet'], ip: ['*']`) car Headscale 0.29 interdit les groupes dans `via`.
        - En `Standard` : `autogroup:internet:*` est accessible à `fleetSubjects`.
      - **Accès Sous-réseaux LAN** :
        - En `Grants V29` : pour chaque route LAN de l'utilisateur, si le routeur LAN porte un tag (`activeLanTag != null`), utiliser `via: [activeLanTag]`. Si le routeur LAN est **sans tag**, émettre le Grant direct sans `via` (`src: fleetSubjects, dst: [route], ip: ['*']`).

### Tâche 09-A.2 — Support Hybride de `autoApprovers` & Alias `hosts` pour Nœuds Sans Tags
- Dans `lib/services/acl/policy_infrastructure_builder.dart` :
  - Lorsqu'un nœud partage des routes (`0.0.0.0/0`, `::/0`, ou CIDR LAN) :
    - S'il possède le tag `tag:<user>-exit-node` / `tag:<user>-lan-sharer`, enregistrer ce tag dans `autoApprovers.routes[route]`.
    - **Nouveau** : S'il est **sans tag** (`node.tags.isEmpty`), trouver l'utilisateur propriétaire via `nodeBelongsToUser(node, user)` et enregistrer `group:<normUser>` dans `autoApprovers.routes[route]`.
  - **Génération d'alias `hosts` pour les nœuds sans tags (`buildManagedHosts`)** :
    - Pour chaque nœud sans tag ayant une adresse IPv4 Tailscale, générer un alias DNS-1123 propre et déterministe : `"host-<normUser>-<sanitizedNodeName>": "<ipv4>"` (avec suffixe `-2` en cas d'homonymie chez le même utilisateur).
    - Permet de cibler individuellement une machine sans tag dans une règle ACL, un Grant ou la Vue Puzzle sans dépendre d'une IP brute en dur !
- Dans `lib/services/acl/policy_preserver.dart` (`_mergeHosts`) et `lib/services/acl/policy_orphan_cleaner.dart` :
  - Distinguer les clés `hosts` gérées par l'application (préfixées par `host-`) des clés `hosts` manuelles créées par l'administrateur (ex: `"nas-maison": "192.168.1.50"`).
  - Les clés `host-*` sont mises à jour automatiquement si l'IP d'un nœud change (ex: après `backfillNodeIps`) et supprimées par `PolicyOrphanCleaner` si le nœud est supprimé, tandis que les `hosts` manuels de l'admin restent **100 % intacts**.

### Tâche 09-A.3 — Résolution Complète dans `AclParserService` (Simulateur de Flux + Graphe + Tableau) & Rattachement OIDC
- Dans `lib/services/acl_parser_service.dart` :
  - **Charger `aclPolicy['hosts']` dans `_parseAliases()`** : toute règle ciblant un alias `host-jean-pc` ou un host manuel est désormais résolue vers son IP/CIDR.
  - **Corriger `_resolveAlias()` pour `"user@"`, `"user@domain"` et les emails OIDC** :
    - Actuellement, `allUsers.firstWhere((u) => u.name == alias)` échoue quand `groups` contient `"jean@"` (avec `@` final) ou un email OIDC alors que `u.name` est `"jean"` !
    - Utiliser `PolicyInfrastructureBuilder.nodeBelongsToUser(node, user)` et matcher `alias` contre `u.name`, `'${u.name}@'`, `u.email`, et `resolveAclGroupMembers(u.name, email: u.email)`.
    - Résoudre alors vers toutes les adresses IP des nœuds appartenant à `user` (et pour `group:<user>`, résoudre vers les nœuds sans tags + nœuds de l'utilisateur).
  - **Supporter `autogroup:member`** : résoudre vers les IPs de tous les nœuds appartenant à un utilisateur humain (`node.tags.isEmpty`).
- Dans `lib/screens/dashboard_screen.dart` (lignes 105-119), `lib/screens/user_detail_screen.dart` (lignes 382-387) et `lib/services/acl/taildrive_builder.dart` :
  - Utiliser `PolicyInfrastructureBuilder.nodeBelongsToUser(node, user)` pour qu'aucun nœud OIDC ou sans tag ne tombe dans *"Nœuds Orphelins"* et que Taildrive utilise toujours le nom de groupe exact déclaré dans `policy['groups']`.

---

## 3. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Modifié** | `lib/services/acl/policy_infrastructure_builder.dart` | `autoApprovers` hybrides (`group:` si nœud sans tag) + `buildManagedHosts` (`host-<user>-<node>`) |
| **Modifié** | `lib/services/acl/grants_v29_generator.dart` | Union hybride `[...sortedTags, groupName]` + `via` conditionnel (avec ou sans tag routeur) |
| **Modifié** | `lib/services/standard_acl_generator_service.dart` | Union hybride `[...sortedTags, groupName]` dans `src` et `dst` |
| **Modifié** | `lib/services/acl/policy_preserver.dart` | Rafraîchissement des `host-*` gérés tout en sanctuarisant les `hosts` manuels |
| **Modifié** | `lib/services/acl/policy_orphan_cleaner.dart` | Nettoyage des `host-*` de nœuds supprimés |
| **Modifié** | `lib/services/acl_parser_service.dart` | Résolution de `hosts`, `"user@"`, emails OIDC et `autogroup:member` pour Simulateur & Graphe |
| **Modifié** | `lib/services/acl/taildrive_builder.dart` | Rattachement propriétaire via `nodeBelongsToUser` |
| **Modifié** | `lib/screens/dashboard_screen.dart` & `lib/screens/user_detail_screen.dart` | Rattachement des nœuds OIDC / sans tags via `nodeBelongsToUser` |
| **Tests** | `test/services/acl/hybrid_acl_generation_test.dart` | Tests unitaires parc 100% tagué, 100% sans tag, et mixte (tagué + sans tag OIDC/local) *(Nouveau)* |

---

## 4. Gate de Validation `09-A`
- [ ] `flutter analyze` $\rightarrow$ `0 issue`.
- [ ] Test de non-régression strict : pour un utilisateur dont **tous** les nœuds sont tagués, la règle générée est identique.
- [ ] Test Parc Mixte (Jean a 1 NAS tagué `tag:jean-client` + 1 mobile OIDC sans tag) : la règle générée contient à la fois `tag:jean-client` et `group:jean` en `src` et `dst`.
- [ ] Test dans le **Simulateur de flux ACL** : simuler un flux entre le NAS tagué de Jean et le mobile sans tag de Jean $\rightarrow$ le simulateur affiche **✅ AUTORISÉ (ALLOW)**.
