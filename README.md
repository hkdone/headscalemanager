# Headscale Manager - Aide et Guide d'Utilisation

Bienvenue dans le guide d'utilisation de l'application Headscale Manager !

Cette application vous permet de gérer facilement votre serveur Headscale. Ce guide vous aidera à configurer votre serveur et à utiliser l'application.

## Fonctionnement : API vs Lignes de Commande (CLI)

Pour des raisons de sécurité et de flexibilité, l'application utilise une combinaison d'appels directs à l'API de Headscale et de commandes à exécuter manuellement sur votre serveur (CLI).

### Actions directes (via API) :

Ces actions sont effectuées directement par l'application :
- Lister les utilisateurs et les nœuds.
- Créer et supprimer des utilisateurs.
- Créer et invalider des clés de pré-authentification.
- Déplacer un nœud vers un autre utilisateur.
- Supprimer un nœud.
- Activer/Désactiver les routes (subnets et exit node).

### Actions manuelles (via CLI) :

Pour ces actions, l'application génère la commande exacte que vous devez copier et coller dans le terminal de votre serveur Headscale. C'est une mesure de sécurité pour les opérations sensibles :
- Enregistrer un nouveau nœud (la validation finale).
- Renommer un nœud.
- Modifier les tags d'un nœud (pour les ACLs).
- Appliquer la politique ACL.

## Tutoriel : Ajouter un appareil et le configurer (avec un client Tailscale)

Voici les étapes complètes pour ajouter un nouvel appareil (nœud) à votre réseau Headscale.

### Étape 1 : Créer un utilisateur

Si ce n'est pas déjà fait, allez dans l'onglet "Utilisateurs" et créez un nouvel utilisateur (par exemple, "mon-user").

### Étape 2 : Enregistrer l'appareil

Il existe deux méthodes principales :

**A) Avec une clé de pré-authentification (Recommandé)**

1. Dans l'onglet "Utilisateurs", cliquez sur l'icône de clé et créez une clé pour votre utilisateur. Même si aucune case n'est cochée, il est nécessaire de mettre 1 jour d'expiration de la clé pour générer une clé valide.
2. Copiez la commande `tailscale up ...` fournie.
3. Exécutez cette commande sur l'appareil que vous souhaitez ajouter. Il sera automatiquement enregistré et apparaîtra dans votre tableau de bord.

**B) Enregistrement manuel**

L'enregistrement manuel se fait en deux étapes :

1.  **Sur l'appareil client :**
    *   **Pour Windows, Linux, et macOS :** Dans l'application, allez dans les détails de l'utilisateur, cliquez sur "Enregistrer un nouvel appareil", et dans l'onglet "Windows/Linux/macOS", copiez la commande `tailscale up ...` et exécutez-la sur l'appareil.
    *   **Pour iOS et Android :** Dans l'application, allez dans les détails de l'utilisateur, cliquez sur "Enregistrer un nouvel appareil", et dans l'onglet "iOS/Android", copiez l'URL du serveur. Sur le client Tailscale, allez dans les paramètres, sélectionnez "Use alternate server", et collez l'URL.

2.  **Dans l'application Headscale Manager :**
    *   Après avoir effectué l'étape 1, le client Tailscale vous fournira une URL d'enregistrement.
    *   Dans l'application Headscale Manager, passez à l'étape 2 de l'enregistrement, collez l'URL fournie par le client, ce qui générera une commande `headscale nodes register ...`.
    *   Exécutez cette commande sur votre serveur Headscale pour finaliser l'enregistrement.

### Étape 3 (Optionnel) : Renommer le nœud et ajouter des tags

Une fois le nœud apparu dans le tableau de bord, vous pouvez le configurer. C'est une étape cruciale si vous utilisez les ACLs basées sur les tags.

1. Allez dans les détails du nœud en cliquant dessus.
2. Utilisez le menu pour le **renommer** (par exemple, "mon-telephone").
3. Cliquez sur l'icône de crayon pour **modifier les tags**. Ajoutez les tags pertinents (par exemple, `tag:user-phone`, `tag:user-laptop`).
4. L'application execute automatiquement la commande `headscale nodes rename ...` mais vous donnera la commande CLI pour appliquer les changements `headscale nodes tag ...`. Exécutez-la sur votre serveur.

