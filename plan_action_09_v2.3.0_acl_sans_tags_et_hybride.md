# Plan d'Action 09 (Plan Maître) — Gouvernance $N-2$, Alignement Intelligent, Mode Hybride, Centre de Bascule & Moteur "Sans Tags"

**Date de mise à jour** : 17 novembre 2026 *(Restructuré en 4 Sous-Plans atomiques `09-0`, `09-A`, `09-B`, `09-C` avec branches dédiées)*  
**Versions cibles** : `2.5.0+162` $\rightarrow$ `2.6.0+165` *(voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Registre de dépréciation associé** : [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md)  
**Prérequis** : Plans 10, 08 et 11 validés, mergés et publiés (`2.4.0+161`).

---

## 1. Philosophie Globale & Découpage Sécurisé en 4 Sous-Plans

Pour garantir **zéro perte de règles ACL** et **zéro coupure réseau** sur des parcs hétérogènes (utilisateurs locaux, utilisateurs OIDC mobiles, machines déjà taguées sous `tagged-devices`, machines sans tags, serveurs Headscale `0.26` à `0.30`), le Plan 09 est découpé en **4 sous-plans séquentiels**, chacun disposant de sa propre branche Git et de son Gate de test :

```text
[Sous-Plan 09-0] Dépréciation N-2, Purge Pré-v0.26 & Diagnostic Intelligent d'Alignement
    │  Branche : feat/acl-09-0-deprecation-and-alignment (Risque 🟢 Très Faible)
    │  • Bandeau rouge d'avertissement pour serveurs <= 0.27 (N-2) + REGISTRE_DEPRECATION_HEADSCALE.md
    │  • Alignement Policy v2 ("user@" pour locaux sans email, email pour OIDC)
    │  • Diagnostic & Auto-Fix avec accord admin (unification Local + OIDC mobile, tagOwners, DNS-1123)
    ▼
[Sous-Plan 09-A] Cœur Hybride Zéro-Coupure & Résolution Simulateur/Graphe
    │  Branche : feat/acl-09-a-hybrid-core (Risque 🟢 Faible)
    │  • Union hybride [...sortedTags, group:<user>] dans Standard & Grants V29 (parcs mixtes)
    │  • Gestion automatique de "via" (tagué) vs routage direct (routeur sans tag)
    │  • Alias "hosts" ("host-<user>-<node>") gérés sans écraser les hosts manuels
    │  • Résolution complète de "hosts", "user@", emails OIDC et autogroup:member dans Simulateur & Graphe
    ▼
[Sous-Plan 09-B] Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud
    │  Branche : feat/acl-09-b-stop-autotag-and-wizard (Risque 🟡 Faible à Moyen)
    │  • Tags optionnels sur PreAuthKey & Enregistrement + protection anti-conversion tagged-devices sur routes
    │  • Écran AclMigrationCenterScreen (non-intrusif, accessible depuis Paramètres, ACL et Fiche Nœud)
    │  • Bascule guidée nœud par nœud (Taggé <-> Sans Tag / OIDC / Grants) avec validation live du flux !
    ▼
[Sous-Plan 09-C] 4ème Moteur "Sans Tags" (AclEngineMode.tagless) & Adaptation de Tous les Constructeurs Manuels
       Branche : feat/acl-09-c-tagless-and-builders (Risque 🟡 Moyen)
       • Moteur TaglessAclGeneratorService (grants >= 0.29, acls < 0.29, tolérance hybride)
       • Adaptation du Composeur de Grants, de la Vue Puzzle, des Règles Spécifiques et de l'Éditeur SSH
```

---

## 2. Liens Directs vers les 4 Sous-Plans Détaillés

1. **[Sous-Plan 09-0 — Dépréciation $N-2$, Purge Pré-v0.26 & Diagnostic Intelligent d'Alignement](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_0_deprecation_audit_et_alignement.md)**
   - Branche : `feat/acl-09-0-deprecation-and-alignment` (`2.5.0+162`)
2. **[Sous-Plan 09-A — Cœur Hybride Zéro-Coupure (Tags + Sans Tags + OIDC) & Résolution Simulateur/Graphe](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_A_coeur_hybride_et_groupes.md)**
   - Branche : `feat/acl-09-a-hybrid-core` (`2.5.1+163`)
3. **[Sous-Plan 09-B — Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_B_arret_autotagging_et_assistant_bascule.md)**
   - Branche : `feat/acl-09-b-stop-autotag-and-wizard` (`2.5.2+164`)
4. **[Sous-Plan 09-C — 4ème Moteur `Sans Tags` (`AclEngineMode.tagless`) & Adaptation de Tous les Constructeurs Manuels](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_C_moteur_tagless_et_constructeurs.md)**
   - Branche : `feat/acl-09-c-tagless-and-builders` (`2.6.0+165`)

---

## 3. Synthèse des 10 Garanties Techniques Intégrées aux Sous-Plans

| # | Point Critique | Sous-Plan | Garantie apportée |
|---|---|---|---|
| **1** | **Utilisateurs locaux sans email (`"user@"`)** | `09-0` | `resolveAclGroupMembers` génère `"jean@"` (exigé par Headscale Policy v2 $\ge 0.26$) au lieu d'un faux domaine, permettant aux machines sans tags des utilisateurs locaux de matcher leur groupe. |
| **2** | **Bascule Mobile OIDC forcée à côté d'un compte local** | `09-0` & `09-A` | `AlignmentDiagnosticService` détecte et unifie l'identifiant local (`"jean@"`) et l'email OIDC (`"jean@gmail.com"`) dans le même `group:jean`, empêchant toute perte d'ACL quand un mobile se connecte en OIDC. |
| **3** | **Parc mixte (1 machine taguée + 1 machine sans tag chez le même user)** | `09-A` | Les générateurs utilisent l'union `[...sortedTags, groupName]` dans `src` et `dst` pour que les machines taguées et sans tags d'un même utilisateur communiquent dans les deux sens. |
| **4** | **Routage `"via"` en 0.29+ avec routeur sans tag** | `09-A` & `09-C` | Utilise `"via": [tag]` si le routeur porte un tag, ou bascule automatiquement en Grant direct sans `"via"` si le routeur est sans tag (évitant l'erreur 500 Headscale). |
| **5** | **Alias `"hosts"` (`host-<user>-<node>`) propres** | `09-A` & `09-C` | `PolicyPreserver._mergeHosts` met à jour les `host-*` auto-générés et `PolicyOrphanCleaner` supprime les `host-*` de machines supprimées, sans jamais toucher aux `hosts` manuels de l'admin. |
| **6** | **Simulateur de flux & Graphe Visuel ACL** | `09-A` | `AclParserService` résout `aclPolicy['hosts']`, `"user@"`, les emails OIDC et `autogroup:member`. |
| **7** | **Approbation de routes sans conversion forcée en `tagged-devices`** | `09-B` | `DashboardScreen`, `NodeDetailScreen`, `ExitNodeCommandDialog`, `ShareSubnetDialog` et `MoveNodeDialog` n'appellent plus `setTags` de force sur un appareil sans tag. |
| **8** | **Centre d'Assistance à la Bascule Nœud-par-Nœud** | `09-B` | `AclMigrationCenterScreen` guide la bascule d'un nœud en 3 étapes (Préparation ACL $\rightarrow$ Commande/Action $\rightarrow$ Validation live par API + Simulateur). |
| **9** | **Adaptation de tous les constructeurs manuels (Composeur, Puzzle, Exceptions, SSH)** | `09-C` | Support complet de `group:<user>`, des alias `host-<user>-<node>`, de `via` optionnel et du modèle SSH `autogroup:self`. |
| **10** | **Préservation intelligente lors d'un changement de moteur** | `09-C` | `_preserveCustomRulesOnRegenerate` filtre les anciennes règles auto-générées intra-utilisateur pour ne conserver que les vraies règles personnalisées inter-utilisateurs / Composeur / Puzzle. |
