# Plan d'Action 06 — Version 2.0.0 : Moteur ACL Grants/`via` (Headscale 0.29+)

**Date** : 11 juillet 2026  
**Version cible release** : `2.0.0+141` *(publié en test fermé)*  
**Version serveur cible** : Headscale ≥ `0.29.0` (rétrocompatibilité < 0.29)

---

## 1. Objectifs

| # | Objectif | Critère de succès |
|---|---|---|
| O1 | Isoler les LAN identiques (`192.168.1.0/24`) par utilisateur via `grants` + `via` | Jean et Clarisse partagent le même CIDR sans collision |
| O2 | Conserver le fonctionnement actuel sur serveurs < 0.29 | Aucune régression Legacy / Standard |
| O3 | Bascule automatique + manuelle selon version Headscale | 3 moteurs sélectionnables en Paramètres |
| O4 | Refondre ACL, Puzzle et règles spécifiques autour du nouveau modèle | UI cohérente, export JSON valide |
| O5 | Corriger la dette technique identifiée | Orchestrateur unique, tests, doc à jour |
| O6 | Documenter et versionner proprement | README, aides in-app, whats_new, pubspec alignés |

---

## 2. Périmètre

### Inclus
- Nouveau moteur `GrantsV29`
- Orchestrateur central des politiques ACL
- Refonte écrans ACL / Puzzle / exceptions / dashboard
- Wizard de migration 0.29
- Corrections bugs connus (parser Taildrive, dashboard ignore Standard)
- Tests unitaires critiques
- Documentation complète
- Versionning `2.0.0`

### Exclus (report v2.1+)
- `go_router` (navigation globale)
- Découpage complet de `AppProvider`
- Bloc `tests` / `sshTests` Headscale (beta)
- i18n complète des messages d'erreur API

---

## 3. Architecture cible

```
lib/services/acl/
├── acl_engine_mode.dart
├── acl_policy_orchestrator.dart
├── policy_infrastructure_builder.dart
├── taildrive_builder.dart
├── legacy_acl_generator.dart          # ex-NewAclGeneratorService
├── standard_acl_generator.dart        # ex-StandardAclGeneratorService
└── grants_v29_generator.dart          # NOUVEAU (Phase 1)

lib/models/
├── exception_rule.dart
└── acl_generation_result.dart

lib/widgets/
└── grants_migration_dialog.dart
```

---

## 4. Phases

### PHASE 0 — Préparation & dette technique → `1.9.2+133` ✅

| ID | Tâche | Fichiers | Statut |
|---|---|---|---|
| P0-01 | Corriger chemin keystore Android | `android/app/build.gradle.kts` | ✅ |
| P0-02 | Créer `AclPolicyOrchestrator` | `lib/services/acl/` | ✅ |
| P0-03 | Extraire `PolicyInfrastructureBuilder` | `lib/services/acl/` | ✅ |
| P0-04 | Extraire `TaildriveBuilder` | `lib/services/acl/` | ✅ |
| P0-05 | Remplacer instanciations directes (~15 sites) | dashboard, acl_screen, puzzle, dialogs… | ✅ (12 sites) |
| P0-06 | Dashboard : respecter `useStandardAclEngine` | `dashboard_screen.dart` | ✅ |
| P0-07 | Parser Taildrive `cap/drive` | `acl_parser_service.dart` | ✅ |
| P0-08 | Tests unitaires orchestrateur | `test/services/acl/` | ✅ |
| P0-09 | Aligner `currentVersion` sur `pubspec.yaml` | `home_screen.dart` | ✅ |

### PHASE 1 — Moteur Grants V29 → `1.10.0+134` ✅

| ID | Tâche | Statut |
|---|---|---|
| P1-01 | `AclEngineMode` enum + persistance par serveur | ✅ |
| P1-02 | `GrantsV29Generator` (grants `ip` + `via`) | ✅ |
| P1-03–06 | Grants intra-user, LAN, Internet, groupe | ✅ |
| P1-07 | Taildrive via `TaildriveBuilder` | ✅ |
| P1-08 | Modèle `ExceptionRule` avec `via` | ⬜ reporté v2.1 (Map conservé) |
| P1-09 | Auto-sélection si serveur ≥ 0.29 | ✅ |
| P1-10 | UI Paramètres : sélecteur 3 moteurs | ✅ |
| P1-11 | Blocage Grants sur serveur < 0.29 | ✅ |
| P1-12 | Warning utilisateurs sans nœud tagué | ✅ |
| P1-13 | Tests Jean/Clarisse `192.168.1.0/24` | ✅ |

