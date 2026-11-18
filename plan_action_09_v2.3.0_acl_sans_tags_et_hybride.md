# Plan d'Action 09 (Plan Maître) — Gouvernance $N-2$, Alignement Intelligent, Mode Hybride, Centre de Bascule & Moteur "Sans Tags"

**Date de mise à jour** : 18 novembre 2026 *(Restructuré en 4 Sous-Plans atomiques `09-0`, `09-A`, `09-B`, `09-C` avec branches dédiées ; `09-0`/`09-A`/`09-B` validés & mergés)*  
**Versions cibles** : `2.5.0+165` $\rightarrow$ `2.5.2+169` *(Publication publique #1 : `09-0` + `09-A` + `09-B`)* $\rightarrow$ `2.6.0+170` *(Publication publique #2 : `09-C`)* *(voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Registre de dépréciation associé** : [REGISTRE_DEPRECATION_HEADSCALE.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/REGISTRE_DEPRECATION_HEADSCALE.md)  
**Prérequis** : Plans 10, 08 et 11 validés, mergés et publiés (`2.4.0+161`).

---

## 1. Philosophie Globale & Découpage Sécurisé en 4 Sous-Plans

Pour garantir **zéro perte de règles ACL** et **zéro coupure réseau** sur des parcs hétérogènes (utilisateurs locaux, utilisateurs OIDC mobiles, machines déjà taguées sous `tagged-devices`, machines sans tags, serveurs Headscale `0.26` à `0.30`), le Plan 09 est découpé en **4 sous-plans séquentiels**, chacun disposant de sa propre branche Git et de son Point de contrôle de test :

```text
[Sous-Plan 09-0] Dépréciation N-2, Purge Pré-v0.26 & Diagnostic Intelligent d'Alignement (✅ Validé & Mergé)
    │  Branche : feat/acl-09-0-deprecation-and-alignment (Risque 🟢 Très Faible)
    │  • Bandeau rouge d'avertissement pour serveurs <= 0.27 (N-2) + REGISTRE_DEPRECATION_HEADSCALE.md
    │  • Alignement Policy v2 ("user@" pour locaux sans email, email pour OIDC)
    │  • Diagnostic & Auto-Fix avec accord admin (unification Local + OIDC mobile, tagOwners, DNS-1123)
    ▼
[Sous-Plan 09-A] Cœur Hybride Zéro-Coupure & Résolution Simulateur/Graphe (✅ Validé & Mergé)
    │  Branche : feat/acl-09-a-hybrid-core (Risque 🟢 Faible)
    │  • Union hybride [...sortedTags, group:<user>] dans Standard & Grants V29 (parcs mixtes)
    │  • Gestion automatique de "via" (tagué) vs routage direct (routeur sans tag)
    │  • Alias "hosts" ("host-<user>-<node>") gérés sans écraser les hosts manuels
    │  • Résolution complète de "hosts", "user@", emails OIDC et autogroup:member dans Simulateur & Graphe
    ▼
[Sous-Plan 09-B] Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud (✅ Validé & Mergé — 2.5.2+169)
    │  Branche : feat/acl-09-b-stop-autotag-and-wizard (Risque 🟡 Faible à Moyen)
    │  • Tags optionnels sur PreAuthKey & Enregistrement + protection anti-conversion tagged-devices sur routes
    │  • Écran AclMigrationCenterScreen (non-intrusif, accessible depuis Paramètres, ACL et Fiche Nœud)
    │  • Bascule guidée nœud par nœud (Taggé <-> Sans Tag / OIDC / Grants) avec régénération ACL auto & validation live !
    ▼
[Sous-Plan 09-C] 4ème Moteur "Sans Tags" (AclEngineMode.tagless) & Adaptation de Tous les Constructeurs Manuels (⬜ À faire — 2.6.0+170)
       Branche : feat/acl-09-c-tagless-and-builders (Risque 🟡 Moyen — en 2 lots internes 09-C.1 + 09-C.2)
       • Lot 1 (09-C.1) : Moteur TaglessAclGeneratorService isolé (grants >= 0.29, acls < 0.29, tolérance hybride) + sélecteur UI
       • Lot 2 (09-C.2) : Composeur de Grants, Vue Puzzle, Règles Spécifiques, SSH + PolicyPreserver sécurisé (routeurs tiers & inter-moteurs)
```

---

## 2. Liens Directs vers les 4 Sous-Plans Détaillés

1. **[Sous-Plan 09-0 — Dépréciation $N-2$, Purge Pré-v0.26 & Diagnostic Intelligent d'Alignement](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_0_deprecation_audit_et_alignement.md)** — ✅ Validé & Mergé
   - Branche : `feat/acl-09-0-deprecation-and-alignment` (`2.5.0+165`)
2. **[Sous-Plan 09-A — Cœur Hybride Zéro-Coupure (Tags + Sans Tags + OIDC) & Résolution Simulateur/Graphe](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_A_coeur_hybride_et_groupes.md)** — ✅ Validé & Mergé
   - Branche : `feat/acl-09-a-hybrid-core` (`2.5.1+166`)
3. **[Sous-Plan 09-B — Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_B_arret_autotagging_et_assistant_bascule.md)** — ✅ Validé & Mergé *(Publication publique #1)*
   - Branche : `feat/acl-09-b-stop-autotag-and-wizard` (`2.5.2+169`)
4. **[Sous-Plan 09-C — 4ème Moteur `Sans Tags` (`AclEngineMode.tagless`) & Adaptation de Tous les Constructeurs Manuels](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_C_moteur_tagless_et_constructeurs.md)** — ⬜ À faire *(Publication publique #2)*
   - Branche : `feat/acl-09-c-tagless-and-builders` (`2.6.0+170`)

---

## 3. Synthèse des 12 Garanties Techniques Intégrées aux Sous-Plans

| # | Point Critique | Sous-Plan | Garantie apportée |
|---|---|---|---|
| **1** | **Utilisateurs locaux sans email (`"user@"`)** | `09-0` | `resolveAclGroupMembers` génère `"jean@"` (exigé par Headscale Policy v2 $\ge 0.26$) au lieu d'un faux domaine, permettant aux machines sans tags des utilisateurs locaux de matcher leur groupe. |
| **2** | **Bascule Mobile OIDC forcée à côté d'un compte local** | `09-0` & `09-A` | `AlignmentDiagnosticService` détecte et unifie l'identifiant local (`"jean@"`) et l'email OIDC (`"jean@gmail.com"`) dans le même `group:jean`, empêchant toute perte d'ACL quand un mobile se connecte en OIDC. |
| **3** | **Parc mixte (1 machine taguée + 1 machine sans tag chez le même user)** | `09-A` | Les générateurs utilisent l'union `[...sortedTags, groupName]` dans `src` et `dst` pour que les machines taguées et sans tags d'un même utilisateur communiquent dans les deux sens. |
| **4** | **Routage `"via"` en 0.29+ avec routeur sans tag** | `09-A` & `09-C` | Utilise `"via": [tag]` si le routeur porte un tag, ou bascule automatiquement en Grant direct sans `"via"` si le routeur est sans tag (évitant l'erreur 500 Headscale). |
| **5** | **Alias `"hosts"` (`host-<user>-<node>`) propres** | `09-A` & `09-C` | `PolicyPreserver._mergeHosts` met à jour les `host-*` auto-générés et `PolicyOrphanCleaner` supprime les `host-*` de machines supprimées, sans jamais toucher aux `hosts` manuels de l'admin. |
| **6** | **Simulateur de flux & Graphe Visuel ACL** | `09-A` | `AclParserService` résout `aclPolicy['hosts']`, `"user@"`, les emails OIDC et `autogroup:member`. |
| **7** | **Approbation de routes sans conversion forcée en `tagged-devices`** | `09-B` | `DashboardScreen`, `NodeDetailScreen`, `ExitNodeCommandDialog`, `ShareSubnetDialog` et `MoveNodeDialog` n'appellent plus `setTags` de force sur un appareil sans tag. |
| **8** | **Centre d'Assistance à la Bascule Nœud-par-Nœud** | `09-B` | `AclMigrationCenterScreen` guide la bascule d'un nœud en 3 étapes (Préparation ACL $\rightarrow$ Commande/Action $\rightarrow$ Régénération ACL auto & validation live par API + Simulateur). |
| **9** | **Adaptation de tous les constructeurs manuels (Composeur, Puzzle, Exceptions, SSH)** | `09-C` | Support complet de `group:<user>`, des alias `host-<user>-<node>`, des routeurs sans tag (`via` optionnel) et du modèle SSH `autogroup:self`. |
| **10** | **Préservation stricte lors d'un changement de moteur** | `09-C` | `_preserveCustomRulesOnRegenerate` / `PolicyPreserver` ne filtre que les anciennes règles auto-générées intra-utilisateur (`action: accept`, sans `proto`, sans `app`, port `:*` uniquement) et conserve 100 % des règles inter-utilisateurs, Composeur, Puzzle, et règles à ports/protocoles/IPs personnalisés. |
| **11** | **Bascule d'un routeur tiers (`Exit Node` / `LAN`) vers le sans tag** | `09-C` | Si un tiers passe à 100 % sans tag, remplace `tag:<tiers>-*` par `group:<tiers>` et ne retire `via` automatiquement que s'il n'y a aucune ambiguïté (un seul utilisateur publie `autogroup:internet` ou ce CIDR LAN) ; en cas de conflit, bloque l'élargissement silencieux et alerte l'admin dans le diagnostic / Diff Visuel. |
| **12** | **Découpage sécurisé en 2 lots & 8 architectures testées** | `09-C` | Lot 1 (`09-C.1` : moteur `tagless` isolé sans toucher aux 3 moteurs existants) puis Lot 2 (`09-C.2` : constructeurs & `PolicyPreserver`), validés par tests unitaires sur les 8 combinaisons et vérifiés par `AclParserService`. |
