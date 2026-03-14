# Plan d'Action 05 — Version 1.5.105 : Connexion OIDC & Corrections (14 mars 2026)

## Objectif
Améliorer le support OIDC end-to-end et corriger les warnings de dépréciation accumulés.

---

## Modifications réalisées

### 1. Fix bug : Utilisateur OIDC créé sans nom
**Cause** : Headscale crée automatiquement un utilisateur lors d'une première connexion OIDC
avec `name = ""` (chaîne vide). L'opérateur `??` ne protège pas contre les chaînes vides.

- [x] **`lib/models/user.dart`** — `User.fromJson` : fallback `name → email → displayName → 'Unknown User'`
  si `name` est vide. Affichage correct même avant correction serveur.

- [x] **`lib/models/node.dart`** — `Node.fromJson` : même fallback pour `node.user`
  (`userMap['name']` vide → `userMap['email']`). Cohérence avec `user.name`.

- [x] **`lib/screens/users_screen.dart`** — `_loadAndFixUsers()` : au chargement de l'écran
  Utilisateurs, détection automatique des users OIDC avec `name == email` (signal que le
  serveur avait `name=""`) → appel silencieux de `renameUser(id, email)` → rechargement.
  **Correction permanente côté serveur : les ACLs fonctionnent sans renommage manuel.**

- [x] **`lib/screens/dashboard_screen.dart`** — Bannière orange si des nœuds ont
  `node.user == ""` ou `"N/A"`, avec message guidant vers l'écran Utilisateurs.

### 2. Nouveau dialog "Ajouter un Appareil" avec choix de mode
**Contexte** : OIDC n'est pas activé sur tous les serveurs. L'utilisateur doit choisir.

- [x] **`lib/widgets/registration_dialogs.dart`** — Refonte complète de
  `showTailscaleUpCommandDialog` :
  - **Écran de sélection** : deux cartes cliquables au départ
  - **Carte "Connexion Classique"** → Flow 3 étapes inchangé (commande → machine key → tags ACL)
  - **Carte "Connexion OIDC"** *(note : OIDC réservé aux admins ayant activé OIDC dans config.yaml)* :
    - Étape 1/2 : commande `tailscale up` + URL mobile (navigateur s'ouvre automatiquement, pas de machine key)
    - Étape 2/2 : snippet `config.yaml` copiable avec l'email de l'utilisateur courant
      (`oidc.allowed_users`) + rappel que le nœud s'enregistre automatiquement
  - Numérotation mise à jour : Classique → "Étape 1/3", "Étape 2/3", "Étape 3/3"

### 3. Fix dépréciation `Matrix4.scale` → `scaleByDouble`
- [x] **`lib/widgets/acl_graph_widget.dart`** — Ligne 152 :
  `..scale(scale, scale, 1.0)` → `..scaleByDouble(scale, scale, 1.0, 1.0)`
  Graphe ACL animé inchangé visuellement.

### 4. Fix dépréciation `Radio.groupValue`/`onChanged` → `RadioGroup`
- [x] **`lib/widgets/shared_routes_access_dialog.dart`** — Les 3 `RadioListTile`
  wrappés dans un `RadioGroup<RouteAccessChoice>` ancêtre (Flutter 3.32+).
  Comportement identique.

### 5. Désactivation Code Spell Checker
- [x] **`.vscode/settings.json`** — `"cSpell.enabled": false` ajouté pour ce workspace.

---

## Fichiers modifiés
| Fichier | Changement |
|---|---|
| `lib/models/user.dart` | Fallback `name` vide OIDC |
| `lib/models/node.dart` | Fallback `node.user` vide OIDC |
| `lib/screens/users_screen.dart` | Auto-renommage OIDC silencieux |
| `lib/screens/dashboard_screen.dart` | Bannière détection nœuds sans utilisateur |
| `lib/widgets/registration_dialogs.dart` | Sélecteur Classique/OIDC + flow OIDC 2 étapes |
| `lib/widgets/acl_graph_widget.dart` | Fix `scaleByDouble` |
| `lib/widgets/shared_routes_access_dialog.dart` | Fix `RadioGroup` |
| `lib/data/whats_new_data.dart` | Entrée version 1.5.105 |
| `lib/screens/home_screen.dart` | `currentVersion` → `1.5.105` |
| `pubspec.yaml` | `version: 1.5.0+105` |
| `.vscode/settings.json` | cSpell désactivé |

---

## Points de vérification (Beta Play Store)
- [ ] User OIDC avec `name=""` → l'app affiche l'email, les ACLs génèrent `tag:jean-client`
- [ ] Ouvrir "Utilisateurs" avec un user OIDC sans nom → renommage auto + rechargement
- [ ] Dashboard avec nœud user vide → bannière orange visible
- [ ] Dialog "Nouvel Appareil" : choix Classique → 3 étapes intactes
- [ ] Dialog "Nouvel Appareil" : choix OIDC → 2 étapes, snippet YAML avec email
- [ ] Graphe ACL : ouverture, zoom/dézoom et animation inchangés
- [ ] Dialog "Accès routes partagées" : 3 choix radio fonctionnels
- [ ] Popup "Nouveautés" s'affiche au premier lancement de la 1.5.105
