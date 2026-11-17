# Registre de Dépréciation & Cycle de Vie des Versions Headscale

**Règle de Gouvernance ("Fenêtre Glissante $N - 2$") :**
Afin d'éviter que le code de **Headscale Manager** n'accumule indéfiniment de la dette technique ("usine à gaz") tout en respectant les administrateurs en production :
1. **Version de référence courante ($N$)** : `0.29` *(Fenêtre activement supportée sans avertissement : **$N$ (`0.29`) et $N-1$ (`0.28`)**).*
2. **Seuil d'avertissement Bandeau Rouge ($\le N - 2$)** : Tout serveur connecté en version **$\le 0.27$** (`< 0.28.0`) affiche un **bandeau rouge d'avertissement** dans l'application prévenant l'administrateur que son serveur a au moins 2 versions majeures de retard et que les fonctions dépréciées associées seront retirées à la prochaine mise à jour majeure.
3. **Seuil de purge immédiate ($\le N - 3$, soit `< 0.26`)** : Les contournements spécifiques aux versions `< 0.26` sont purgés dès le **Sous-Plan 09-0**, avec un **système d'audit et d'alignement automatique** qui aide l'administrateur à mettre sa configuration en conformité.

---

## 📋 Processus Obligatoire à Chaque Montée de Version Headscale

À chaque fois qu'une nouvelle version majeure de Headscale sort (ex: passage de `0.29` à `0.30`) :
1. **Incrémenter `currentReferenceMinorVersion`** dans `VersionInfo` (ex: `0.29` $\rightarrow$ `0.30`).
2. **Décaler le seuil du Bandeau Rouge ($N - 2$)** d'un cran (ex: $\le 0.27$ $\rightarrow$ $\le 0.28$).
3. **Purger dans le code Dart** tous les éléments du palier sortant listés dans le tableau ci-dessous.
4. **Mettre à jour ce fichier** avant de créer la branche Git de la nouvelle version.

---

## 🗂️ Tableau de Suivi des Dépréciations par Palier de Version

### 🔴 Palier 1 : Headscale `< 0.26` (`0.22` à `0.25`) — **PURGE IMMÉDIATE (Sous-Plan 09-0)**

| Fonctionnalité / Contournement Legacy | Fichiers & Emplacements dans le code | Action dans le Sous-Plan `09-0` |
|---|---|---|
| **Membres de `groups` sans `@`** *(Policy v1)* | `lib/utils/string_utils.dart` (`resolveAclGroupMembers`)<br>`lib/screens/acl_puzzle_screen.dart` | Aligner systématiquement sur le format Policy v2 ($\ge 0.26$) : `"user@"` pour les comptes locaux sans email et `"user@domaine.com"` pour les comptes email/OIDC. Le diagnostic `09-0` détecte et corrige automatiquement les anciens groupes sans `@`. |
| **Propriétaires `tagOwners` sans `group:` ni `@`** | `lib/services/new_acl_generator_service.dart`<br>`lib/widgets/edit_tags_dialog.dart` | Interdire tout owner brut sans `@` ni `group:`. Nettoyer automatiquement via l'outil d'alignement `09-0`. |
| **Ancien bloc `autoApprovers.exitNodes`** *(remplacé par `routes: 0.0.0.0/0` en 0.26+)* | `lib/services/new_acl_generator_service.dart` | Supprimé / remplacé par `autoApprovers.routes["0.0.0.0/0", "::/0"]` + détection dans l'audit `09-0` si une vieille policy serveur contient encore `exitNodes`. |
| **Tags fusionnés par point-virgule (`tag:user-client;exit-node`)** *(Moteur Legacy)* | `lib/services/new_acl_generator_service.dart`<br>`lib/widgets/edit_tags_dialog.dart` (`_consolidateTags`)<br>`lib/widgets/legacy_migration_dialog.dart` | Déprécié : l'outil d'alignement `09-0` et l'Assistant de Bascule `09-B` détectent ces tags et guident la conversion en 1 clic vers les tags séparés (`Standard`/`Grants V29`) ou vers le mode `Sans Tags`. Suppression complète du moteur `Legacy` prévue au passage `0.30`. |

