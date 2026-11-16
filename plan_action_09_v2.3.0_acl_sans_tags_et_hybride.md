# Plan d'Action 09 — Version 2.3.0 : Mode ACL "Sans Tags" (Tagless) & Filet de Sécurité Hybride

**Date de création** : 16 novembre 2026  
**Version cible** : `2.3.0+157`  
**Branche Git dédiée** : `feat/v2.3.0-tagless-hybrid-acl` *(créée depuis `master` après merge du Plan 08)*  
**Prérequis** : Plan d'Action 08 (`v2.2.0`) mergé et validé  
**Priorité** : **P1 — Haute (Simplification majeure des ACLs & Adoption Utilisateurs)**  
**Niveau de risque global** : 🟠 **Moyen à Élevé** *(introduit un nouveau mode de génération ACL ; isolé par opt-in pour ne pas impacter les parcs existants)*

---

## 1. Objectif

Permettre aux utilisateurs de gérer leurs ACLs Headscale **sans être obligés d'utiliser des tags sur leurs machines** (notamment sur Headscale 0.26–0.29+ où taguer un nœud remplace son propriétaire humain par `tagged-devices`), tout en protégeant les configurations existantes :

1. **Nouveau moteur ACL `tagless` ("Sans Tags / Utilisateurs")** : Génération de politiques basées sur les identités utilisateurs (`group:<user>`), `autogroup:member` / `autogroup:self` et les alias `hosts` (`nom-machine` $\rightarrow$ IP Tailscale).
2. **Filet de sécurité Hybride dans `Standard` et `Grants V29`** : Ne plus ignorer silencieusement les utilisateurs qui possèdent des nœuds sans tag (`if (activeUserTags.isEmpty) continue;`), afin qu'un nouvel appareil connecté en OIDC ou CLI ne soit jamais coupé du réseau par défaut.
3. **Compatibilité complète avec le Puzzle, le Composeur de Grants et le Graphe Visuel** pour les nœuds sans tags.

---

## 2. Prise en compte de la Production Hétérogène (Zéro Coupure)

> [!CAUTION]
> **Règles strictes de non-coupure en production :**
> 1. **Aucun changement automatique sur les serveurs existants** : Le mode `tagless` est **strictement opt-in** (choisi manuellement dans les Paramètres ou lors de l'ajout d'un nouveau serveur). Les serveurs déjà en `legacy`, `standard` ou `grantsV29` conservent leur mode.
> 2. **Aucun dé-taguage automatique** : L'application ne retire jamais les tags des nœuds déjà tagués en production (d'autant que Headscale 0.26+ conserve `tagged-devices` tant qu'il reste un tag ou nécessite une ré-authentification).
> 3. **Modification purement additive en mode Hybride** : Sur `Standard` et `Grants V29`, l'inclusion via `group:<user>` ne s'ajoute que si l'utilisateur possède effectivement au moins un nœud avec `node.tags.isEmpty`. Si tous ses nœuds sont déjà tagués, le JSON généré reste **strictement identique** à la v2.2.0.
> 4. **Option de quarantaine préservée** : Un interrupteur dans les Paramètres (*"Inclure les nœuds sans tag des utilisateurs"* — activé par défaut en hybride, désactivable) permet aux admins stricts de garder les nœuds sans tag isolés s'ils le souhaitent.

---

## 3. Détails Techniques

