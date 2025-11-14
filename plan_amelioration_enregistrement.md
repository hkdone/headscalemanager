# Plan d'amélioration pour l'enregistrement des appareils

## Idée 1 : Simplifier le partage de la clé (mis de côté)

*   **Bouton "Partager"** : Ajouter un bouton "Partager" à côté de "Copier" et "QR Code" pour envoyer la commande `tailscale up` complète via e-mail, SMS, etc., en utilisant le package `share_plus`.
*   **Lien profond (Deep Link)** : Générer un lien spécial (ex: `headscalemanager://register?key=...`) qui pourrait pré-remplir les informations dans le client Tailscale.

## Idée 2 : Enregistrement simplifié via l'application (Plan Actif)

L'objectif est d'éliminer l'échange manuel de clés entre l'utilisateur et l'administrateur.

### Plan d'action

1.  **Créer un écran "Appareils en attente"** :
    *   Créer un nouveau fichier `lib/screens/pending_devices_screen.dart`.
    *   Ajouter une route et un lien de navigation (par exemple, dans `home_screen.dart`) pour accéder à cet écran.

2.  **Filtrer et afficher les appareils non enregistrés** :
    *   Sur cet écran, appeler l'endpoint `GET /api/v1/node`.
    *   Filtrer la liste des nœuds pour n'afficher que ceux qui sont en attente d'enregistrement. Le critère de filtrage sera probablement un champ `user` nul ou un statut spécifique.
    *   Pour chaque appareil en attente, afficher des informations pertinentes (nom, OS, IP).

3.  **Implémenter la logique d'approbation** :
    *   Ajouter un bouton "Approuver" pour chaque appareil en attente.
    *   Au clic, ouvrir une boîte de dialogue qui liste tous les utilisateurs existants.
    *   L'administrateur sélectionne un utilisateur pour associer l'appareil.
    *   L'application appelle ensuite la fonction `registerMachine(machineKey, userName)` avec la `machineKey` de l'appareil en attente et le nom de l'utilisateur sélectionné.

4.  **Notifications (Phase 2 - Optionnel)** :
    *   Mettre en place une tâche de fond (background task) qui vérifie périodiquement la présence de nouveaux appareils en attente.
    *   Si un nouvel appareil est détecté, envoyer une notification push à l'administrateur.
    *   Le clic sur la notification redirige directement vers l'écran "Appareils en attente".
