# Feuille de Route : Développements Futurs pour HeadscaleManager

Ce document contient une liste de fonctionnalités potentielles pour l'amélioration de l'application, classées par ordre de complexité.

---

### ✨ **Fonctionnalités Faciles (Améliorations rapides)**

**1. Recherche et Filtrage des Listes**
*   **Description :** Sur les écrans qui affichent de longues listes (comme le Tableau de Bord avec les nœuds, ou l'écran des Utilisateurs), ajouter une barre de recherche en haut de l'écran pour filtrer instantanément les résultats et trouver rapidement ce que vous cherchez.
*   **Plan :**
    1.  Intégrer un champ de recherche en haut des écrans `DashboardScreen` et `UsersScreen`.
    2.  À chaque lettre tapée, filtrer la liste des nœuds ou des utilisateurs pour n'afficher que ceux qui correspondent à la recherche.

**2. Copie Rapide des Informations**
*   **Description :** Sur l'écran de détail d'un nœud, en plus du nom de domaine (FQDN), ajouter une icône "copier" à côté d'autres informations techniques utiles comme l'adresse IP, la clé machine ou l'ID du nœud.
*   **Plan :**
    1.  Modifier le widget qui affiche une ligne de détail (`_buildDetailRow`).
    2.  Pour les champs concernés, ajouter une `IconButton` qui, au clic, copie la donnée correspondante dans le presse-papiers.

---

### 🚀 **Fonctionnalités Intermédiaires (Outils de diagnostic)**

**3. Scanner de Ports**
*   **Description :** C'est le complément parfait du Ping. Sur la page de détail d'un nœud, cet outil vous permettrait de vérifier si un port spécifique est ouvert (par exemple, le port 22 pour SSH, 3389 pour le Bureau à Distance, ou 80/443 pour un serveur web). C'est extrêmement utile pour diagnostiquer pourquoi un service ne répond pas.
*   **Plan :**
    1.  Intégrer une librairie de scan de ports (ex: `port_scanner` depuis pub.dev).
    2.  Sur l'écran de détail d'un nœud, ajouter un bouton "Scanner les ports".
    3.  Ce bouton ouvrirait un dialogue où vous pourriez entrer un ou plusieurs ports à tester.
    4.  Lancer le scan sur l'IP du nœud et afficher clairement les résultats : "Ouvert" ou "Fermé".

**4. Gestion Centralisée des Clés d'Authentification**
*   **Description :** Actuellement, la création de clés est un peu cachée. Cette fonctionnalité ajouterait un onglet dédié dans la barre de navigation principale pour lister, créer, et supprimer les clés de pré-authentification de manière centralisée et intuitive.
*   **Plan :**
    1.  Ajouter une nouvelle icône "Clés" dans la barre de navigation en bas de l'écran.
    2.  Lier cette icône à l'écran `PreAuthKeysScreen` (qui existe déjà mais n'est pas utilisé).
    3.  S'assurer que la liste des clés se rafraîchit correctement après chaque création ou suppression.

**5. Test de Connexion à l'API**
*   **Description :** Sur l'écran des paramètres, lorsque vous entrez une nouvelle URL de serveur ou une nouvelle clé API, il n'y a aucun moyen de savoir si elles sont correctes avant de voir des erreurs ailleurs. Cette fonctionnalité ajouterait un bouton "Tester la Connexion" qui ferait un appel simple à l'API pour valider instantanément les identifiants.
*   **Plan :**
    1.  Ajouter un bouton "Tester" dans l'écran `SettingsScreen`.
    2.  Au clic, appeler une fonction simple de l'API (comme `getUsers`).
    3.  Afficher une notification de succès ("Connexion réussie !") ou d'échec ("Erreur : veuillez vérifier vos informations") en fonction du résultat.

---

### 💎 **Fonctionnalités Complexes (Vision à long terme)**

**6. Graphiques et Statistiques Visuelles**
*   **Description :** Créer un nouvel onglet "Statistiques" pour visualiser la santé et la composition de votre réseau avec des graphiques interactifs.
*   **Plan :**
    1.  Intégrer une librairie de graphiques (comme `fl_chart`).
    2.  Créer un nouvel écran dédié.
    3.  Agréger les données de vos nœuds pour afficher :
        *   Un graphique circulaire de la répartition des systèmes d'exploitation (Windows, Linux, Android...).
        *   Un histogramme du nombre de nœuds par utilisateur.
        *   Un historique de la disponibilité des nœuds (demanderait de sauvegarder l'état à intervalles réguliers).

**7. Gestion Simplifiée des "Exit Nodes"**
*   **Description :** La configuration d'un "exit node" (pour faire sortir tout son trafic par une machine spécifique) est une fonctionnalité puissante de Headscale, mais complexe à mettre en place. On pourrait la simplifier drastiquement.
*   **Plan :**
    1.  Sur l'écran de détail d'un nœud, détecter s'il est configuré pour être un "exit node".
    2.  Si c'est le cas, afficher un simple interrupteur "Activer/Désactiver l'Exit Node".
    3.  L'activation de cet interrupteur ferait automatiquement les appels API nécessaires pour approuver les routes de sortie et mettrait à jour les ACLs pour autoriser les autres machines à l'utiliser.
