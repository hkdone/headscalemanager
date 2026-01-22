# Plan d'Action 02 : Transition vers v0.26 (Tags & Politique ACL)

## Objectif
S'adapter aux changements architecturaux de la v0.26, notamment l'isolation des Tags et le format des utilisateurs dans les politiques.

## Comparaison avec le code actuel
*   **Tags** : Actuellement, le groupement est 100% utilisateur. En v0.26, un nœud avec un tag n'appartient plus à un utilisateur.
*   **Utilisateurs** : La v0.26 impose le suffixe `@` pour les noms sans domaine dans les ACL.

## Éléments à modifier (Certitude)
- [ ] **`lib/services/new_acl_generator_service.dart`** : Ajouter le suffixe `@` aux noms d'utilisateurs si `serverVersion >= 0.26.0`.
- [ ] **`lib/models/node.dart`** : Prioriser le nouveau champ `tags` dans le `fromJson`.
- [ ] **`lib/screens/dashboard_screen.dart`** : Créer une catégorie "Nœuds Tagués" pour les nœuds sans propriétaire.

## Éléments à vérifier (Incertitude)
- [ ] **Exclusivité Tag/User** : Vérifier si l'API renvoie toujours un objet utilisateur pour un nœud tagué (normalement non en v0.26+).
- [ ] **Impact ACL** : Tester si le changement de tag via l'UI supprime bien l'utilisateur côté serveur.

## Étapes de réalisation
- [ ] Modifier le générateur d'ACL pour le format de nom `user@`.
- [ ] Mettre à jour la logique de groupement du Dashboard.
- [ ] Ajouter une mention informative dans l'UI des Tags concernant la perte de propriété utilisateur.
- [ ] Tester la génération d'ACL avec un mix de nœuds tagués et utilisateurs.
