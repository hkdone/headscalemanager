import 'package:flutter/material.dart';

/// Écran d'aide de l'application.
///
/// Fournit des informations sur les prérequis, l'installation du serveur Headscale,
/// et un guide d'utilisation de l'application page par page.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide et Guide d\'Utilisation'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue dans le guide d\'utilisation de l\'application Headscale Manager !',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Cette application vous permet de gérer facilement votre serveur Headscale depuis votre appareil mobile ou de bureau. Pour commencer, suivez les étapes ci-dessous.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            Text(
              '1. Prérequis et Installation du Serveur Headscale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Pour utiliser cette application, vous devez disposer d\'un serveur Headscale fonctionnel. Voici comment le configurer :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**1.1. Installation de Headscale avec Docker**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Il est recommandé d\'installer Headscale via Docker en utilisant l\'image officielle `headscale/headscale`. Assurez-vous de configurer la persistance des données en montant les volumes nécessaires.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Exemple de commande Docker (à adapter) :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[200],
              child: const Text(
                '''docker run -d --name headscale \
  -v <chemin_local_config>:/etc/headscale \
  -v <chemin_local_data>:/var/lib/headscale \
  -p 8080:8080 \
  headscale/headscale:latest''',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '- `<chemin_local_config>` : Chemin sur votre machine hôte où se trouvera le fichier `config.yaml` et `acl.yaml`.'

              '- `<chemin_local_data>` : Chemin sur votre machine hôte pour la persistance des données de Headscale (base de données, etc.).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '**1.2. Fichiers de Configuration**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Dans le volume de configuration (`<chemin_local_config>`), vous aurez besoin de deux fichiers :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '- **`config.yaml`** : Le fichier de configuration principal de Headscale. Voici un exemple de configuration "clé en main" :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[200],
              child: const Text(
                '''server_url: http://<VOTRE_FQDN_PUBLIC>:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 0.0.0.0:9090
grpc_listen_addr: 0.0.0.0:50443
db_path: /var/lib/headscale/db.sqlite
private_key_path: /var/lib/headscale/private.key
noise_private_key_path: /var/lib/headscale/noise_private.key
log_level: info
dns_config:
  override_local_dns: true
  nameservers:
    - 8.8.8.8
    - 1.1.1.1
  magic_dns: true
derp:
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update: true
acls:
  enabled: true
  file: /etc/headscale/acl.yaml
oauth2:
  enabled: false
  issuer: ""
  client_id: ""
  client_secret: ""
  scopes: []
  allowed_domains: []
  extra_params: {}
users:
  - name: admin
    create_if_not_exists: true
    roles:
      - admin
    api_keys:
      - name: initial-api-key
        expiration: 2030-01-01T00:00:00Z
        permissions:
          - all
''',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '**N\'oubliez pas de remplacer `<VOTRE_FQDN_PUBLIC>` par le nom de domaine public que vous utiliserez.**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '- **`acl.yaml`** : Pour le moment, vous pouvez le laisser vide pour une utilisation sans ACLs. Il sera utilisé par Headscale pour appliquer les politiques d\'accès.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              '**1.3. Configuration d\'un Proxy Inverse (Recommandé)**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pour des raisons de sécurité et d\'accessibilité, il est fortement recommandé de placer votre serveur Headscale derrière un proxy inverse (comme Nginx, Caddy, ou Traefik).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Assurez-vous que :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '- Vous avez un **FQDN (Fully Qualified Domain Name) public** (ex: `headscale.mondomaine.com`).'

              '- Vous avez un **certificat SSL/TLS valide** pour ce FQDN (ex: via Let\'s Encrypt).'
              '- Le proxy inverse redirige le **port externe HTTPS (443)** vers le **port interne HTTP (8080)** de votre conteneur Headscale.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '**1.4. Génération de la Clé API Headscale**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Une fois votre serveur Headscale opérationnel et accessible via votre FQDN public, vous devrez générer une clé API pour que l\'application puisse s\'y connecter.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Connectez-vous à votre serveur Headscale (par exemple, via SSH sur la machine hôte de Docker) et utilisez la commande :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.grey[200],
              child: const Text(
                'headscale apikeys create',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '**Gardez précieusement cette clé API unique dans un gestionnaire de mots de passe.** Elle est essentielle pour l\'authentification de l\'application.',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            Text(
              '2. Configuration de l\'Application',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Dans l\'application Headscale Manager :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '1.  Allez dans l\'écran **Paramètres** (icône d\'engrenage en haut à droite).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '2.  Entrez l\'**adresse publique de votre serveur Headscale** (votre FQDN public, ex: `https://headscale.mondomaine.com`).',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '3.  Collez la **clé API** que vous avez générée précédemment.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '4.  Sauvegardez les paramètres. L\'application est maintenant prête à se connecter à votre serveur !',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            Text(
              '3. Utilisation de l\'Application',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'L\'application est divisée en plusieurs sections accessibles via la barre de navigation inférieure :',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.1. Tableau de Bord (Dashboard)**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet écran affiche un aperçu de l\'état de votre réseau Headscale. Vous y trouverez des informations sur le nombre de nœuds en ligne/hors ligne, le nombre d\'utilisateurs, etc. Les nœuds sont regroupés par utilisateur et peuvent être développés pour afficher plus de détails. Taper sur un nœud vous mènera à son écran de détails.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Développer/Réduire les groupes d\'utilisateurs :** Tapez sur le nom d\'un utilisateur pour afficher ou masquer les nœuds qui lui sont associés.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Afficher les détails du nœud :** Tapez sur n\'importe quel nœud dans la liste pour naviguer vers son écran de détails (`Détails du Nœud`).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.2. Utilisateurs (Users)**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Gérez les utilisateurs de votre serveur Headscale. Vous pouvez voir la liste des utilisateurs existants, en créer de nouveaux et les supprimer.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Ajouter Utilisateur (icône '+' en bas à droite) :** Ouvre un dialogue pour créer un nouvel utilisateur. Entrez simplement le nom d\'utilisateur souhaité. L\'application ajoutera automatiquement `@nasfilecloud.synology.me` au nom d\'utilisateur si non présent.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Créer Clé de Pré-authentification (icône \'vpn_key\' en bas à droite) :** Ouvre un dialogue pour créer une clé de pré-authentification. Vous pouvez sélectionner un utilisateur, et spécifier si la clé est réutilisable, éphémère et sa durée d\'expiration en jours. Après création, une commande `tailscale up` est affichée pour enregistrer un client.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Supprimer Utilisateur (icône de poubelle à côté de chaque utilisateur) :** Supprime l\'utilisateur sélectionné. Une confirmation vous sera demandée. Notez que la suppression échouera si l\'utilisateur possède encore des appareils.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Détails Utilisateur (clic sur un utilisateur) :** Affiche les détails de l\'utilisateur, y compris les nœuds qui lui sont associés et les clés de pré-authentification.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.3. ACLs (Access Control Lists)**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cette section vous permet de visualiser et de générer des politiques ACL pour votre réseau Headscale. Les ACLs définissent qui peut communiquer avec qui.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Générer la configuration de base (icône de restauration) :** Génère une politique ACL "Tout-Tag" basée sur les utilisateurs et les nœuds existants. Cette politique est affichée dans le champ de texte et peut être copiée. Cette fonctionnalité est utile pour obtenir une base de politique ACL.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Partager le fichier ACL (icône de partage) :** Exporte la politique ACL affichée dans le champ de texte vers un fichier JSON que vous pouvez partager ou sauvegarder.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.4. Détails Utilisateur**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet écran affiche les informations détaillées d\'un utilisateur et liste tous les appareils (nœuds) qui lui sont associés.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Enregistrer un nouvel appareil (bouton central) :** Ouvre un dialogue en deux étapes pour enregistrer un nouvel appareil sous cet utilisateur. La première étape fournit une commande `tailscale up` à exécuter sur l\'appareil, et la seconde étape génère la commande `headscale nodes register` à exécuter sur votre serveur Headscale après avoir collé le lien web obtenu.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Gestion des Nœuds (pour chaque appareil listé) :** Chaque nœud est affiché avec son statut en ligne/hors ligne. Taper sur un nœud vous mènera à son écran de détails (`Détails du Nœud`). Un menu contextuel (icône "trois points" ou "plus") offre des actions spécifiques pour chaque nœud.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.5. Détails du Nœud**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet écran affiche toutes les informations détaillées d\'un nœud spécifique, y compris son FQDN, ses adresses IP, ses routes annoncées et ses tags.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Modifier les Tags (icône de crayon dans l\'AppBar) :** Ouvre un dialogue pour modifier les tags associés au nœud. Vous entrez les tags sous forme de liste séparée par des virgules. L\'application génère une commande CLI `headscale nodes tag` que vous devez copier et exécuter manuellement sur votre serveur Headscale pour appliquer les changements.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Menu d\'Actions (icône "trois points" ou "plus" à côté de chaque nœud dans les listes) :** Ce menu contextuel offre plusieurs actions pour le nœud :',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Renommer l\'appareil :** Permet de changer le nom affichable du nœud.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Déplacer l\'appareil :** Permet de transférer le nœud vers un autre utilisateur.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Activer le nœud de sortie :** Affiche une commande `tailscale up --advertise-exit-node` pour configurer le nœud comme nœud de sortie. Cette commande doit être exécutée manuellement sur l\'appareil.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Désactiver le nœud de sortie :** Désactive la fonctionnalité de nœud de sortie via l\'API.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Partager le sous-réseau local :** Ouvre un dialogue pour entrer un sous-réseau CIDR. Affiche une commande `tailscale up --advertise-routes` pour annoncer le sous-réseau. Cette commande doit être exécutée manuellement sur l\'appareil.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Désactiver les routes de sous-réseau :** Désactive les routes de sous-réseau annoncées via l\'API.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '  - **Supprimer l\'appareil :** Supprime le nœud du serveur Headscale après confirmation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.6. Clés de Pré-authentification**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet écran (accessible via le bouton `vpn_key` sur l\'écran Utilisateurs) vous permet de visualiser, créer et supprimer des clés de pré-authentification. Ces clés sont utilisées pour enregistrer de nouveaux appareils sans intervention manuelle sur le serveur.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Boutons et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **Créer Clé (icône '+' en bas à droite) :** Ouvre un dialogue pour créer une nouvelle clé de pré-authentification. Vous pouvez spécifier l\'utilisateur, si elle est réutilisable, éphémère et sa durée d\'expiration en jours. Après création, une commande `tailscale up` est affichée pour enregistrer un client.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Supprimer Clé (icône de poubelle à côté de chaque clé) :** Supprime une clé de pré-authentification existante après confirmation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),

            Text(
              '**3.7. Paramètres**',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Cet écran vous permet de configurer l\'application pour qu\'elle se connecte à votre serveur Headscale.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '**Champs et Fonctionnalités :**',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '- **URL du Serveur :** Entrez l\'adresse publique (FQDN) de votre serveur Headscale (ex: `https://headscale.mondomaine.com`).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Clé API :** Collez la clé API unique que vous avez générée depuis votre serveur Headscale. Ce champ est masqué pour des raisons de sécurité.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '- **Bouton Enregistrer :** Sauvegarde les identifiants saisis. L\'application redémarrera pour appliquer les nouveaux paramètres.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),

            Text(
              'Pour toute question ou problème, veuillez consulter la documentation officielle de Headscale ou les ressources de la communauté.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}