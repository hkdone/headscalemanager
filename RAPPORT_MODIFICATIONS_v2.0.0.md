# Rapport de modifications — Headscale Manager v2.0.0

**Date** : 11 juillet 2026  
**Version** : `2.0.0+141`  
**Périmètre** : Phases 0 à 4 du plan Grants/`via` (Headscale ≥ 0.29)

---

## 1. Résumé exécutif

L'application intègre désormais un **moteur ACL Grants V29** complet avec routage **`via`**, une **refonte UI** des écrans ACL et Puzzle, un **wizard de migration**, et la **documentation** associée. Le backend (Phase 0–1) et la couche UI (Phases 2–4) sont implémentés.

---

## 2. Phases réalisées

| Phase | Version | Statut |
|---|---|---|
| **0** — Orchestrateur, TaildriveBuilder, dette technique | `1.9.2+133` | ✅ |
| **1** — Moteur Grants V29 | `1.10.0+134` | ✅ |
| **2** — Refonte écran ACL | `2.0.0-beta+135` | ✅ |
| **3** — Refonte Puzzle 3 colonnes | `2.0.0-beta+136` | ✅ |
| **4** — Migration, doc, release | `2.0.0+141` | ✅ |

---

## 3. Fichiers créés

| Fichier | Description |
|---|---|
| `lib/services/acl/acl_policy_orchestrator.dart` | Point d'entrée unique génération ACL |
| `lib/services/acl/grants_v29_generator.dart` | Grants avec `via` (LAN, exit, intra-flotte) |
| `lib/services/acl/policy_infrastructure_builder.dart` | Groups, tagOwners, autoApprovers |
| `lib/services/acl/taildrive_builder.dart` | Grants/nodeAttrs Taildrive |
| `lib/models/acl_engine_mode.dart` | Enum `legacy \| standard \| grantsV29` |
| `lib/widgets/acl/acl_engine_banner.dart` | Bandeau moteur + warnings |
| `lib/widgets/acl/grants_list_view.dart` | Vue structurée des grants |
| `lib/widgets/acl/acls_list_view.dart` | Vue structurée des ACLs |
| `lib/widgets/acl/policy_diff_dialog.dart` | Aperçu diff avant export |
| `lib/widgets/grants_migration_dialog.dart` | Wizard migration Grants V29 |
| `test/services/acl/acl_policy_orchestrator_test.dart` | Tests orchestrateur |
| `test/services/acl/grants_v29_generator_test.dart` | Tests Jean/Clarisse CIDR |
| `test/services/acl/acl_puzzle_service_test.dart` | Test round-trip grants ↔ puzzle |
| `plan_action_06_v2.0.0_grants_via.md` | Plan d'action détaillé |

---

## 4. Fichiers modifiés (principaux)

### Backend / moteurs ACL
- `lib/providers/app_provider.dart` — `aclEngineMode`, auto-upgrade 0.29
- `lib/services/storage_service.dart` — persistance moteur + flags migration
- `lib/services/acl_parser_service.dart` — parsing grants réseau `{ ip, via }`
- `lib/services/acl_puzzle_service.dart` — parse/convert grants + via
- `lib/models/acl_puzzle_model.dart` — `PuzzleRule.via`, `isGrant`

### UI
- `lib/screens/acl_screen.dart` — onglets Grants/ACLs/JSON, bandeau, diff export
- `lib/screens/acl_puzzle_screen.dart` — 3 colonnes, wizard 3 étapes
- `lib/screens/settings_screen.dart` — sélecteur 3 moteurs, migration/rollback
- `lib/screens/home_screen.dart` — wizard auto + version 2.0.0
- ~15 dialogs/écrans — migration vers `engineMode:` orchestrateur

### Versionning & doc
- `pubspec.yaml` → `2.0.0+141`
- `lib/data/whats_new_data.dart` — entrées 1.10.0 et 2.0.0
- `README.md`, `README.En.md` — section moteurs ACL
- `lib/screens/help_screen.dart`, `help_screen_en.dart` — section Grants V29
- `android/app/build.gradle.kts` — keystore relatif (Phase 0)

---

## 5. Architecture cible (implémentée)

```
AclPolicyOrchestrator.generatePolicy(engineMode: ...)
  ├── legacy    → NewAclGeneratorService
  ├── standard  → StandardAclGeneratorService
  └── grantsV29 → GrantsV29GeneratorService (fallback Standard si < 0.29)
```