## 1. Prérequis et Installation du Serveur Headscale

Pour utiliser cette application, vous devez disposer d'un serveur Headscale fonctionnel. Voici comment le configurer :

### 1.1. Installation de Headscale avec Docker

Il est recommandé d'installer Headscale via Docker en utilisant l'image officielle `headscale/headscale`. Assurez-vous de configurer la persistance des données en montant les volumes nécessaires.

Exemple de commande Docker (à adapter) :
```
docker run -d --name headscale \
  -v <chemin_local_config>:/etc/headscale \
  -v <chemin_local_data>:/var/lib/headscale \
  -p 8080:8080 \
  headscale/headscale:latest
```

- `<chemin_local_config>` : Chemin sur votre machine hôte où se trouvera le fichier `config.yaml` et `acl.yaml`.
- `<chemin_local_data>` : Chemin sur votre machine hôte pour la persistance des données de Headscale (base de données, etc.).

### 1.2. Fichiers de Configuration

Dans le volume de configuration (`<chemin_local_config>`), vous aurez besoin de deux fichiers :

- **`config.yaml`** : Le fichier de configuration principal de Headscale. Voici un exemple de configuration "clé en main" :
```yaml
server_url: https://<VOTRE_FQDN_PUBLIC>:8081
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential
derp:
  server:
    enabled: false
    region_id: 999
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"
    verify_clients: true
    stun_listen_addr: "0.0.0.0:3478"
    private_key_path: /var/lib/headscale/derp_server_private.key
    automatically_add_embedded_derp_region: true
    ipv4: 1.2.3.4
    ipv6: 2001:db8::1
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  paths: []
  auto_update_enabled: true
  update_frequency: 24h
disable_check_updates: false
ephemeral_node_inactivity_timeout: 30m
database:
  type: sqlite
  debug: false
  gorm:
    prepare_stmt: true
    parameterized_queries: true
    skip_err_record_not_found: true
    slow_threshold: 1000
  sqlite:
    path: /var/lib/headscale/db.sqlite
    write_ahead_log: true
    wal_autocheckpoint: 1000
acme_url: https://acme-v02.api.letsencrypt.org/directory
acme_email: ""
tls_letsencrypt_hostname: ""
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: HTTP-01
tls_letsencrypt_listen: ":http"
tls_cert_path: ""
tls_key_path: ""
log:
  level: info
  format: text
policy:
   mode: file
   path: /etc/headscale/acl.yaml
dns:
  magic_dns: true
  base_domain: <VOTRE_DOMAINE_DE_BASE>.com
  override_local_dns: false
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
      - 2606:4700:4700::1111
      - 2606:4700:4700::1001
    split:
      {}
  search_domains: []
  extra_records: []
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"
logtail:
  enabled: false
randomize_client_port: false
preauthkey_expiry: 5m
routes:
   enabled: true
```

**N'oubliez pas de remplacer `<VOTRE_FQDN_PUBLIC>` par le nom de domaine public que vous utiliserez.**

- **`acl.yaml`** : Pour le moment, vous pouvez le laisser vide pour une utilisation sans ACLs. Il sera utilisé par Headscale pour appliquer les politiques d'accès.

### 1.3. Configuration d'un Proxy Inverse (Recommandé)

Pour des raisons de sécurité et d'accessibilité, il est fortement recommandé de placer votre serveur Headscale derrière un proxy inverse (comme Nginx, Caddy, ou Traefik).

