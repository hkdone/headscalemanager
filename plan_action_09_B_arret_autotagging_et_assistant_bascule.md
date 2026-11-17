# Sous-Plan d'Action 09-B — Arrêt de l'Auto-Tagging Forcé & Centre d'Assistance à la Bascule Nœud-par-Nœud

**Date de création** : 17 novembre 2026  
**Version cible** : `2.5.2+164` *(Étape 4.B — voir [SUIVI_IMPLEMENTATION.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/SUIVI_IMPLEMENTATION.md))*  
**Branche Git dédiée** : `feat/acl-09-b-stop-autotag-and-wizard` *(créée depuis `master` après merge de `09-A`)*  
**Prérequis** : Sous-Plans `09-0` et `09-A` validés et mergés  
**Plan parent** : [plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md](file:///c:/Users/jeanv/Desktop/Projets/StudioProjects/headscaleManager/plan_action_09_v2.3.0_acl_sans_tags_et_hybride.md)  
**Niveau de risque** : 🟡 **Faible à Moyen** *(touche aux dialogues d'enregistrement/approbation et ajoute un nouvel écran d'assistance pas-à-pas)*

---

## 1. Objectif du Sous-Plan 09-B

Maintenant que le cœur hybride (`09-A`) protège à 100 % les appareils sans tags aux côtés des appareils tagués :
1. **Stopper l'auto-tagging forcé** dans l'application pour qu'un administrateur puisse créer des PreAuthKeys sans tags, enregistrer de nouveaux appareils sans tags, et approuver des routes LAN ou Exit Nodes sur des appareils sans tags **sans les convertir accidentellement en `tagged-devices`**.
2. **Créer un "Centre d'Assistance à la Bascule" (`AclMigrationCenterScreen`)** non-intrusif mais accessible à tout moment, permettant à l'administrateur :
   - De basculer en sécurité vers **Grants V29** ou vers **Sans Tags (No-Tag)**.
   - De **migrer ses nœuds un par un** (de `Taggé` $\rightarrow$ `Sans Tag / OIDC` ou inversement) avec un **mode opératoire guidé** et un **bouton de validation de fonctionnement en direct** (qui vérifie l'état API du nœud + simule ses flux réseau).

---

## 2. Détails Techniques

### Tâche 09-B.1 — Arrêt de l'Auto-Tagging Forcé & Protection Anti-Conversion `tagged-devices`
1. **`lib/widgets/create_pre_auth_key_dialog.dart`** :
   - Ajouter un interrupteur explicite : **"Associer des tags ACL (Mode Serveur / Infrastructure)"**.
   - Lorsqu'il est **décoché** (par défaut en mode `tagless`, et librement décochable dans tous les modes) :
     - Envoyer `aclTags: null` à `createPreAuthKey(...)` (la machine appartiendra directement à l'utilisateur humain sans passer en `tagged-devices`, et c'est 100 % compatible avec la future règle `owner_conflict` de Headscale `0.30` !).
   - Lorsqu'il est **coché** :
     - Générer les tags via `TagCapabilityHelper.buildInitialTags(...)` et s'assurer que ces tags existent dans `tagOwners` de la policy active (anticipation `tags_not_permitted` Headscale 0.29/0.30).
2. **`lib/widgets/registration_dialogs.dart`** :
   - Après `registerMachine(key, user.name)` :
     - Si `appProvider.aclEngineMode == AclEngineMode.tagless`, ne pas ouvrir `_showAddTagsDialog` et afficher directement la confirmation *"Appareil enregistré sous l'utilisateur ${user.name} (sans tag)"*.
     - Dans les autres modes, renommer le bouton *"Ignorer"* de l'étape 3/3 en **"Conserver sans tag (Appareil personnel)"** et expliquer que l'appareil est couvert par le filet hybride `group:<user>`.
3. **`lib/screens/dashboard_screen.dart`, `lib/screens/node_detail_screen.dart`, `lib/widgets/exit_node_command_dialog.dart`, `lib/widgets/share_subnet_dialog.dart` & `lib/widgets/move_node_dialog.dart`** :
   - **Règle de protection absolue** : Si un nœud n'a actuellement **aucun tag** (`node.tags.isEmpty`) :
     - En mode `tagless` : approuver uniquement les routes (`setNodeRoutes`) et régénérer l'ACL (`autoApprovers` utilise `group:<user>`). **Ne jamais appeler `setTags` !**
     - En mode `Standard` ou `Grants V29` : si le nœud est sans tag (`node.tags.isEmpty`), proposer à l'administrateur le choix :
       - **"Approuver sans tag (Recommandé — Conserve le propriétaire humain)"** $\rightarrow$ approuve la route via le filet hybride `group:<user>` sans appeler `setTags`.
       - **"Convertir en routeur tagué (`tag:<user>-lan-sharer` / `exit-node`)"** *(nécessaire uniquement si deux utilisateurs partagent le même CIDR LAN et ont besoin de `via`)* $\rightarrow$ avertit que le nœud passera sous `tagged-devices`.
   - Dans `MoveNodeDialog` (`< 0.28`) : si `node.tags.isEmpty`, déplacer le nœud sans lui injecter de tags.

---

### Tâche 09-B.2 — Le "Centre d'Assistance à la Bascule" (`AclMigrationCenterScreen`) : Emplacement & Ergonomie

Pour que cet outil ne soit **jamais intrusif** (aucune popup forcée au démarrage) mais **immédiatement trouvable à tout moment** :
1. **Point d'entrée 1 — Écran ACL (`lib/screens/acl_screen.dart`)** :
   - Dans le menu `⋮` en haut à droite : entrée **"🧭 Assistant de bascule & migration (Grants / Sans Tags)"**.
   - Sur le bandeau `AclEngineBanner` : bouton discret **"Assistant de bascule"** à côté du sélecteur de moteur.
2. **Point d'entrée 2 — Écran Paramètres (`lib/screens/settings_screen.dart`)** :
   - Dans la carte *"Moteur de génération ACL"*, bouton **"🧭 Ouvrir l'assistant de bascule guidée (Nœud par Nœud)"**.
3. **Point d'entrée 3 — Fiche d'un Nœud (`NodeDetailScreen` & `EditTagsDialog`)** :
   - Bouton **"🔄 Basculer ce nœud (Taggé ↔ Sans Tag / OIDC)"** qui ouvre directement l'assistant pré-filtré sur ce nœud !

---

### Tâche 09-B.3 — Mode Opératoire Guidé & Validation Nœud-par-Nœud dans `AclMigrationCenterScreen`

L'écran `AclMigrationCenterScreen` propose **3 parcours guidés avec vérification automatique** :

#### Parcours A : Basculer un nœud de **Taggé (`tagged-devices`) $\rightarrow$ Sans Tag (Utilisateur / OIDC)** *(Un par un, sans couper le parc)*
Pour chaque nœud tagué sélectionné par l'administrateur, une fiche interactive en **3 étapes avec feux tricolores (⬜ $\rightarrow$ 🔄 $\rightarrow$ ✅)** s'affiche :
1. **Étape 1 — Préparation du Filet ACL sur le serveur (Automatique en 1 clic)** :
   - Vérifie que `group:<user>` contient bien `"<user>@"` et l'email OIDC de l'utilisateur (`09-0`), et que les règles hybrides (`09-A`) autorisent déjà `group:<user>` à communiquer avec tous les `tag:<user>-*` existants et les routes LAN/Exit Node.
   - Si ce n'est pas encore sur le serveur, bouton **"Préparer l'ACL d'accueil"** (avec aperçu Diff).
   - *Résultat* : Le serveur est prêt à accueillir le nœud sans tag **avant même qu'on le déconnecte** !
2. **Étape 2 — Mode opératoire de reconnexion du nœud sans tag** :
   - Explique pourquoi Headscale $\ge 0.28$ impose une ré-authentification pour sortir de `tagged-devices`.
   - Propose deux méthodes selon le type d'appareil :
     - **Appareil Mobile / OIDC (Android, iOS, PC avec navigateur)** :
       - Bouton **"1. Expirer la session actuelle (`expireNode`)"** ou **"Supprimer l'ancienne entrée taguée avant reconnexion"** + instructions claires : *"Sur l'appareil, cliquez sur Reconnecter (Login) et connectez-vous avec le compte OIDC"*.
     - **Serveur / PC en ligne de commande (Linux, Windows, macOS)** :
       - Génère la commande exacte prête à copier :
         `tailscale up --login-server=<URL> --advertise-tags= --force-reauth` (avec `--accept-routes` ou `--advertise-routes=...` pré-rempli si le nœud partageait déjà des routes !).
3. **Étape 3 — Validation de fonctionnement en direct (Bouton *"🔍 Vérifier & Valider la bascule"*)** :
   - Lorsque l'admin clique sur **"Vérifier & Valider la bascule"** :
     1. Appelle `apiService.getNodes()` et retrouve l'appareil (par ID ou par hostname/IP).
     2. Vérifie :
        - Est-il en ligne (`node.online == true`) ?
        - Est-il bien **sans tag** (`node.tags.isEmpty`) et rattaché à l'utilisateur (`nodeBelongsToUser`) ?
        - Ses routes éventuelles sont-elles ré-approuvées (sinon propose un bouton 1-clic **"Ré-approuver ses routes précédentes"**) ?
     3. Lance automatiquement `AclParserService.simulateConnection` entre ce nœud et les autres machines de l'utilisateur (taguées et sans tags) et affiche :
        - **✅ Badge Vert : "Nœud basculé en Sans Tag et communication réseau validée avec X appareil(s) !"**

#### Parcours B : Basculer un nœud de **Sans Tag $\rightarrow$ Taggé (`tag:<user>-client` / Routeur)**
- En **1 clic API** (aucune manipulation sur l'appareil client n'est requise !) :
  1. Met à jour `tagOwners` dans la policy serveur si nécessaire.
  2. Appelle `apiService.setTags(node.id, newTags)`.
  3. Régénère la policy ACL et valide via le simulateur que le flux est **✅ AUTORISÉ**.

#### Parcours C : Basculer le serveur vers **Grants V29** (ou **Sans Tags global**)
- Exécute d'abord le diagnostic d'alignement `09-0`, affiche le comparateur Diff visuel ligne-par-ligne, applique la policy, puis lance une simulation automatique sur chaque utilisateur pour confirmer qu'aucun accès n'a été perdu.

---

## 3. Fichiers Concernés

| Type | Fichier | Nature de la modification |
|---|---|---|
| **Nouveau** | `lib/screens/acl_migration_center_screen.dart` | Centre d'assistance à la bascule (Parcours A/B/C nœud par nœud + validation live) |
| **Modifié** | `lib/widgets/create_pre_auth_key_dialog.dart` | Interrupteur optionnel *"Associer des tags ACL"* (`aclTags: null` si décoché) |
| **Modifié** | `lib/widgets/registration_dialogs.dart` | Option *"Conserver sans tag"* + saut auto en mode `tagless` |
| **Modifié** | `lib/screens/dashboard_screen.dart` & `lib/screens/node_detail_screen.dart` | Protection anti-tagging forcé lors de l'approbation de routes + lien vers l'assistant |
| **Modifié** | `lib/widgets/exit_node_command_dialog.dart` & `lib/widgets/share_subnet_dialog.dart` | Ne pas appeler `setTags` si le nœud reste sans tag |
| **Modifié** | `lib/widgets/move_node_dialog.dart` | Ne pas taguer un nœud sans tag lors d'un déplacement |
| **Modifié** | `lib/widgets/edit_tags_dialog.dart` | Bouton ouvrant directement le Parcours A (dé-taguer ce nœud) |
| **Modifié** | `lib/screens/acl_screen.dart` & `lib/screens/settings_screen.dart` | Entrées d'accès au Centre d'Assistance à la Bascule |

---

## 4. Gate de Validation `09-B`
- [ ] `flutter analyze` $\rightarrow$ `0 issue`.
- [ ] Créer une PreAuthKey avec l'option *"Associer des tags ACL"* décochée $\rightarrow$ la clé est créée sans aucun tag.
- [ ] Ouvrir le **Centre d'Assistance à la Bascule** depuis Paramètres, depuis l'écran ACL, et depuis la fiche d'un nœud.
- [ ] Tester le **Parcours A** sur une machine de test (ou vérifier les 3 étapes : préparation ACL $\rightarrow$ commande pré-remplie avec ses routes $\rightarrow$ bouton de validation de flux en direct).
