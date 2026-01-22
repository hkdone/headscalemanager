# Plan d'Action 03 : Transition vers v0.27 (Validation & Autogroupes)

## Objectif
Supporter les nouveaux autogroupes et respecter les règles de validation DNS plus strictes de la v0.27.

## Comparaison avec le code actuel
*   **Validation** : Actuellement, pas de validation forte sur les noms de nœuds. La v0.27 rejette les caractères spéciaux (underscores, etc.).
*   **ACL** : La v0.27 impose des ports explicites (plus de ports vides).

## Éléments à modifier (Certitude)
- [ ] **`lib/services/new_acl_generator_service.dart`** : Garantir que chaque règle ACL possède un port (`:*` par défaut).
- [ ] **`lib/screens/node_detail_screen.dart`** (ou dialogue de renommage) : Ajouter une validation regex DNS.

## Éléments à vérifier (Incertitude)
- [ ] **Autogroupes** : Doit-on proposer l'utilisation de `autogroup:self` malgré son statut expérimental ?
- [ ] **Validation existante** : Vérifier si certains noms actifs en base vont provoquer des erreurs après migration du serveur.

## Étapes de réalisation
- [ ] Implémenter la validation DNS (regex) côté client pour le renommage.
- [ ] Mettre à jour le générateur d'ACL pour s'assurer que tous les ports sont explicites.
- [ ] Étudier l'ajout de `autogroup:member` pour simplifier les règles ACL intra-utilisateur.
- [ ] Vérifier l'affichage MagicDNS avec les nouveaux formats de noms.
