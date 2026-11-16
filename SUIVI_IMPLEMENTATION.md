# Suivi d'Implémentation — Ordre Logique & Graduel (du moins risqué au plus risqué)

**Branche de référence (stable) :** `master` *(version actuelle : `2.2.0+157`)*  
**Dernière mise à jour :** 16 novembre 2026  

---

## 1. Ordre d'Exécution Recommandé & Dépendances

L'ordre ci-dessous classe les plans **du risque de casse en production le plus faible au plus élevé**, tout en respectant strictement les **dépendances techniques** :

```text
[Étape 1] Plan 10 : Cybersécurité & Résilience (0 dépendance • Risque 🟢 Très Faible)
    │  (Hardening local : PIN PBKDF2 migré sans coupure, timeouts HTTP, SAST 100/100)
    ▼
[Étape 2] Plan 08 : Compatibilité Multi-Versions & Fusion Non-Destructive (0 dépendance • Risque 🟡 Moyen)
    │  (Prérequis fondamental : PolicyPreserver, HuJSON, TagCapabilityHelper, aclEngineMode par serveur)
    ├──────────────────────────────────────────┐
    ▼                                          │
[Étape 3] Plan 11 : Outils Visuels & API       │ (Dépend de Plan 08 • Risque 🟢 Très Faible)
    │  (Diff Visuel + Simulateur ACL + SSH + expireNode + backfillips)
    │  👉 Fournit le Diff & Simulateur pour vérifier visuellement l'Étape 4 !
    ▼                                          ▼
[Étape 4] Plan 09 : Mode ACL Sans Tags & Stop Auto-Tagging (Dépend de Plan 08 • Risque 🟠 Moyen-Élevé)
       (Moteur tagless, arrêt auto-tagging PreAuthKey/Registration/Dashboard, filet Hybride)
```