### Logique Grants V29 (par utilisateur tagué)
1. Grant intra-flotte : `src/dst` = tags, `ip: ["*"]` (sans via)
2. Internet : `dst: [autogroup:internet]`, `via: [tag:X-exit-node]`
3. LAN : `dst: [CIDR]`, `via: [tag:X-lan-sharer]` — **isolation multi-utilisateurs même CIDR**
4. Groupe → flotte : `src: [group:X]`, `dst: tags`
5. Règles temporaires → restent dans `acls[]`
6. Taildrive → grants `app` + `nodeAttrs` fusionnés

---

## 6. Fonctionnalités UI v2.0

### Écran ACL
- Bandeau moteur actif + warning utilisateurs sans nœud tagué
- Onglet **Grants** : liste grants réseau et Taildrive
- Onglet **ACLs** : règles classiques + exceptions temporaires
- Onglet **JSON** : édition brute synchronisée
- Export serveur avec **aperçu diff** (compteur grants/acls/groupes)

### Puzzle ACL
- Layout **Source | Via | Destination**
- Wizard création : 3 étapes en mode Grants V29
- Preview JSON grant ou ACL selon le type de règle

### Migration
- **Wizard auto** au lancement si serveur ≥ 0.29, moteur ≠ grantsV29, pas de tags legacy
- **Paramètres** : Migrer vers Grants V29 / Rollback Grants → Standard
- **Legacy** : wizard tags fusionnés inchangé (`legacy_migration_dialog.dart`)

---

## 7. Tests automatisés exécutés

```bash
flutter analyze          # OK — aucun problème
flutter test test/services/acl/   # 9 tests passent
```

| Test | Vérifie |
|---|---|
| Orchestrateur standard/legacy | Génération ACL classique |
| Grants Jean + Clarisse | 2 grants `via` distincts sur `192.168.1.0/24` |
| Fallback grantsV29 < 0.29 | Retour Standard |
| TaildriveBuilder | Version gate 0.29 |
| Puzzle round-trip | Grant `via` préservé parse → convert |

---

## 8. Plan de tests manuels (compte test)

> À réaliser après publication sur votre compte test Headscale ≥ 0.29.

### 8.1 Prérequis
- [x] Serveur Headscale **≥ 0.29.0** sur compte test
- [x] Au moins 2 utilisateurs (ex. Jean, Clarisse) avec nœuds tagués `-client`
- [x] Un nœud `-lan-sharer` par utilisateur partageant `192.168.1.0/24`
- [ ] VPN **coupé** sur l'appareil de test pendant les migrations *(non confirmé)*

### 8.2 Moteurs ACL (Paramètres)
- [x] **Legacy** : génération policy → tags fusionnés dans JSON *(phase 1 OK)*
- [x] **Standard** : tags séparés `-client`, `-exit-node`, `-lan-sharer` *(phase 1 OK)*
- [x] **Grants V29** : clé `grants[]` présente, pas de collision LAN *(auto-migration + tests unitaires)*
- [ ] Grants V29 **grisé** si serveur < 0.29 *(non testé — prod en 0.29)*
- [x] Auto-upgrade vers Grants V29 au premier chargement (serveur 0.29+, pas de choix explicite)

### 8.3 Écran ACL
- [x] Bandeau affiche le bon moteur
- [x] Warning si utilisateur sans nœud tagué (ex. helene974)
- [x] Onglet **Grants** : grants LAN avec `via: tag:X-lan-sharer`
- [ ] Onglet **ACLs** : règles temporaires / exceptions *(non vérifié manuellement)*
- [ ] Onglet **JSON** : édition manuelle + sync onglets *(non vérifié manuellement)*
- [ ] **Exporter** → dialog diff → application serveur OK *(non vérifié manuellement)*
- [x] **Générer politique** → JSON valide Headscale *(policy auto-migrée au 1er lancement)*

### 8.4 Jean + Clarisse — collision CIDR (test critique)
- [x] Jean : grant `{ dst: ["192.168.1.0/24"], via: ["tag:jean-lan-sharer"] }` *(policy générée)*
- [x] Clarisse : grant `{ dst: ["192.168.1.0/24"], via: ["tag:clarisse-lan-sharer"] }` *(policy générée)*
- [ ] Connectivité : Jean accède à **son** LAN via son routeur, pas celui de Clarisse *(test réseau réel requis)*
- [ ] Idem pour Clarisse *(test réseau réel requis)*

### 8.5 Exit node via grants
- [ ] Utilisateur avec `-exit-node` tagué *(non confirmé)*
- [ ] Grant internet : `via: [tag:X-exit-node]`
- [ ] Trafic internet sort via le bon nœud

