# Plan d'Action 09 — Version 2.3.0 : Mode ACL "Sans Tags" (Tagless), Suppression de l'Auto-Tagging & Filet Hybride

**Date de création** : 16 novembre 2026 *(révisé après audit du flux d'enregistrement, Pre-Auth Keys & migrations auto)*  
**Version cible** : `2.5.0+159` *(Étape 4 recommandée — voir `SUIVI_IMPLEMENTATION.md`)*  
**Branche Git dédiée** : `feat/acl-tagless-and-hybrid` *(créée depuis `master` après Plans 10, 08 et 11)*  
**Prérequis** : Plan d'Action 08 (`PolicyPreserver` & `aclEngineMode` par serveur) mergé ; Plan d'Action 11 recommandé avant (Diff Visuel & Simulateur ACL)  
**Priorité** : **P1 — Haute (Simplification majeure des ACLs & Adoption Utilisateurs)**  
**Niveau de risque global** : 🟠 **Moyen à Élevé** *(introduit un nouveau mode de génération ACL et modifie les flux d'enregistrement / Pre-Auth Keys ; isolé par opt-in pour ne pas impacter les parcs existants)*

---

## 1. Objectif & Constat sur le Flux Actuel d'Auto-Tagging

L'audit complet du flux d'enregistrement montre que **l'application force ou injecte aujourd'hui des tags à plusieurs endroits clés**, ce qui empêche de fait une gestion 100% sans tags :

1. **`CreatePreAuthKeyDialog` (`lib/widgets/create_pre_auth_key_dialog.dart:163-182`)** : même sans cocher *Exit Node* ou *LAN Sharer*, la création d'une clé de pré-authentification injecte **systématiquement** `aclTags: ['tag:<user>-client']`. Toute machine enregistrée via Pre-Auth Key naît donc taguée (sous `tagged-devices` en 0.26+).
2. **`registration_dialogs.dart` (`_showAddTagsDialog`, ligne 640 & 717-726)** : juste après `registerMachine()`, l'étape 3/3 incite l'administrateur à appliquer `tag:<user>-client`.
3. **`DashboardScreen` (`_addCapabilities`, lignes 306-311)** : si un nœud **sans tag** demande l'approbation d'une route ou d'un Exit Node, le code actuel lui ajoute `tag:exit-node` ou `tag:lan-sharer` (sans même préfixer par `<user>` !), ce qui le bascule de force dans `tagged-devices`.
4. **`ExitNodeCommandDialog` (ligne 221) & `ShareSubnetDialog` (ligne 135)** : ajoutent des tags lors de l'activation d'une route.
5. **Contrainte Headscale 0.26–0.29+ sur les machines DÉJÀ taguées** : une machine qui a déjà reçu un tag appartient désormais au compte système `tagged-devices`. Headscale ne permet plus de lui rendre son propriétaire humain via un simple appel API `setTags([])` : il faut soit la ré-authentifier (`--advertise-tags= --force-reauth`), soit la supprimer et la ré-enregistrer.

**Objectifs du Plan 09 :**
- Supprimer l'auto-tagging obligatoire dans les flux d'enregistrement, de création de Pre-Auth Keys et d'approbation de routes lorsque le mode `tagless` est actif (ou sur choix utilisateur).
- Introduire le moteur **`AclEngineMode.tagless`** basé sur `group:<user>`, `autogroup:self`/`member` et les alias `hosts`.
- Rendre ce moteur **tolérant aux machines déjà taguées** (zéro coupure si un parc contient un mélange d'anciennes machines taguées et de nouvelles machines sans tags) + offrir un guide pour "dé-taguer" proprement une ancienne machine si souhaité.
- Ajouter un filet de sécurité hybride dans `Standard` et `Grants V29` pour ne plus jamais couper un appareil non tagué (ex: connexion OIDC).

---

## 2. Prise en compte de la Production Hétérogène (Zéro Coupure)

> [!CAUTION]
> **Règles strictes de non-coupure en production :**
> 1. **Aucun changement automatique sur les serveurs existants** : Le mode `tagless` est **strictement opt-in** (choisi manuellement dans Paramètres ou pour un nouveau serveur). Les serveurs déjà en `legacy`, `standard` ou `grantsV29` gardent leur flux actuel.
> 2. **Tolérance aux machines DÉJÀ taguées (`tagged-devices`)** : Si un administrateur bascule un serveur existant vers `tagless`, `TaglessAclGeneratorService` détecte les machines qui ont encore des tags (`node.tags.isNotEmpty`), préserve leurs `tagOwners` et inclut leurs tags dans les règles d'accès de l'utilisateur (`node.getNormalizedOwner()`). **Aucune machine déjà en production n'est coupée !**
> 3. **Modification purement additive en mode Hybride (`Standard` / `Grants V29`)** : L'inclusion via `group:<user>` ne s'ajoute que si l'utilisateur possède effectivement au moins un nœud avec `node.tags.isEmpty`. Si tous ses nœuds sont déjà tagués, le JSON généré reste **strictement identique** à la v2.2.0.
> 4. **Option de quarantaine préservée** : Un interrupteur dans les Paramètres ACL permet de désactiver l'inclusion auto des nœuds sans tag si l'admin utilise l'absence de tag comme quarantaine.

---

## 3. Détails Techniques

### Tâche 09.1 — Moteur `TaglessAclGeneratorService` (`AclEngineMode.tagless`)
- Ajouter `tagless` à l'enum `AclEngineMode` dans `lib/models/acl_engine_mode.dart`.
- Créer `lib/services/acl/tagless_acl_generator.dart` :
  - **`groups`** : construit `group:<normUser>` via `resolveAclGroupMembers(...)` pour chaque utilisateur.
  - **`hosts`** : pour chaque nœud non-tagué (`node.tags.isEmpty`) ayant une IP, déclare un alias DNS unique dans `hosts` (ex: `"host-<normUser>-<sanitizedNodeName>": "100.64.0.x"`), fusionné de manière non-destructive via `PolicyPreserver` (Plan 08).
  - **`autoApprovers`** : pour chaque route partagée par un nœud sans tag (`0.0.0.0/0`, `::/0`, ou LAN `192.168.x.0/24`), enregistre `group:<normUser>` dans `autoApprovers['routes'][route]`.
  - **Règles (`grants` si serveur $\ge 0.29$, sinon `acls`)** :
    - Intra-utilisateur : `src: ["group:<user>"]`, `dst: ["group:<user>"]` (+ LAN partagés + `autogroup:internet` si Exit Node actif).
    - **Tolérance rétroactive (Transition douce)** : si cet utilisateur a aussi d'anciennes machines encore taguées (`node.tags.isNotEmpty`), les inclure dans `src` et `dst` de l'utilisateur ainsi que dans `tagOwners` et `autoApprovers` pour qu'aucune machine existante ne perde l'accès.
    - Règles spécifiques / exceptions : ciblent les alias `hosts` (`host-<user>-<machine>`) ou l'IP directe, sans nécessiter aucun tag.
- **Limite connue Headscale (`via` sans tags)** :
  - Dans Headscale 0.29+, le mot-clé `"via"` d'un Grant exige un `tag:` (restriction Tailscale).
  - Tant que deux utilisateurs ont des sous-réseaux différents (`192.168.10.0/24` vs `192.168.20.0/24`), `via` n'est pas nécessaire et le mode `tagless` fonctionne à 100% sans tags.
  - Si deux utilisateurs tentent de partager le **même CIDR** en mode `tagless`, `RouteConflictService` bloque l'approbation et explique qu'il faut soit changer de CIDR, soit activer le tag uniquement sur les 2 routeurs concernés (`Grants V29`).

### Tâche 09.2 — Stopper l'Auto-Tagging dans tous les Flux d'Enregistrement & d'Approbation
C'est la modification indispensable pour que les nouvelles machines restent **vraiment sans tags** :
1. **`lib/widgets/create_pre_auth_key_dialog.dart` (lignes 111-183)** :
   - Ajouter un interrupteur *"Associer des tags ACL (Mode Infrastructure / Serveur)"* :
     - **Décoché par défaut** si `appProvider.aclEngineMode == AclEngineMode.tagless` (et optionnel même dans les autres modes !).
     - Lorsqu'il est décoché : passer `aclTags: null` à `createPreAuthKey(...)` et masquer les cases Exit Node / LAN Sharer tagués (avec note : *"La machine appartiendra directement à l'utilisateur sans tag"*).
     - Lorsqu'il est coché : générer les tags selon le moteur actif (Plan 08).
2. **`lib/widgets/registration_dialogs.dart` (lignes 640 & 659-749)** :
   - Après `registerMachine(key, user.name)` : si `appProvider.aclEngineMode == AclEngineMode.tagless`, **ne pas ouvrir `_showAddTagsDialog`** (afficher directement la confirmation *"Appareil enregistré sous l'utilisateur ${user.name} (sans tag)"*).
   - Dans les autres modes, renommer le bouton *"Ignorer"* en **"Conserver sans tag (Recommandé pour appareil personnel)"**.
3. **`lib/screens/dashboard_screen.dart` (lignes 685-691 & 830-836), `exit_node_command_dialog.dart` (lignes 183-222) & `share_subnet_dialog.dart` (lignes 97-136)** :
   - Si `appProvider.aclEngineMode == AclEngineMode.tagless` (ou si le nœud n'a aucun tag et qu'on ne veut pas le basculer en `tagged-devices`), **ne pas appeler `setTags()`** lors de l'approbation d'une route ou d'un Exit Node ! Approuver uniquement les routes via `setNodeRoutes()` puis régénérer les ACLs.
   - Corriger également le fallback buggé de `_addCapabilities` (`dashboard_screen.dart:306-311`) qui ajoutait `tag:exit-node` / `tag:lan-sharer` sans préfixe utilisateur sur les nœuds sans tags.
4. **Assistant pour "Dé-taguer" une ancienne machine (`lib/widgets/edit_tags_dialog.dart`)** :
   - Si un nœud a déjà des tags (`tagged-devices`) et que l'admin veut le passer en mode sans tag sur Headscale $\ge 0.26$, afficher dans `EditTagsDialog` un bouton **"Comment retirer les tags et rendre à un utilisateur ?"** ouvrant les commandes exactes à exécuter sur la machine client :
     - `tailscale up --login-server=<URL> --advertise-tags= --force-reauth` (ou ré-enregistrement après suppression si le bug empty-tags 0.28/0.29 s'applique).

### Tâche 09.3 — Filet de Sécurité Hybride dans `Standard` & `Grants V29`
- Dans `lib/services/standard_acl_generator_service.dart` et `lib/services/acl/grants_v29_generator.dart` :
  - Détecter `final untaggedNodes = userNodes.where((n) => n.tags.isEmpty).toList();`.
  - Si `untaggedNodes.isNotEmpty` (et option d'inclusion active) :
    - Ajouter `groupName` (`group:<normUser>`) aux sources (`src`) et destinations (`dst`) de la règle intra-utilisateur (au lieu de `if (activeUserTags.isEmpty) continue;`).
    - Ajouter `groupName` dans `autoApprovers['routes']` pour les routes annoncées par ces nœuds sans tags.
- Mettre à jour `lib/widgets/acl/acl_engine_banner.dart` pour remplacer l'alerte *"aucune règle auto"* par un statut informatif adapté au mode (`tagless` vs hybride).

### Tâche 09.4 — Support Sans Tags dans `AclParserService`, Composeur, Graphe, Puzzle & Suppression des Prompts de Migration Auto
- **`lib/screens/home_screen.dart` (`_checkForGrantsMigration`, lignes 88-119) & `lib/providers/app_provider.dart` (`_maybeAutoEnableGrantsEngine`, lignes 515-531)** :
  - **Point critique vérifié** : actuellement `HomeScreen._checkForGrantsMigration()` affiche la popup de migration vers `Grants V29` sur tout serveur $\ge 0.29.0$ dès que `aclEngineMode != grantsV29`. Si un utilisateur choisit `AclEngineMode.tagless`, il recevrait cette popup à chaque démarrage !
  - Bloquer `_checkForGrantsMigration()` et `_maybeAutoEnableGrantsEngine()` si `aclEngineMode == AclEngineMode.tagless` ou si `hasExplicitAclEngineMode()` est vrai pour le serveur actif.
- **`lib/utils/grants_v29_gate.dart` & `lib/widgets/acl/grant_edit_sheet.dart`** :
  - Ouvrir le Composeur et l'Éditeur de Grants aux serveurs $\ge 0.29.0$ également en mode `tagless` (puisque `TaglessAclGeneratorService` émet des `grants` sur $\ge 0.29$), tout en adaptant les options (`group:` / `hosts` et `via` optionnel).
- **`lib/services/acl_parser_service.dart`** :
  - Dans `_parseAliases()` (lignes 139-168), charger également `aclPolicy['hosts']` dans `_aliases` pour résoudre les machines sans tags dans la vue Tableau, `AclGraphWidget` et `AclParserService.simulateConnection` (Plan 11).
  - Supporter `autogroup:member` et `autogroup:self` dans `_resolveAlias()`.
- **`lib/services/acl/grant_composer_service.dart` & `grant_composer_sheet.dart`** :
  - Dans `sourceTagOptions()`, proposer les groupes `group:<user>` en plus des `tag:<user>-client`.
  - Dans `destinationOptions(intraFleet / targetedIp)`, proposer les alias `hosts` des machines sans tags.
  - Rendre l'étape `via` optionnelle si ni la source ni la destination ne nécessite de routage multi-LAN par tag.
- **`lib/screens/acl_puzzle_screen.dart`** :
  - Ajouter les entités `host` issues des machines sans tags dans `_buildAvailableEntities()`.
  - Corriger la normalisation `group:${normalizeUserName(user.name)}` (actuellement ligne 170 utilise `group:${user.name}` brut).
- **`lib/screens/settings_screen.dart`** :
  - Ajouter le 4ème mode **"Sans Tags (Utilisateurs)"** dans le sélecteur de moteur ACL + le toggle *"Inclure automatiquement les appareils sans tag"* pour `Standard`/`Grants V29`.

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/services/acl/tagless_acl_generator.dart` | Générateur ACL/Grants sans tags (`group:` + `hosts` + tolérance hybride) |
| **Modifié** | `lib/models/acl_engine_mode.dart` | Ajout de `AclEngineMode.tagless` |
| **Modifié** | `lib/screens/home_screen.dart` & `lib/providers/app_provider.dart` | Empêcher la popup/auto-bascule `Grants V29` si mode `tagless` |
| **Modifié** | `lib/utils/grants_v29_gate.dart` | Autoriser Composeur/Éditeur de Grants en mode `tagless` ($\ge 0.29$) |
| **Modifié** | `lib/services/acl/acl_policy_orchestrator.dart` | Routage vers `TaglessAclGeneratorService` |
| **Modifié** | `lib/services/acl/policy_infrastructure_builder.dart` | Support `autoApprovers` par `group:` pour nœuds sans tags |
| **Modifié** | `lib/services/standard_acl_generator_service.dart` | Filet de sécurité hybride pour nœuds sans tags |
| **Modifié** | `lib/services/acl/grants_v29_generator.dart` | Filet de sécurité hybride pour nœuds sans tags |
| **Modifié** | `lib/widgets/create_pre_auth_key_dialog.dart` | Ne plus forcer `aclTags` par défaut en mode `tagless` (case optionnelle) |
| **Modifié** | `lib/widgets/registration_dialogs.dart` | Sauter `_showAddTagsDialog` en mode `tagless` ; option "Conserver sans tag" |
| **Modifié** | `lib/screens/dashboard_screen.dart` | Ne pas appeler `setTags` en mode `tagless` lors d'approbation/cleanup route |
| **Modifié** | `lib/widgets/exit_node_command_dialog.dart` | Ne pas appeler `setTags` en mode `tagless` |
| **Modifié** | `lib/widgets/share_subnet_dialog.dart` | Ne pas appeler `setTags` en mode `tagless` |
| **Modifié** | `lib/widgets/edit_tags_dialog.dart` | Guide de ré-authentification pour retirer les tags sur Headscale $\ge 0.26$ |
| **Modifié** | `lib/services/acl_parser_service.dart` | Résolution de `hosts`, `autogroup:member` et `autogroup:self` |
| **Modifié** | `lib/services/acl/grant_composer_service.dart` | Options `group:` et `hosts` pour utilisateurs sans tags |
| **Modifié** | `lib/widgets/acl/grant_composer_sheet.dart` & `grant_edit_sheet.dart` | Sélection sans tag + étape `via` optionnelle |
| **Modifié** | `lib/widgets/acl/acl_engine_banner.dart` | Affichage mode `tagless` et statut hybride |
| **Modifié** | `lib/screens/acl_puzzle_screen.dart` | Entités `hosts` + correction normalisation `group:` |
| **Modifié** | `lib/screens/settings_screen.dart` | Sélecteur du 4ème mode *"Sans Tags (Utilisateurs)"* + option hybride |
| **Tests** | `test/services/acl/tagless_acl_generator_test.dart` | Tests unitaires mode `tagless` + mixte + non-régression hybride *(Nouveau)* |

---

## 5. Risques de Casse & Procédure de Rollback

| Risque identifié | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Pre-Auth Key sans `aclTags` sur ancien workflow attendant un tag** | Moyen | Faible | L'option *"Associer des tags ACL"* reste cochée par défaut pour `legacy`, `standard` et `grantsV29` si l'utilisateur ne bascule pas en `tagless` ; en `tagless`, le générateur couvre automatiquement l'appareil sans tag via `group:`. |
| **Machines déjà taguées (`tagged-devices`) sur un serveur passant en `tagless`** | Élevé | Moyen | `TaglessAclGeneratorService` génère en hybride les règles pour leurs tags existants + leurs `tagOwners`, évitant toute coupure lors de la bascule. |
| **Admin comptant sur l'exclusion des nœuds sans tag (quarantaine)** | Faible | Élevé | Paramètre booléen explicite dans Réglages ACL pour désactiver l'inclusion auto des nœuds sans tag en mode `Standard`/`GrantsV29`. |
| **Collision de noms dans `hosts` (deux users ont un nœud nommé `iphone`)** | Élevé | Moyen | Préfixer systématiquement la clé `hosts` par l'utilisateur normalisé : `host-<normUser>-<sanitizedNodeName>` (et suffixer `-2` si doublon chez le même user). |
| **Deux users avec le même CIDR LAN en mode `tagless`** | Moyen | Élevé | `RouteConflictService` empêche la double approbation sans tag `via` et guide l'admin vers la solution hybride (taguer uniquement les 2 routeurs). |

### Commandes Git de branche & rollback :
```bash
# Création de la branche depuis master (après merge des Plans 10, 08 et 11)
git checkout master && git pull
git checkout -b feat/acl-tagless-and-hybrid

# Rollback immédiat avant merge
git checkout master
git branch -D feat/acl-tagless-and-hybrid

# Rollback après merge
git revert -m 1 <commit_merge_sha>
```
