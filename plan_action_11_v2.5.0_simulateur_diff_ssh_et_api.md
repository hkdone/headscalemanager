# Plan d'Action 11 — Version 2.5.0 : Simulateur ACL, Diff Visuel Ligne-par-Ligne, Tailscale SSH & Nouveautés API

**Date de création** : 16 novembre 2026  
**Version cible** : `2.5.0+159`  
**Branche Git dédiée** : `feat/v2.5.0-simulator-diff-ssh-api-tools` *(créée depuis `master`)*  
**Prérequis** : Plans d'Action 08 (`v2.2.0`) et 09 (`v2.3.0`) mergés  
**Priorité** : **P2 — Évolution Produit (Confiance Admin & Adoption Utilisateurs)**  
**Niveau de risque global** : 🟢 **Très Faible** *(fonctionnalités purement additives et déclenchées à la demande par l'utilisateur)*

---

## 1. Objectif

Apporter les outils visuels et d'audit qui donnent aux administrateurs une **confiance totale** avant de modifier leurs ACLs en production et exploitent les dernières capacités de Headscale `0.28` / `0.29+` :

1. **Diff Visuel Ligne-par-Ligne Coloré** avant toute publication sur le serveur (`PolicyDiffDialog` v2).
2. **Simulateur Interactif de Flux ACL ("Qui peut parler à qui ?")** + épinglage dans le bloc `"tests"` officiel de Headscale `0.29+`.
3. **Gestionnaire Visuel Tailscale SSH (`"ssh": [...]`)** dans l'écran ACL.
4. **Exploitation des endpoints API manquants** : expiration de session d'un nœud (`/api/v1/node/{id}/expire`) et attribution des IPs manquantes (`/api/v1/node/backfillips`).

---

## 2. Prise en compte de la Production Hétérogène (Zéro Coupure)

> [!TIP]
> **Sécurité par conception :**
> - Le **Diff Visuel** et le **Simulateur** sont en lecture seule : ils ne modifient rien tant que l'admin ne clique pas explicitement sur *Confirmer export*.
> - Le bloc `"tests"` n'est actif que sur Headscale $\ge 0.29.0$ (masqué sur les serveurs plus anciens pour éviter tout rejet de schéma).
> - Les règles `"ssh"` ne sont ajoutées que si l'administrateur crée explicitement une règle dans le nouvel onglet SSH.

---

## 3. Détails Techniques

### Tâche 11.1 — Comparateur Visuel Ligne-par-Ligne (`JsonDiffUtils` + `PolicyDiffDialog`)
- Créer `lib/utils/json_diff_utils.dart` implémentant un calcul de diff ligne-par-ligne (LCS) sur les deux JSON formatés (`JsonEncoder.withIndent('  ')`).
- Mettre à jour `AclScreen._exportAclPolicyToServer()` pour récupérer la politique **actuellement en ligne sur le serveur** (plutôt que de comparer uniquement avec `_lastGeneratedPolicy` en mémoire).
- Améliorer `lib/widgets/acl/policy_diff_dialog.dart` :
  - Afficher les lignes ajoutées (`+`, fond vert), supprimées (`-`, fond rouge) et un filtre *"Afficher uniquement les différences"*.
  - Garde-fou performance : si la policy dépasse 1500 lignes, basculer sur un diff par section JSON (`groups`, `acls`, `grants`, `ssh`, `tests`) pour éviter tout lag sur mobile.

### Tâche 11.2 — Simulateur de Connectivité & Bloc `"tests"` Headscale 0.29+
- Ajouter dans `lib/services/acl_parser_service.dart` une méthode `SimulationResult simulateConnection({required Node sourceNode, required String destination, String? port, String protocol = 'tcp'})` qui évalue les règles `acls` et `grants` (avec support `via` et `hosts`) sur le brouillon local.
- Créer `lib/widgets/acl/acl_simulator_sheet.dart` :
  - Sélection Source (Machine / Utilisateur) $\rightarrow$ Destination (Machine / Sous-réseau / IP / `autogroup:internet`) + Port/Protocole.
  - Affiche ✅ **AUTORISÉ** (règle correspondante + routeur `via` utilisé) ou ❌ **BLOQUÉ** (avec bouton *"Autoriser via le Composeur"*).
  - Si serveur $\ge 0.29.0$ : bouton *"Épingler comme test de non-régression"* qui ajoute une entrée dans `policy['tests']` (`src`, `accept` / `deny`).
- Avant export vers le serveur, valider que les IPs/hôtes cités dans `policy['tests']` existent toujours afin d'éviter un rejet de sauvegarde par Headscale.

### Tâche 11.3 — Onglet Tailscale SSH dans `AclScreen`
- Ajouter un 4ème onglet **SSH** dans `lib/screens/acl_screen.dart` (`Grants | ACLs | SSH | JSON`).
- Créer `lib/widgets/acl/ssh_rules_list_view.dart` et un dialogue de création rapide :
  - Source (`group:<user>`, `tag:...`, `autogroup:member`)
  - Destination (`tag:...`, `autogroup:self`) — avec validation stricte des règles Tailscale SSH (`dst` ne peut cibler un autre utilisateur sans tag).
  - Comptes Linux autorisés (`autogroup:nonroot`, `root`, ou personnalisé) et action (`accept` / `check`).

### Tâche 11.4 — Endpoints API `expireNode` & `backfillNodeIps`
- Dans `lib/api/headscale_api_service.dart` :
  - `Future<Node> expireNode(String nodeId)` $\rightarrow$ `POST $_baseUrl/api/v1/node/${Uri.encodeComponent(nodeId)}/expire`
  - `Future<List<String>> backfillNodeIps({bool confirmed = true})` $\rightarrow$ `POST $_baseUrl/api/v1/node/backfillips?confirmed=$confirmed`
- Dans `lib/screens/node_detail_screen.dart` et `lib/screens/user_detail_screen.dart` : ajouter l'action *"Expirer la session (Déconnecter sans supprimer)"* avec dialogue explicatif.
- Dans `lib/screens/settings_screen.dart` : ajouter le bouton de maintenance *"Attribuer les IPs manquantes (Backfill IPs)"* avec prévisualisation (`confirmed=false`) puis confirmation (`confirmed=true`).

---

## 4. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/utils/json_diff_utils.dart` | Algorithme de diff ligne-par-ligne pour JSON |
| **Nouveau** | `lib/widgets/acl/acl_simulator_sheet.dart` | Interface du simulateur de connectivité et épinglage `tests` |
| **Nouveau** | `lib/widgets/acl/ssh_rules_list_view.dart` | Vue et éditeur des règles Tailscale SSH (`policy['ssh']`) |
| **Modifié** | `lib/widgets/acl/policy_diff_dialog.dart` | Affichage visuel `+` / `-` coloré |
| **Modifié** | `lib/services/acl_parser_service.dart` | Méthode `simulateConnection(...)` |
| **Modifié** | `lib/screens/acl_screen.dart` | Onglet SSH, entrée Simulateur, fetch policy serveur avant Diff |
| **Modifié** | `lib/api/headscale_api_service.dart` | `expireNode` & `backfillNodeIps` |
| **Modifié** | `lib/screens/node_detail_screen.dart` | Bouton *Expirer la session* |
| **Modifié** | `lib/screens/user_detail_screen.dart` | Option *Expirer la session* dans le menu de `_NodeCard` |
| **Modifié** | `lib/screens/settings_screen.dart` | Outil de maintenance *Backfill IPs* |
| **Tests** | `test/utils/json_diff_utils_test.dart`, `test/services/acl_simulator_test.dart` | Tests unitaires diff & simulateur *(Nouveaux)* |

---

## 5. Risques de Casse & Procédure de Rollback

| Risque identifié | Probabilité | Impact | Mitigation |
|---|---|---|---|
| **Rejet serveur sur `"tests"` si un nœud référencé est supprimé** | Moyen | Moyen | Vérification pré-export des IPs/tags utilisés dans `tests` avec proposition de nettoyage automatique si un nœud n'existe plus. |
| **Règle SSH invalide rejetée par Headscale** | Faible | Faible | Contrôle dans l'UI que `dst` d'une règle `ssh` utilise `autogroup:self` ou un `tag:` lorsque `src != dst`, et blocage du bouton Valider sinon. |
| **Lenteur du Diff sur très gros JSON** | Faible | Faible | Bascule automatique vers un résumé par section au-delà de 1500 lignes. |

### Commandes Git de branche & rollback :
```bash
# Création de la branche depuis master
git checkout master && git pull
git checkout -b feat/v2.5.0-simulator-diff-ssh-api-tools

# Rollback immédiat avant merge
git checkout master
git branch -D feat/v2.5.0-simulator-diff-ssh-api-tools

# Rollback après merge
git revert -m 1 <commit_merge_sha>
```