Assurez-vous que :
- Vous avez un **FQDN (Fully Qualified Domain Name) public** (ex: `headscale.mondomaine.com`).
- Vous avez un **certificat SSL/TLS valide** pour ce FQDN (ex: via Let's Encrypt).
- Le proxy inverse redirige le **port externe HTTPS (443)** vers le **port interne HTTP (8080)** de votre conteneur Headscale.

### 1.4. Génération de la Clé API Headscale

Une fois votre serveur Headscale opérationnel et accessible via votre FQDN public, vous devrez générer une clé API pour que l'application puisse s'y connecter.

Connectez-vous à votre serveur Headscale (par exemple, via SSH sur la machine hôte de Docker) et utilisez la commande :
```
headscale apikeys create
```

**Gardez précieusement cette clé API unique dans un gestionnaire de mots de passe.** Elle est essentielle pour l'authentification de l'application.

## 2. Configuration de l'Application

Dans l'application Headscale Manager :

1.  Allez dans l'écran **Paramètres** (icône d'engrenage en haut à droite).
2.  Entrez l'**adresse publique de votre serveur Headscale** (votre FQDN public, ex: `https://headscale.mondomaine.com`).
3.  Collez la **clé API** que vous avez générée précédemment. Ce champ est masqué pour des raisons de sécurité.
4.  Sauvegardez les paramètres. L'application redémarrera pour appliquer les nouveaux paramètres.

## 3. Utilisation de l'Application

L'application est divisée en plusieurs sections accessibles via la barre de navigation inférieure :

### 3.1. Tableau de Bord (Dashboard)

Cet écran affiche un aperçu de l'état de votre réseau Headscale. Vous y trouverez des informations sur le nombre de nœuds en ligne/hors ligne, le nombre d'utilisateurs, etc. Les nœuds sont regroupés par utilisateur et peuvent être développés pour afficher plus de détails. Taper sur un nœud vous mènera à son écran de détails (`Détails du Nœud`).

**Boutons et Fonctionnalités :**
- **Développer/Réduire les groupes d'utilisateurs :** Tapez sur le nom d'un utilisateur pour afficher ou masquer les nœuds qui lui sont associés.
- **Afficher les détails du nœud :** Tapez sur n'importe quel nœud dans la liste pour naviguer vers son écran de détails (`Détails du Nœud`).

### 3.2. Utilisateurs (Users)

Gérez les utilisateurs de votre serveur Headscale. Vous pouvez voir la liste des utilisateurs existants, en créer de nouveaux et les supprimer.

**Boutons et Fonctionnalités :**
- **Ajouter Utilisateur (icône '+' en bas à droite) :** Ouvre un dialogue pour créer un nouvel utilisateur. Entrez simplement le nom d'utilisateur souhaité. L'application ajoutera automatiquement `le suffixe de domaine de votre serveur Headscale (par exemple, `@votre_domaine.com`)` au nom d'utilisateur si non présent.
- **Créer Clé de Pré-authentification (icône 'vpn_key' en bas à droite) :** Ouvre un dialogue pour créer une clé de pré-authentification. Vous pouvez sélectionner un utilisateur, et spécifier si la clé est réutilisable, éphémère et sa durée d'expiration en jours. Après création, une commande `tailscale up` est affichée pour enregistrer un client.
- **Supprimer Utilisateur (icône de poubelle à côté de chaque utilisateur) :** Supprime l'utilisateur sélectionné. Une confirmation vous sera demandée. Notez que la suppression échouera si l'utilisateur possède encore des appareils.
- **Détails Utilisateur (clic sur un utilisateur) :** Affiche les détails de l'utilisateur, y compris les nœuds qui lui sont associés et les clés de pré-authentification.

### 3.3. ACLs (Access Control Lists)

Cette section vous permet de visualiser et de générer des politiques ACL pour votre réseau Headscale. Les ACLs définissent qui peut communiquer avec qui.

**Boutons et Fonctionnalités :**
- **Générer la configuration de base (icône de restauration) :** Génère une politique ACL "Tout-Tag" basée sur les utilisateurs et les nœuds existants. Cette politique est affichée dans le champ de texte et peut être copiée. Cette fonctionnalité est utile pour obtenir une base de politique ACL.
- **Partager le fichier ACL (icône de partage) :** Exporte la politique ACL affichée dans le champ de texte vers un fichier JSON que vous pouvez partager ou sauvegarder.

### 3.4. Détails Utilisateur

Cet écran affiche les informations détaillées d'un utilisateur et liste tous les appareils (nœuds) qui lui sont associés.