### 8.6 Puzzle ACL
- [ ] Chargement policy serveur → règles grants visibles avec colonne **Via**
- [ ] Création règle 3 étapes (source → via → destination)
- [ ] Application policy → grants corrects sur serveur
- [ ] Réordonnancement règles (drag) OK

### 8.7 Graphe ACL (AclManagerScreen)
- [x] Accès LAN visible depuis nœuds autorisés *(fix crash + positionnement build 141)*
- [x] Exit node affiché avec routage correct *(fix positionnement build 141)*
- [ ] Taildrive grants visibles *(si Taildrive configuré — non confirmé)*

### 8.8 Migration Grants V29
- [x] Wizard au premier lancement (serveur 0.29, moteur Standard) *(migration auto constatée)*
- [ ] « Plus tard » → ne réapparaît plus (dismissed)
- [ ] Migration manuelle Paramètres → policy régénérée et poussée
- [ ] **Rollback Grants → Standard** → moteur Standard, regénérer policy

### 8.9 Migration Legacy (si applicable)
- [ ] Tags `;` détectés → wizard legacy
- [ ] Migration tags → Standard → pas de tags fusionnés restants

### 8.10 Taildrive
- [ ] Partages configurés → grants `cap/drive` + `nodeAttrs`
- [ ] Parser et UI Taildrive OK

### 8.11 Non-régression
- [x] Dashboard : approbation routes / exit node avec bon moteur *(phase 1 OK)*
- [ ] Dialogs (tags, subnet, exit node) → policy cohérente
- [ ] Serveur < 0.29 : aucune régression Legacy/Standard *(non testé)*
- [x] What's New 2.0.0 affiché au premier lancement

### 8.12 Règles IP manuelles existantes
- [ ] Conserver les 2 règles `100.64.0.10/12 → 100.64.0.15` après migration
- [ ] Vérifier qu'elles apparaissent dans onglet ACLs

---

## 9. Points d'attention / limites connues

| Item | Détail | Statut |
|---|---|---|
| Puzzle + orchestrateur | Si puzzle vide en mode grants, la policy orchestrateur est utilisée telle quelle | Connu |
| Édition JSON manuelle | Peut désynchroniser les onglets Grants/ACLs jusqu'à regénération | Connu |
| `project_summary.md` | Non réécrit (prévu plan P4) | **Reporté v2.1** |
| `api_cli_functions_guide.md` | Non mis à jour intégralement | **Reporté v2.1** |
| `ExceptionRule` typé (P1-08) | Règles temporaires encore en `Map` | **Reporté v2.1** |
| Écrans >800 lignes (P2-09) | Extraction partielle seulement | **Reporté v2.1** |
| i18n erreurs API | — | Report v2.1 |
| go_router / split AppProvider | — | Report v2.1 |
| cmdline-tools Android | Build AAB OK mais exit code 1 si cmdline-tools absent | **À corriger post-release** |
| Kotlin Built-in migration | Warning `share_plus`, `workmanager_android` | **Surveiller avant prochain flutter upgrade** |

---

## 10. Bilan audit implémentation (11/07/2026)

| Phase | Code | Doc | Tests auto | Tests manuels |
|---|---|---|---|---|
| **0** Orchestrateur | ✅ 100 % | ✅ | ✅ 4 tests | ✅ phase 1 OK |
| **1** Grants V29 | ✅ ~95 % (P1-08 ExceptionRule absent) | ✅ | ✅ 4 tests | ✅ auto-migration |
| **2** UI ACL | ✅ ~90 % (P2-09 écrans volumineux) | ✅ README/help | — | ⚠️ partiel |
| **3** Puzzle 3 col. | ✅ 100 % | ✅ | ✅ 1 test | ⬜ non testé |
| **4** Migration/release | ✅ wizard + rollback | ⚠️ 2 docs reportées | ✅ 9/9 | ⚠️ §8 partiel |

**Verdict** : release **2.0.0+141** prête pour test fermé Play Store. Validation réseau LAN (§8.4) reste le test critique avant prod.

---

## 11. Procédure de déploiement recommandée

1. Publier `2.0.0+141` sur compte test
2. Vérifier version serveur Headscale affichée (Paramètres)
3. Exécuter checklist section 8 sur compte test
4. Migrer production après validation Jean/Clarisse CIDR
5. Conserver backup policy ACL avant migration (`Exporter` / partage fichier)

---

## 12. Commandes utiles

```bash
flutter pub get
flutter analyze
flutter test test/services/acl/
flutter build appbundle --release --no-tree-shake-icons
```

---

*Rapport mis à jour — Headscale Manager v2.0.0+141 Grants/via*