### Pourquoi cet ordre est le plus sûr ?
1. **Étape 1 ([Plan 10](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_10_v2.4.0_cybersecurite_et_resilience.md))** ne touche **ni aux ACLs, ni aux tags, ni aux routes serveur**. Aucun trafic VPN utilisateur ne peut être coupé. Il corrige l'audit SAST à 100/100 et protège le PIN avec migration transparente.
2. **Étape 2 ([Plan 08](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_08_v2.2.0_compatibilite_et_securite_acl.md))** pose les fondations indispensables avant toute nouvelle fonctionnalité ACL : il empêche d'écraser les règles `ssh`/`hosts`/`tests` du serveur (`PolicyPreserver`), corrige les tags `;` résiduels, isole `aclEngineMode` par serveur, et répare le parseur HuJSON.
3. **Étape 3 ([Plan 11](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_11_v2.5.0_simulateur_diff_ssh_et_api.md))** est **100% additive** (risque très faible) et ne dépend que du Plan 08. Le faire **avant** le Plan 09 permet d'utiliser le **Diff Visuel ligne-par-ligne** et le **Simulateur ACL** pour vérifier en interne chaque JSON généré par le futur mode Sans Tags !
4. **Étape 4 ([Plan 09](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md))** est le chantier le plus sensible (il change le flux PreAuthKey/Enregistrement/Approbation pour stopper l'auto-tagging et ajoute le moteur `tagless` + filet Hybride). Le faire en dernier, protégé par `PolicyPreserver` (Plan 08) et contrôlable via le `Diff Visuel` + `Simulateur` (Plan 11), réduit drastiquement le risque de casse en production.

> [!IMPORTANT]
> **Règle d'or entre chaque étape :**
> - Créer la branche depuis `master` à jour.
> - À chaque release mergée dans `master`, aligner `pubspec.yaml`, `lib/screens/home_screen.dart` (`currentVersion`) et `lib/data/whats_new_data.dart` avec le numéro de version séquentiel (`2.2.0+156` $\rightarrow$ `2.3.0+157` $\rightarrow$ `2.4.0+158` $\rightarrow$ `2.5.0+159`).
> - **Ne jamais démarrer l'étape N+1 avant d'avoir exécuté la checklist de validation interne de l'étape N.**

---

## 2. Tableau de Bord des Étapes & Branches

| Ordre | Plan | Version de release | Branche Git dédiée | Dépendances | Risque Prod | Statut |
|---|---|---|---|---|---|---|
| **1** | [Plan 10 — Cybersécurité & Résilience](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_10_v2.4.0_cybersecurite_et_resilience.md) | `2.2.0+157` | `sec/hardening-pin-network-sast` | Aucune | 🟢 Très Faible | ✅ Validé & Mergé |
| **2** | [Plan 08 — Compatibilité & Non-Destructif](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_08_v2.2.0_compatibilite_et_securite_acl.md) | `2.3.0+158` | `fix/compat-non-destructive-acl` | Aucune | 🟡 Moyen | ✅ Validé & Mergé |
| **3** | [Plan 11 — Diff, Simulateur, SSH & API](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_11_v2.5.0_simulateur_diff_ssh_et_api.md) | `2.4.0+160` | `feat/acl-simulator-diff-ssh-api` | Plan 08 | 🟢 Très Faible | ✅ Validé & Mergé |
| **4** | [Plan 09 — Mode Sans Tags & Hybride](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md) | `2.5.0+160` | `feat/acl-tagless-and-hybrid` | Plan 08 *(Plan 11 rec.)* | 🟠 Moyen-Élevé | ⬜ À faire |

**Légende des statuts :** `⬜ À faire` • `🔄 En cours` • `🧪 En test interne` • `✅ Validé & Mergé` • `⏪ Rollback effectué`

---

## 3. Checklists Détaillées par Étape

### Étape 1 — Plan 10 (`sec/hardening-pin-network-sast` → `2.2.0+157`)
- [x] **10.1** `SecurityService` : PBKDF2-HMAC-SHA256 + sel aléatoire + comparaison temps constant + migration transparente depuis SHA-256 + lockout anti-bruteforce (`LockScreen`) + support 4/6 chiffres (`SetupPinScreen`)
- [x] **10.2** Re-verrouillage automatique en arrière-plan (`main.dart` + `SecuritySettingsScreen` + protection `FilePicker`/`ImagePicker`/biométrie)
- [x] **10.3** Timeouts HTTP 20s + alerte `http://` public (`AddEditServerScreen`) + remédiation 3 alertes SAST (`SecurityService`, `StorageService`, `AclScreen`) + `.gitignore`
- [x] **10.4** `NetworkOverviewScreen` : diagnostic IP publique / traceroute déclenché uniquement sur clic utilisateur
- [x] **Gate 1 (Validation avant merge)** : `flutter analyze` (0 erreur/info) ✅ • 36/36 tests unitaires ✅ • Test manuel interne sur appareil (ancien PIN migré, auto-lock, alerte HTTP, diagnostic sortie Internet) ✅ • Merge `sec/hardening-pin-network-sast` → `master` ✅

### Étape 2 — Plan 08 (`fix/compat-non-destructive-acl` → `2.3.0+158`)
- [x] **08.1** `PolicyPreserver` : fusion non-destructive (`ssh`, `tests`, `ipsets`, `derpMap`, `hosts`, `nodeAttrs`) sur **tous** les appels `setAclPolicy` (y compris `RenameNodeDialog`, `ManageSpecificRulesDialog`, `LegacyMigrationDialog`)
- [x] **08.2** `TagCapabilityHelper` : unification gestion tags Legacy vs Standard/GrantsV29 + fix nettoyage `tag:<user>-lan-sharer` + fix `registration_dialogs.dart`, `create_pre_auth_key_dialog.dart`, `move_node_dialog.dart`
- [x] **08.3** `RouteConflictService` : autoriser CIDR partagés entre users différents en mode `grantsV29` ($\ge 0.29$) + alerte pré-rollback dans `SettingsScreen`
- [x] **08.4** `JsonUtils` : parseur lexical HuJSON complet (`//`, `/* */`, trailing commas) + application dans `AclScreen._fetchAclPolicyFromServer`
- [x] **08.5** API `PreAuthKey` v0.28+ (`serverVersion` + `keyId`) + encodage `Uri.encodeComponent`
- [x] **08.6** Isolation `aclEngineMode` par `serverId` dans `StorageService` / `AppProvider` (avec fallback sur la clé globale existante)
- [x] **Gate 2 (Validation avant merge)** : `flutter analyze` (0 erreur/info) ✅ • 55/55 tests unitaires ✅ • Versionning `2.3.0+158` ✅ • Test interne conservation `ssh`/`hosts`, approbation route 0.29, synchro éditeur JSON/orphelins et bascule multi-serveurs ✅ (commentaires HuJSON ↔ Puzzle et détail 6-7 différés au test conjoint Étape 3)

### Étape 3 — Plan 11 (`feat/acl-simulator-diff-ssh-api` → `2.4.0+160`)
- [x] **11.1** `JsonDiffUtils` + `PolicyDiffDialog` v2 (comparateur coloré `+`/`-` face à la policy serveur réelle)
- [x] **11.2** `AclSimulatorSheet` + `AclParserService.simulateConnection` + génération/validation du bloc `"tests"` (Headscale $\ge 0.29$)
- [x] **11.3** Onglet SSH dans `AclScreen` (`SshRulesListView` + validation Tailscale SSH)
- [x] **11.4** API `expireNode` (dans `NodeDetailScreen` & `UserDetailScreen`) + `backfillNodeIps` (dans `SettingsScreen`)
- [x] **Gate 3 (Validation avant merge)** : `flutter analyze` OK (0 issue) ✅ • Tests unitaires Diff & Simulateur OK (64/64) ✅ • Test interne validé + correctifs Puzzle Diff, port unique `"tests"` & préservation OIDC ✅ • Versionning `2.4.0+160` ✅

### Étape 4 — Plan 09 (`feat/acl-tagless-and-hybrid` → `2.5.0+160`)
- [ ] **09.1** `AclEngineMode.tagless` + `TaglessAclGeneratorService` (`group:` + `hosts` + `autoApprovers` + tolérance rétroactive machines déjà taguées)
- [ ] **09.2** Stopper l'auto-tagging en mode `tagless` dans `CreatePreAuthKeyDialog` (`aclTags: null` par défaut), `registration_dialogs.dart` (sauter étape tags), `DashboardScreen` (y compris fix bug `tag:exit-node` sans user), `ExitNodeCommandDialog`, `ShareSubnetDialog` + guide ré-auth sans tag dans `EditTagsDialog`
- [ ] **09.3** Filet de sécurité Hybride dans `StandardAclGeneratorService` & `GrantsV29GeneratorService` (+ option désactivable)
- [ ] **09.4** Empêcher popup/auto-bascule `GrantsMigrationDialog` si mode `tagless` (`HomeScreen` & `AppProvider`), ouvrir `GrantsV29Gate` / `GrantEditSheet` au mode `tagless`, support `hosts` & `group:` dans `AclParserService` (Graphe + Simulateur), `GrantComposerService`, `AclPuzzleScreen` (+ fix normalisation `group:` dans Puzzle), `SettingsScreen` & `AclEngineBanner`
- [ ] **Gate 4 (Validation avant merge)** : Test non-régression JSON identique sur flotte 100% taguée • Test enregistrement + PreAuthKey sans tag • Test flotte mixte (tagués + non-tagués) • Vérification via Diff Visuel & Simulateur (Plan 11) • Versionning `2.5.0+160`

---

## 4. Journal de Progression & Incidents

| Date | Étape / Plan | Branche | Résultat / Observations de test interne |
|---|---|---|---|
| 2026-11-16 | Initialisation & Audit | `master` | Création et audit croisé des plans 08 à 11 ; mise en place de l'ordre graduel 10 $\rightarrow$ 08 $\rightarrow$ 11 $\rightarrow$ 09. |
| 2026-11-16 | Étape 1 — Plan 10 | `sec/hardening-pin-network-sast` | Implémentation PBKDF2 + migration PIN, lockout, auto-lock arrière-plan, timeouts HTTP 20s, alerte HTTP, diagnostic opt-in, remédiation SAST. `flutter analyze` (0 issue), 36/36 tests passés, test manuel interne validé. Mergé dans `master`. |
| 2026-11-16 | Étape 2 — Plan 08 | `fix/compat-non-destructive-acl` | Implémentation `PolicyPreserver`, `TagCapabilityHelper`, `RouteConflictService` (via 0.29+ & garde-fou rollback), parseur lexical HuJSON (`JsonUtils`), API PreAuthKey v0.28+ & `Uri.encodeComponent`, isolation `aclEngineMode` par `serverId`, synchro éditeur JSON/serveur + `PolicyOrphanCleaner` + sanctuarisation commentaires HuJSON ↔ Puzzle (`HuJsonCommentService`). `flutter analyze` (0 issue) & 55/55 tests passés (`2.3.0+158`). Validé et mergé dans `master`. |
| 2026-11-16 | Étape 3 — Plan 11 | `feat/acl-simulator-diff-ssh-api` | Implémentation `JsonDiffUtils` + `PolicyDiffDialog` v2 (y compris Vue Puzzle), `AclSimulatorSheet` + `simulateConnection` + validation/port unique bloc `"tests"`, onglet SSH (`SshRulesListView` + `SshRuleValidator`), `expireNode` + `backfillNodeIps`, et fix matching OIDC + préservation des règles personnalisées à la régénération. `flutter analyze` (0 issue) & 64/64 tests passés (`2.4.0+160`). Validé et mergé dans `master`. Plan 09 différé avant publication des 3 premiers plans. |