**Boutons et Fonctionnalités :**
- **Enregistrer un nouvel appareil (bouton central) :** Ouvre un dialogue en deux étapes pour enregistrer un nouvel appareil sous cet utilisateur. La première étape fournit une commande `tailscale up` à exécuter sur l'appareil, et la seconde étape génère la commande `headscale nodes register` à exécuter sur votre serveur Headscale après avoir collé le lien web obtenu.
- **Gestion des Nœuds (pour chaque appareil listé) :** Chaque nœud est affiché avec son statut en ligne/hors ligne. Taper sur un nœud vous mènera à son écran de détails (`Détails du Nœud`). Un menu contextuel (icône "trois points" ou "plus") offre des actions spécifiques pour chaque nœud.

### 3.5. Détails du Nœud

Cet écran affiche toutes les informations détaillées d'un nœud spécifique, y compris son FQDN (construit dynamiquement à partir du nom du nœud et du domaine de base de votre serveur Headscale), ses adresses IP, ses routes annoncées et ses tags.

**Boutons et Fonctionnalités :**
- **Modifier les Tags (icône de crayon dans l'AppBar) :** Ouvre un dialogue pour modifier les tags associés au nœud. Vous entrez les tags sous forme de liste séparée par des virgules. L'application génère une commande CLI `headscale nodes tag` que vous devez copier et exécuter manuellement sur votre serveur Headscale pour appliquer les changements.
- **Menu d'Actions (icône "trois points" ou "plus" à côté de chaque nœud dans les listes) :** Ce menu contextuel offre plusieurs actions pour le nœud :
  - **Renommer l'appareil :** Permet de changer le nom affichable du nœud.
  - **Déplacer l'appareil :** Permet de transférer le nœud vers un autre utilisateur.
  - **Activer le nœud de sortie :** Affiche une commande `tailscale up --advertise-exit-node` pour configurer le nœud comme nœud de sortie. Cette commande doit être exécutée manuellement sur l'appareil.
  - **Désactiver le nœud de sortie :** Désactive la fonctionnalité de nœud de sortie via l'API.
  - **Partager le sous-réseau local :** Ouvre un dialogue pour entrer un sous-réseau CIDR. Affiche une commande `tailscale up --advertise-routes` pour annoncer le sous-réseau. Cette commande doit être exécutée manuellement sur l'appareil.
  - **Désactiver les routes de sous-réseau :** Désactive les routes de sous-réseau annoncées via l'API.
  - **Supprimer l'appareil :** Supprime le nœud du serveur Headscale après confirmation.

### 3.6. Clés de Pré-authentification

Cet écran (accessible via le bouton `vpn_key` sur l'écran Utilisateurs) vous permet de visualiser, créer et supprimer des clés de pré-authentification. Ces clés sont utilisées pour enregistrer de nouveaux appareils sans intervention manuelle sur le serveur.

**Boutons et Fonctionnalités :**
- **Créer Clé (icône '+' en bas à droite) :** Ouvre un dialogue pour créer une nouvelle clé de pré-authentification. Vous pouvez spécifier l'utilisateur, si elle est réutilisable, éphémère et sa durée d'expiration en jours. Après création, une commande `tailscale up` est affichée pour enregistrer un client.
- **Supprimer Clé (icône de poubelle à côté de chaque clé) :** Supprime une clé de pré-authentification existante après confirmation.

### 3.7. Paramètres

Cet écran vous permet de configurer l'application pour qu'elle se connecte à votre serveur Headscale.

**Champs et Fonctionnalités :**
- **URL du Serveur :** Entrez l'adresse publique (FQDN) de votre serveur Headscale (ex: `https://headscale.mondomaine.com`).
- **Clé API :** Collez la clé API unique que vous avez générée depuis votre serveur Headscale. Ce champ est masqué pour des raisons de sécurité.
- **Bouton Enregistrer :** Sauvegarde les identifiants saisis. L'application redémarrera pour appliquer les nouveaux paramètres.

Pour toute question ou problème, veuillez consulter la documentation officielle de Headscale ou les ressources de la communauté.
