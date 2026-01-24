# Plan d'Action 03 : Transition vers v0.27 (Validation & Autogroupes)

## Objectif
Supporter les nouveaux autogroupes et respecter les règles de validation DNS plus strictes de la v0.27.

## Comparaison avec le code actuel
*   **Validation** : Actuellement, pas de validation forte sur les noms de nœuds. La v0.27 rejette les caractères spéciaux (underscores, etc.).
*   **ACL** : La v0.27 impose des ports explicites (plus de ports vides).

## Éléments à modifier (Certitude)
- [x] **`lib/services/new_acl_generator_service.dart`** : Garantir que chaque règle ACL possède un port (`:*` par défaut).
- [x] **`lib/screens/dns_screen.dart`** : 
    *   Ajouter une validation Regex (RFC 1123) lors de l'ajout/modification d'un alias. (Lettres, chiffres, tirets, pas de tiret au début/fin).
    *   Dans `_fetchData`, vérifier tous les alias existants chargés depuis le storage.
    *   Si un alias invalide est détecté, afficher une icône d'alerte à côté de celui-ci et suggérer une correction (ex: remplacer `_` par `-`) via un dialogue au clic.
- [x] **`lib/widgets/rename_node_dialog.dart`** : 
    *   **Validation** : Ajouter la validation RFC 1123 dans le form.
    *   **Sanitization** : Proposer une correction automatique si invalide.
    *   **Consistance ACL** : Après le succès du `renameNode`, déclencher une régénération complète des ACLs (via `NewAclGenerator` ou `Standard` selon le mode) pour s'assurer que tout est synchronisé.
- [x] **`lib/screens/user_detail_screen.dart`** : 
    *   **Audit Visuel** : Dans la grille des nœuds (`_NodeCard`), si le nom est invalide, afficher une icône ⚠️.
- [x] **`lib/screens/node_detail_screen.dart`** : 
    *   **Audit Visuel** : Dans le header, afficher un warning si le nom est invalide.

## Éléments à vérifier (Incertitude)
- [x] **Autogroupes** : Décision prise avec l'utilisateur. `autogroup:member` est exclu car trop permissif. Support manuel uniquement (partiellement visible dans Puzzle, invisible dans Graph).

## Étapes de réalisation
- [x] Implémenter la regex de validation RFC 1123 dans un utilitaire (`StringUtils` ?).
- [x] Mettre à jour `DnsScreen` pour valider l'input utilisateur (alias).
- [x] Mettre à jour `DnsScreen` pour auditer les alias existants et signaler les erreurs.
- [x] Mettre à jour le générateur d'ACL pour s'assurer que tous les ports sont explicites. (Vérifié : Le code actuel gère déjà correctement les ports :* par défaut)
- [x] Mettre à jour `RenameNodeDialog` pour inclure la validation, la sanitization et le callback de régénération ACL.
- [x] Mettre à jour `UserDetailScreen` et `NodeDetailScreen` pour signaler les nœuds aux noms invalides.
- [x] Vérifier l'affichage MagicDNS avec les nouveaux formats de noms.