### Tâche 09.1 — Moteur `TaglessAclGeneratorService` (`AclEngineMode.tagless`)
- Ajouter `tagless` à l'enum `AclEngineMode` dans `lib/models/acl_engine_mode.dart`.
- Créer `lib/services/acl/tagless_acl_generator.dart` :
  - **`groups`** : construit `group:<normUser>` via `resolveAclGroupMembers(...)` pour chaque utilisateur.
  - **`hosts`** : pour chaque nœud non-tagué (`node.tags.isEmpty`) ayant une IPv4/IPv6, déclare un alias unique DNS-compatible dans `hosts` (ex: `"host-<normUser>-<sanitizedNodeName>": "100.64.0.x"`), fusionné de manière non-destructive via `PolicyPreserver` (Plan 08).
  - **`autoApprovers`** : pour chaque route partagée par un nœud sans tag (`0.0.0.0/0`, `::/0`, ou LAN `192.168.x.0/24`), enregistre `group:<normUser>` dans `autoApprovers['routes'][route]`.
  - **Règles (`grants` si serveur $\ge 0.29$, sinon `acls`)** :
    - Intra-utilisateur : `src: ["group:<user>"]`, `dst: ["group:<user>"]` (+ LAN partagés + `autogroup:internet` si Exit Node actif).
    - Règles spécifiques / exceptions : ciblent les alias `hosts` (`host-<user>-<machine>`) ou l'IP directe, sans nécessiter aucun tag.
    - **Cas hybride** : si un serveur bascule en `tagless` mais possède encore quelques serveurs tagués (ex: un serveur Linux tagué), le générateur inclut aussi leurs `tagOwners` et règles associées pour éviter toute coupure pendant une transition progressive.
- **Limite connue Headscale (`via` sans tags)** :
  - Dans Headscale 0.29+, le mot-clé `"via"` d'un Grant exige un `tag:` (imposé par le moteur Tailscale).
  - Tant que deux utilisateurs ont des sous-réseaux différents (ex: `192.168.10.0/24` vs `192.168.20.0/24`), `via` n'est pas nécessaire et le mode `tagless` fonctionne sans aucun tag.
  - Si deux utilisateurs tentent de partager le même CIDR en mode `tagless`, `RouteConflictService` bloque et propose à l'utilisateur soit de taguer uniquement les 2 routeurs concernés (`Grants V29`), soit de changer de plage LAN.

