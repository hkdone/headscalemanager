# Suivi d'Implémentation — Plans d'Action 08 à 11 (`v2.2.0` → `v2.5.0`)

**Branche de référence (stable) :** `master` *(version actuelle en production : `2.1.9+155`)*  
**Dernière mise à jour :** 16 novembre 2026  

> [!IMPORTANT]
> **Règle de déploiement prudent (1 Plan = 1 Branche = 1 Validation) :**
> Ne jamais développer deux plans simultanément sur la même branche. Chaque plan doit être :
> 1. Développé sur sa branche dédiée créée depuis `master`.
> 2. Validé par `flutter analyze`, `flutter test` et tests manuels sur serveur interne (versions `< 0.28` et `0.29.x`).
> 3. Mergé dans `master` (avec tag Git de version) uniquement une fois tous les critères de non-coupure validés.

---

## 1. Vue d'Ensemble des Plans & Branches

| Plan | Version cible | Branche Git dédiée | Objectif principal | Risque Prod | Statut |
|---|---|---|---|---|---|
| [Plan 08](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_08_v2.2.0_compatibilite_et_securite_acl.md) | `2.2.0+156` | `fix/v2.2.0-compat-non-destructive-acl` | Fusion non-destructive (`ssh`/`hosts`/`tests`), cohérence tags, routes `via` 0.29, HuJSON, PreAuthKey API | 🟡 Moyen | ⬜ À faire |
| [Plan 09](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md) | `2.3.0+157` | `feat/v2.3.0-tagless-hybrid-acl` | Mode ACL **Sans Tags (`tagless`)** + Filet de sécurité Hybride pour nœuds sans tag | 🟠 Moyen-Élevé | ⬜ À faire |
| [Plan 10](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_10_v2.4.0_cybersecurite_et_resilience.md) | `2.4.0+158` | `sec/v2.4.0-cybersecurity-network-hardening` | PIN PBKDF2 + sel (migration transparente), anti-bruteforce, auto-lock, timeouts, SAST 100/100 | 🟢 Faible | ⬜ À faire |
| [Plan 11](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_11_v2.5.0_simulateur_diff_ssh_et_api.md) | `2.5.0+159` | `feat/v2.5.0-simulator-diff-ssh-api-tools` | Diff visuel ligne-par-ligne, Simulateur ACL + `tests`, Onglet SSH, `expireNode`, `backfillips` | 🟢 Très Faible | ⬜ À faire |

**Légende des statuts :** `⬜ À faire` • `🔄 En cours` • `🧪 En test interne` • `✅ Validé & Mergé` • `⏪ Rollback effectué`

---

## 2. Checklist Détaillée d'Implémentation

### Plan 08 (`2.2.0+156`) — Branche `fix/v2.2.0-compat-non-destructive-acl`
- [ ] **08.1** `PolicyPreserver` : fusion non-destructive (`ssh`, `tests`, `ipsets`, `derpMap`, `hosts`, `nodeAttrs`) sur tous les points d'appel `setAclPolicy`
- [ ] **08.2** `TagCapabilityHelper` : unification gestion tags Legacy vs Standard/GrantsV29 + fix nettoyage `tag:<user>-lan-sharer` + fix `registration_dialogs.dart`, `create_pre_auth_key_dialog.dart`, `move_node_dialog.dart`
- [ ] **08.3** `RouteConflictService` : autoriser CIDR partagés entre users différents en mode `grantsV29` ($\ge 0.29$) + alerte pré-rollback dans `SettingsScreen`
- [ ] **08.4** `JsonUtils` : parseur lexical HuJSON complet (`//`, `/* */`, trailing commas) + application dans `AclScreen._fetchAclPolicyFromServer`
- [ ] **08.5** API `PreAuthKey` v0.28+ (`serverVersion` + `keyId`) + encodage `Uri.encodeComponent`
- [ ] **Validation 08** : `flutter analyze` OK • Tests unitaires OK • Test interne approbation route + HuJSON + conservation `ssh` OK

### Plan 09 (`2.3.0+157`) — Branche `feat/v2.3.0-tagless-hybrid-acl`
- [ ] **09.1** `AclEngineMode.tagless` + `TaglessAclGeneratorService` (`group:` + `hosts` + `autoApprovers` sans tags)
- [ ] **09.2** Filet de sécurité Hybride dans `StandardAclGeneratorService` & `GrantsV29GeneratorService` (+ option désactivable)
- [ ] **09.3** Support `hosts` et `group:` sans tag dans `AclParserService`, `AclGraphWidget`, `GrantComposerService`, `AclPuzzleScreen` (+ fix normalisation `group:` dans Puzzle)
- [ ] **09.4** Adaptation UI : `SettingsScreen`, `AclEngineBanner`, `registration_dialogs.dart` (tags optionnels en mode `tagless`)
- [ ] **Validation 09** : Test non-régression JSON identique sur flotte 100% taguée • Test flotte 100% sans tags • Test flotte mixte • Test Graphe/Puzzle OK

### Plan 10 (`2.4.0+158`) — Branche `sec/v2.4.0-cybersecurity-network-hardening`
- [ ] **10.1** `SecurityService` : PBKDF2-HMAC-SHA256 + sel aléatoire + migration transparente depuis SHA-256 + lockout anti-bruteforce (`LockScreen`)
- [ ] **10.2** Re-verrouillage automatique en arrière-plan (`main.dart` + `SecuritySettingsScreen` + protection `FilePicker`/biométrie)
- [ ] **10.3** Timeouts HTTP 20s + alerte `http://` public (`AddEditServerScreen`) + remédiation 3 alertes SAST (`catch` silencieux) + `.gitignore`
- [ ] **10.4** `NetworkOverviewScreen` : diagnostic IP publique / traceroute déclenché uniquement sur action utilisateur
- [ ] **Validation 10** : Test unitaire migration PIN SHA-256 $\rightarrow$ PBKDF2 • Test lockout 5 essais • Re-scan SAST 100/100

### Plan 11 (`2.5.0+159`) — Branche `feat/v2.5.0-simulator-diff-ssh-api-tools`
- [ ] **11.1** `JsonDiffUtils` + `PolicyDiffDialog` v2 (comparateur coloré `+`/`-` face à la policy serveur réelle)
- [ ] **11.2** `AclSimulatorSheet` + `AclParserService.simulateConnection` + génération/validation du bloc `"tests"` (Headscale $\ge 0.29$)
- [ ] **11.3** Onglet SSH dans `AclScreen` (`SshRulesListView` + validation Tailscale SSH)
- [ ] **11.4** API `expireNode` (dans `NodeDetailScreen` & `UserDetailScreen`) + `backfillNodeIps` (dans `SettingsScreen`)
- [ ] **Validation 11** : Tests unitaires Diff & Simulateur • Test interne `expireNode` + `tests` Headscale 0.29.7

---

## 3. Journal de Progression & Incidents

| Date | Plan / Tâche | Branche | Auteur | Résultat / Observations de test interne |
|---|---|---|---|---|
| 2026-11-16 | Initialisation | `master` | Architecture & Sécurité | Création des plans 08 à 11 et du suivi d'implémentation après audit complet du codebase (`2.1.9+155`). |
| — | — | — | — | — |