---

### 🚨 Palier 2 : Headscale `0.26` à `0.27` — **EN BANDEAU ROUGE ACTUELLEMENT (Purge prévue à la sortie de Headscale `0.30`)**

> **Statut en v2.5 (`N = 0.29`) :** Affiché avec un **Bandeau Rouge d'avertissement** (`VersionInfo.isServerDeprecated == true` si `< 0.28.0`). Fonctionne encore dans la v2.5 pour laisser le temps aux administrateurs de mettre à jour leur serveur, puis **sera supprimé lors du plan Headscale `0.30`**.

| Fonctionnalité / Contournement Legacy (0.26–0.27) | Fichiers & Emplacements exacts à supprimer au passage `0.30` | Impact lors de la purge en `0.30` |
|---|---|---|
| **Déplacement de nœud (`moveNode` / `POST /api/v1/node/{id}/user`)** *(supprimé de Headscale en 0.28)* | - `lib/api/headscale_api_service.dart` : méthode `moveNode(...)`<br>- `lib/widgets/move_node_dialog.dart` : fichier entier à supprimer<br>- `lib/screens/user_detail_screen.dart:624-637` & `722-727` : entrée menu `'move'` | Suppression du dialogue et de la route API morte en 0.28+. |
| **Ancien endpoint PreAuthKey par boucle utilisateur** (`GET /api/v1/preauthkey?user=...` & expiration par `{user, key}` sans `id`) | - `lib/api/headscale_api_service.dart:399-419` (boucle fallback `< 0.28`)<br>- `lib/api/headscale_api_service.dart:447-465` (expiration legacy par `user` + `key`)<br>- `lib/models/pre_auth_key.dart` | Seul l'endpoint global v0.28+ (`GET /api/v1/preauthkey` et expiration par `id`) sera conservé. |
| **Champs JSON legacy `forcedTags` / `validTags` en camelCase/snake_case multiples** | - `lib/models/node.dart:130-135` | Simplification sur le champ standard `tags` / `forcedTags` v0.28+. |

---

### ⏳ Palier 3 : Headscale `0.28` — **SUPPORTÉ (Entrera en Bandeau Rouge à la sortie de Headscale `0.30`, purge en `0.31`)**

| Fonctionnalité / Spécificité 0.28 | Fichiers & Emplacements concernés | Note pour la future transition `0.30` $\rightarrow$ `0.31` |
|---|---|---|
| **Génération ACL classique (`"acls"`) sans `"grants"` ni `"tests"` ni Taildrive** | - `lib/services/standard_acl_generator_service.dart`<br>- `lib/services/acl/acl_policy_orchestrator.dart` (fallback `< 0.29.0`)<br>- `lib/utils/grants_v29_gate.dart` | En `0.30`, tous les serveurs supportés (`0.29` et `0.30`) supporteront nativement `grants`, `via`, `tests` et `Taildrive`. |

---

### 🔮 Palier 4 : Headscale `0.29` (`/api/v1`) — **VERSION COURANTE (Maintenu en `0.30`–`0.32`, suppression confirmée en `0.33`)**

| Fonctionnalité / Spécificité 0.29 | Fichiers & Emplacements concernés | Note pour la future transition `0.30` (`/api/headscale/v0`) |
|---|---|---|
| **Client REST `/api/v1`** (gelé en `0.30`, supprimé en `0.33` suite aux retours PR `#3375`) | - `lib/api/headscale_api_service.dart` | En `0.30`, ajout progressif du support `/api/headscale/v0` (pagination `pageSize=1000`, `ETag`/`If-Match`, `dryRun=true`, `owner_conflict` sur PreAuthKey, `tags_not_permitted` avec push `tagOwners` préalable, `expire` actif même sur nœuds tagués). |