### Tâche 09.2 — Filet de Sécurité Hybride dans `Standard` & `Grants V29`
- Dans `lib/services/standard_acl_generator_service.dart` et `lib/services/acl/grants_v29_generator.dart` :
  - Détecter `final untaggedNodes = userNodes.where((n) => n.tags.isEmpty).toList();`.
  - Si `untaggedNodes.isNotEmpty` (et option d'inclusion active) :
    - Ajouter `groupName` (`group:<normUser>`) aux sources (`src`) et destinations (`dst`) de la règle intra-utilisateur (au lieu de faire `if (activeUserTags.isEmpty) continue;`).
    - Ajouter `groupName` dans `autoApprovers['routes']` pour les routes annoncées par ces nœuds sans tags (en vérifiant qu'aucun conflit CIDR n'existe si sans `via`).
- Mettre à jour `lib/widgets/acl/acl_engine_banner.dart` pour distinguer :
  - Mode `tagless` actif (badge dédié).
  - Nœuds sans tags couverts par le mode Hybride (information bleue/verte au lieu d'une alerte d'exclusion).

### Tâche 09.3 — Support Sans Tags dans `AclParserService`, Composeur, Graphe & Puzzle
- **`lib/services/acl_parser_service.dart`** :
  - Dans `_parseAliases()` (lignes 139-168), charger également `aclPolicy['hosts']` dans `_aliases` pour que les alias de machines sans tags soient résolus vers leurs IPs dans la vue Tableau et le Graphe `AclGraphWidget`.
  - Vérifier le traitement de `autogroup:member` et `autogroup:self` dans `_resolveAlias()`.
- **`lib/services/acl/grant_composer_service.dart` & `grant_composer_sheet.dart`** :
  - Dans `sourceTagOptions()`, proposer les groupes `group:<user>` en plus des `tag:<user>-client` (et afficher un libellé clair : *"Utilisateur Jean (sans tag)"*).
  - Dans `destinationOptions(intraFleet / targetedIp)`, proposer les alias `hosts` des machines sans tags.
- **`lib/screens/acl_puzzle_screen.dart`** :
  - Dans `_buildAvailableEntities()`, ajouter les entités `host` issues des machines sans tags et s'assurer que `group:<user>` utilise `normalizeUserName(user.name)` (cohérent avec le générateur ; actuellement ligne 170 utilise `group:${user.name}` brut, ce qui est incohérent si `user.name` est un email avec `@` ou `.` !).
- **`lib/widgets/registration_dialogs.dart` & `edit_tags_dialog.dart`** :
  - Si le serveur est en mode `tagless`, rendre l'étape d'ajout de tags facultative / skippée par défaut avec un message explicatif.

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/services/acl/tagless_acl_generator.dart` | Générateur ACL/Grants sans tags (`group:` + `hosts`) |
| **Modifié** | `lib/models/acl_engine_mode.dart` | Ajout de `AclEngineMode.tagless` |
| **Modifié** | `lib/services/acl/acl_policy_orchestrator.dart` | Routage vers `TaglessAclGeneratorService` |
| **Modifié** | `lib/services/acl/policy_infrastructure_builder.dart` | Support `autoApprovers` par `group:` pour nœuds sans tags |
| **Modifié** | `lib/services/standard_acl_generator_service.dart` | Filet de sécurité hybride pour nœuds sans tags |
| **Modifié** | `lib/services/acl/grants_v29_generator.dart` | Filet de sécurité hybride pour nœuds sans tags |
| **Modifié** | `lib/services/acl_parser_service.dart` | Résolution de `hosts`, `autogroup:member` et `autogroup:self` |
| **Modifié** | `lib/services/acl/grant_composer_service.dart` | Options `group:` et `hosts` pour utilisateurs sans tags |
| **Modifié** | `lib/widgets/acl/grant_composer_sheet.dart` | Sélection sans tag + masquage `via` si non applicable |
| **Modifié** | `lib/widgets/acl/acl_engine_banner.dart` | Affichage mode `tagless` et statut hybride |
| **Modifié** | `lib/screens/acl_puzzle_screen.dart` | Entités `hosts` + correction normalisation `group:` |
| **Modifié** | `lib/screens/settings_screen.dart` | Sélecteur du 4ème mode *"Sans Tags (Utilisateurs)"* + option hybride |
| **Modifié** | `lib/widgets/registration_dialogs.dart` | Étape tags optionnelle en mode `tagless` |
| **Tests** | `test/services/acl/tagless_acl_generator_test.dart` | Tests unitaires mode `tagless` + non-régression hybride *(Nouveau)* |

---

## 5. Risques de Casse & Procédure de Rollback

| Risque identifié | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Admin comptant sur l'exclusion des nœuds sans tag (quarantaine)** | Faible | Élevé | Paramètre booléen explicite dans Réglages ACL pour désactiver l'inclusion auto des nœuds sans tag en mode `Standard`/`GrantsV29`. |
| **Collision de noms dans `hosts` (deux users ont un nœud nommé `iphone`)** | Élevé | Moyen | Préfixer systématiquement la clé `hosts` par l'utilisateur normalisé : `host-<normUser>-<sanitizedNodeName>` (et suffixer `-2` si doublon chez le même user). |
| **Bug existant dans `AclPuzzleScreen` (`group:${user.name}` non normalisé)** | Moyen | Moyen | Aligner sur `group:${normalizeUserName(user.name)}` tout en gardant un fallback de lecture pour les anciennes règles Puzzle déjà sauvegardées. |
| **Deux users avec le même CIDR LAN en mode `tagless`** | Moyen | Élevé | `RouteConflictService` empêche la double approbation sans tag `via` et guide l'admin vers la solution hybride (taguer uniquement les 2 routeurs). |

### Commandes Git de branche & rollback :
```bash
# Création de la branche depuis master (après merge du Plan 08)
git checkout master && git pull
git checkout -b feat/v2.3.0-tagless-hybrid-acl

# Rollback immédiat avant merge
git checkout master
git branch -D feat/v2.3.0-tagless-hybrid-acl

# Rollback après merge
git revert -m 1 <commit_merge_sha>
```