### PHASE 2 — Refonte écrans ACL → `2.0.0-beta+135` ✅ (~90 %)

| ID | Tâche | Statut |
|---|---|---|
| P2-01–04 | Bandeau moteur, onglets JSON, sélecteur via, preview diff | ✅ (via = Puzzle, affichage ACL) |
| P2-05–07 | Dashboard + dialogs → orchestrateur | ✅ |
| P2-08 | Graphe ACL arêtes `via` | ✅ (+ fix crash/positionnement build 141) |
| P2-09 | Extraire widgets écrans > 800 lignes | ⚠️ partiel (widgets ACL extraits, écrans encore volumineux) |

### PHASE 3 — Refonte Puzzle → `2.0.0-beta+136` ✅

| ID | Tâche | Statut |
|---|---|---|
| P3-01–07 | PuzzleRule enrichi, grants parser, UI 3 colonnes | ✅ |

### PHASE 4 — Migration & release → `2.0.0+141` ⚠️

| ID | Tâche | Statut |
|---|---|---|
| P4-01 | Wizard migration 0.29 | ✅ |
| P4-02 | Rollback moteur | ✅ |
| P4-03–04 | Versionning + documentation | ✅ version / ⚠️ `project_summary` + `api_cli` reportés |
| P4-05 | Tests manuels | ⚠️ partiel (voir RAPPORT §8) |
| P4-06 | Play Store | 🔄 AAB 141 généré, upload en cours |

---

## 5. Versionning — checklist

| Fichier | v2.0.0 | Statut |
|---|---|---|
| `pubspec.yaml` | `2.0.0+141` | ✅ |
| `lib/screens/home_screen.dart` | `currentVersion = '2.0.0'` | ✅ |
| `lib/data/whats_new_data.dart` | entrée `2.0.0` | ✅ |

---

## 6. Documentation

| Fichier | Action | Statut |
|---|---|---|
| `README.md` / `README.En.md` | Section moteurs ACL, grants/via, upgrade 0.29 | ✅ |
| `project_summary.md` | Réécriture complète | ⬜ reporté v2.1 |
| `api_cli_functions_guide.md` | Corriger noms API + grants | ⬜ reporté v2.1 |
| `help_screen.dart` / `help_screen_en.dart` | Sections Grants, Via, Migration 0.29 | ✅ |

---

## 7. Tests release 2.0.0

- [x] Orchestrateur sélectionne bon moteur
- [x] Jean + Clarisse même CIDR → 2 grants `via` distincts
- [x] Politique Legacy/Standard inchangée sur serveur actuel *(phase 1 OK)*
- [x] Taildrive `cap/drive` parser OK
- [x] helene974 sans nœud → warning documenté *(constaté en prod)*
- [ ] Rollback Grants → Standard OK *(non testé manuellement)*

---

## 8. Calendrier

```
Semaine  1       Phase 0   → 1.9.2
Semaine  2-3     Phase 1   → 1.10.0
Semaine  4-5     Phase 2   → 2.0.0-beta
Semaine  6-7     Phase 3   → 2.0.0-beta
Semaine  8       Phase 4   → 2.0.0
```

---

## 9. Journal d'avancement

| Date | Phase | Statut | Notes |
|---|---|---|---|
| 2026-07-11 | Phase 0 | ✅ Terminée | Orchestrateur, TaildriveBuilder, 12 call sites migrés, parser fix, keystore, v1.9.2+133 |
| 2026-07-11 | Phase 1 | ✅ Terminée | GrantsV29, auto-upgrade 0.29, tests Jean/Clarisse, v1.10.0+134 |
| 2026-07-11 | Phase 2 | ✅ ~90 % | Onglets ACL, bandeau, diff export, graphe via (+ fix 141) ; P2-09 partiel |
| 2026-07-11 | Phase 3 | ✅ Terminée | Puzzle 3 colonnes, wizard via, round-trip test |
| 2026-07-11 | Phase 4 | ⚠️ En cours | Wizard/rollback OK, AAB 141, tests manuels §8 partiels, 2 docs reportées |
