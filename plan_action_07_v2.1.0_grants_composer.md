# Plan d'Action 07 — Version 2.1.0 : Composeur de Grants & plus-value UI

**Date** : 11 juillet 2026  
**Version cible** : `2.1.0+142`  
**Prérequis** : Headscale ≥ `0.29.0` + moteur `grantsV29` actif

---

## 1. Objectifs

| # | Objectif | Critère de succès |
|---|---|---|
| O1 | Simplifier la création de règles Grants V29 | Composeur guidé 4 étapes + templates |
| O2 | Gater la nouveauté au bon contexte | Invisible si serveur < 0.29 ou moteur ≠ grantsV29 |
| O3 | Faciliter la maintenance des grants | Édition inline onglet Grants |
| O4 | Renforcer la confiance post-migration | Bandeau « policy migrée » + lien rollback |
| O5 | Améliorer Puzzle (via routeur) | Picker nœuds routeurs à l'étape Via |
| O6 | Conserver l'existant | Puzzle, graphe, Legacy/Standard inchangés |

## 2. Exclus

- Mode sans tags / fallback `group:` auto
- Test connectivité §8.4 (en attente utilisateur)
- go_router, split AppProvider, docs volumineuses

---

## 3. Phases

### PHASE A — Composeur de grants → `2.1.0+142`

| ID | Tâche |
|---|---|
| A-01 | Modèle `GrantTemplate` + service conversion grant JSON |
| A-02 | Widget `GrantComposerSheet` (4 étapes + preview) |
| A-03 | Gating 0.29 + grantsV29 |
| A-04 | Entrées : SpeedDial ACL, FAB onglet Grants, fiche nœud |
| A-05 | Templates : LAN, Internet, Intra-flotte, IP ciblée, Exception ACL |

### PHASE B — Édition inline & bandeau → `2.1.0+142`

| ID | Tâche |
|---|---|
| B-01 | `GrantEditSheet` — tap ligne grant → édition |
| B-02 | Persistance dans policy locale + sync JSON |
| B-03 | `GrantsMigrationBanner` — date migration + actions |
| B-04 | Storage flags migration date |

### PHASE C — Puzzle routeur picker → `2.1.0+142`

| ID | Tâche |
|---|---|
| C-01 | Entités nœud-routeur dans Puzzle (étape Via) |
| C-02 | Mapping nœud → tag lan-sharer / exit-node |

### PHASE D — Release → `2.1.0+142`

| ID | Tâche |
|---|---|
| D-01 | Version pubspec + whats_new 2.1.0 |
| D-02 | Tests unitaires composeur |
| D-03 | flutter analyze + test |

---

## 4. Journal d'avancement

| Date | Phase | Statut | Notes |
|---|---|---|---|
| 2026-07-11 | A–D | ✅ Terminée | Composeur, édition inline, bandeau migration, puzzle routeurs, v2.1.0+142 |

---

## 5. Critères d'acceptation

- [x] Composeur invisible si serveur < 0.29 ou moteur ≠ Grants V29
- [x] Template LAN produit grant avec `via` correct
- [x] Preview JSON = grant ajouté à la policy
- [x] Édition inline modifie 1 grant sans regénération totale
- [x] Bandeau migration affiché après migration auto
- [x] Puzzle : nœuds routeurs proposés à l'étape Via
- [x] Graphe et Puzzle expert inchangés
