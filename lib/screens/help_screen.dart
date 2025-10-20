import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// Écran d'aide de l'application.
///
/// Fournit des informations sur les prérequis, l'installation du serveur Headscale,
/// et un guide d'utilisation de l'application page par page.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aide et Guide d\'Utilisation',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBodyText(
                context,
                'Bienvenue dans le guide d\'utilisation de l\'application Headscale Manager !',
              ),
              const SizedBox(height: 8),
              _buildBodyText(
                context,
                'Cette application vous permet de gérer facilement votre serveur Headscale. Ce guide vous aidera à configurer votre serveur et à utiliser l\'application.',
              ),
              const SizedBox(height: 24),

              // Section API
              _buildSectionTitle(context, 'Fonctionnement : API'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'L\'application utilise des appels directs à l\'API de Headscale pour toutes les opérations de gestion.'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Actions directes (via API) :'),
                const SizedBox(height: 8),
                _buildCodeBlock(
                  context,
                  'Ces actions sont effectuées directement par l\'application :\n'
                  '- Lister les utilisateurs et les nœuds.\n'
                  '- Créer et supprimer des utilisateurs.\n'
                  '- Créer et invalider des clés de pré-authentification.\n'
                  '- Gérer les clés d\'API.\n'
                  '- Déplacer un nœud vers un autre utilisateur.\n'
                  '- Supprimer un nœud.\n'
                  '- Activer/Désactiver les routes (subnets et exit node).',
                ),
              ]),
              const SizedBox(height: 24),

              // Section Tutoriel
              _buildSectionTitle(
                  context, 'Tutoriel : Ajouter un appareil et le configurer'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'Voici les étapes complètes pour ajouter un nouvel appareil (nœud) à votre réseau Headscale.'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Étape 1 : Créer un utilisateur'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Si ce n\'est pas déjà fait, allez dans l\'onglet "Utilisateurs" et créez un nouvel utilisateur (par exemple, "mon-user").'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Étape 2 : Enregistrer l\'appareil'),
                const SizedBox(height: 8),
                _buildBodyText(
                    context, 'Il existe deux méthodes principales :'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'A) Avec une clé de pré-authentification (Recommandé)',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '1. Dans l\'onglet "Utilisateurs", cliquez sur l\'icône de clé et créez une clé pour votre utilisateur. Même si aucune case n\'est cochée, il est nécessaire de mettre 1 jour d\'expiration de la clé pour générer une clé valide.\n'
                  '2. Copiez la commande `tailscale up ...` fournie.\n'
                  '3. Exécutez cette commande sur l\'appareil que vous souhaitez ajouter. Il sera automatiquement enregistré et apparaîtra dans votre tableau de bord.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'B) Enregistrement via l\'application (pour les clients mobiles)',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '1.  Sur l\'appareil client (iOS/Android) : Dans l\'application Tailscale, allez dans les paramètres, sélectionnez "Use alternate server", et collez l\'URL de votre serveur Headscale.\n'
                  '2.  Dans l\'application Headscale Manager : Après avoir effectué l\'étape 1, le client Tailscale vous fournira une URL d\'enregistrement unique. Dans l\'application Headscale Manager, allez dans les détails de l\'utilisateur, cliquez sur "Enregistrer un nouvel appareil", et collez l\'URL fournie par le client. L\'appareil sera enregistré directement via l\'API.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context,
                    'Étape 3 (Optionnel) : Renommer le nœud et ajouter des tags'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Une fois le nœud apparu dans le tableau de bord, vous pouvez le configurer. C\'est une étape cruciale si vous utilisez les ACLs basées sur les tags.'),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '1. Allez dans les détails du nœud en cliquant dessus.\n'
                  '2. Utilisez le menu pour le renommer (par exemple, "mon-telephone").\n'
                  '3. Cliquez sur l\'icône de crayon pour modifier les tags. Ajoutez les tags pertinents (par exemple, `tag:user-phone`, `tag:user-laptop`). L\'application mettra à jour les tags directement via l\'API.',
                  isSmall: true,
                ),
              ]),
              const SizedBox(height: 24),

              // Section Prérequis
              _buildSectionTitle(
                  context, '1. Prérequis et Installation du Serveur Headscale'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'Pour utiliser cette application, vous devez disposer d\'un serveur Headscale fonctionnel. Voici comment le configurer :'),
                const SizedBox(height: 16),
                _buildSubTitle(
                    context, '1.1. Installation de Headscale avec Docker'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Il est recommandé d\'installer Headscale via Docker en utilisant l\'image officielle `headscale/headscale`. Assurez-vous de configurer la persistance des données en montant les volumes nécessaires.'),
                const SizedBox(height: 8),
                _buildBodyText(
                    context, 'Exemple de commande Docker (à adapter) :'),
                const SizedBox(height: 4),
                _buildCodeBlock(
                  context,
                  '''docker run -d --name headscale 
  -v <chemin_local_config>:/etc/headscale 
  -v <chemin_local_data>:/var/lib/headscale 
  -p 8080:8080 
  headscale/headscale:latest''',
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '- `<chemin_local_config>` : Chemin sur votre machine hôte où se trouvera le fichier `config.yaml`.\n'
                  '- `<chemin_local_data>` : Chemin sur votre machine hôte pour la persistance des données de Headscale (base de données, etc.).',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '1.2. Fichiers de Configuration'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Dans le volume de configuration (`<chemin_local_config>`), vous aurez besoin de deux fichiers :'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '- **`config.yaml`** : Le fichier de configuration principal de Headscale. Voici un exemple de configuration "clé en main" :'),
                const SizedBox(height: 4),
                _buildCodeBlock(
                  context,
                  '''server_url: https://<VOTRE_FQDN_PUBLIC>:8081
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
   mode: database
   path: ""
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
   enabled: true''',
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**N\'oubliez pas de remplacer `<VOTRE_FQDN_PUBLIC>` par le nom de domaine public que vous utiliserez.**',
                    isBold: true),
                const SizedBox(height: 16),
                _buildSubTitle(context,
                    '1.3. Configuration d\'un Proxy Inverse (Recommandé)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Pour des raisons de sécurité et d\'accessibilité, il est fortement recommandé de placer votre serveur Headscale derrière un proxy inverse (comme Nginx, Caddy, ou Traefik).'),
                const SizedBox(height: 8),
                _buildBodyText(context, 'Assurez-vous que :'),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- Vous avez un **FQDN (Fully Qualified Domain Name) public** (ex: `headscale.mondomaine.com`).\n'
                  '- Vous avez un **certificat SSL/TLS valide** pour ce FQDN (ex: via Let\'s Encrypt).\n'
                  '- Le proxy inverse redirige le **port externe HTTPS (8081)** vers le **port interne HTTP (8080)** de votre conteneur Headscale.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(
                    context, '1.4. Génération de la Clé API Headscale'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Une fois votre serveur Headscale opérationnel et accessible via votre FQDN public, vous devrez générer une clé API pour que l\'application puisse s\'y connecter.'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Connectez-vous à votre serveur Headscale (par exemple, via SSH sur la machine hôte de Docker) et utilisez la commande :'),
                const SizedBox(height: 4),
                _buildCodeBlock(context, 'headscale apikeys create'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**Gardez précieusement cette clé API unique dans un gestionnaire de mots de passe.** Elle est essentielle pour l\'authentification de l\'application.',
                    isBold: true),
              ]),
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              _buildSectionTitle(context, '2. Configuration de l\'Application'),
              _buildInfoCard(context, children: [
                _buildBodyText(
                    context, 'Dans l\'application Headscale Manager :'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '1.  Allez dans l\'écran **Paramètres** (icône d\'engrenage en haut à droite).'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '2.  Entrez l\'**adresse publique de votre serveur Headscale** (votre FQDN public, ex: `https://headscale.mondomaine.com`).'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '3.  Collez la **clé API** que vous avez générée précédemment.'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '4.  Sauvegardez les paramètres. L\'application est maintenant prête à se connecter à votre serveur !'),
              ]),
              const SizedBox(height: 24),

              _buildSectionTitle(context, '3. Utilisation de l\'Application'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'L\'application est divisée en plusieurs sections accessibles via la barre de navigation inférieure :'),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.1. Tableau de Bord (Dashboard)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Cet écran affiche un aperçu de l\'état de votre réseau Headscale. Vous y trouverez des informations sur le nombre de nœuds en ligne/hors ligne, le nombre d\'utilisateurs, etc. Les nœuds sont regroupés par utilisateur et peuvent être développés pour afficher plus de détails. Taper sur un nœud vous mènera à son écran de détails.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Boutons et Fonctionnalités :**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Développer/Réduire les groupes d\'utilisateurs :** Tapez sur le nom d\'un utilisateur pour afficher ou masquer les nœuds qui lui sont associés.\n'
                  '- **Afficher les détails du nœud :** Tapez sur n\'importe quel nœud dans la liste pour naviguer vers son écran de détails (`Détails du Nœud`).\n'
                  '- **Gérer les clés d\'API (icône \'api\') :** Ouvre un écran pour gérer les clés d\'API de votre serveur Headscale.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.2. Utilisateurs (Users)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Gérez les utilisateurs de votre serveur Headscale. Vous pouvez voir la liste des utilisateurs existants, en créer de nouveaux et les supprimer.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Boutons et Fonctionnalités :**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Ajouter Utilisateur (icône \'+\' en bas à droite) :** Ouvre un dialogue pour créer un nouvel utilisateur. Entrez simplement le nom d\'utilisateur souhaité. L\'application ajoutera automatiquement `le suffixe de domaine de votre serveur Headscale (par exemple, \'@votre_domaine.com\')` au nom d\'utilisateur si non présent.\n'
                  '- **Gérer les clés de pré-authentification (icône \'vpn_key\' en bas à droite) :** Ouvre un écran pour gérer les clés de pré-authentification de votre serveur Headscale.\n'
                  '- **Supprimer Utilisateur (icône de poubelle à côté de chaque utilisateur) :** Supprime l\'utilisateur sélectionné. Une confirmation vous sera demandée. Notez que la suppression échouera si l\'utilisateur possède encore des appareils.\n'
                  '- **Détails Utilisateur (clic sur un utilisateur) :** Affiche les détails de l\'utilisateur, y compris les nœuds qui lui sont associés et les clés de pré-authentification.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.3. ACLs (Access Control Lists)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Cette section vous permet de générer et de gérer la politique de contrôle d\'accès de votre réseau.'),
                const SizedBox(height: 16),
                _buildBodyText(
                  context,
                  '**Note Importante :** L\'ajout d\'un ou plusieurs utilisateurs peut nécessiter une mise à jour de la politique ACL pour que leurs appareils fonctionnent correctement.',
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**Principe de base : Isolation Stricte par Utilisateur**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  'Le générateur de politique de cette application est basé sur un principe de sécurité fondamental : **chaque utilisateur est isolé dans sa propre "bulle"**. Par défaut :\n'
                  '- Les appareils d\'un utilisateur ne peuvent communiquer qu\'avec les autres appareils de ce même utilisateur.\n'
                  '- Si un utilisateur possède un **exit node**, seuls ses propres appareils peuvent l\'utiliser.\n'
                  '- Si un utilisateur partage un **sous-réseau local**, seuls ses propres appareils peuvent y accéder.\n'
                  '- Jean ne peut pas voir ou contacter les appareils, exit nodes ou sous-réseaux de Clarisse, et vice-versa.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildBodyText(
                    context, '**Workflow d\'utilisation de la page ACL :**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  'La page ACL a deux fonctions principales :',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '**1. Générer la politique de base sécurisée :**\n'
                  '- Appuyez sur le bouton **Générer la Politique**.\n'
                  '- L\'application va analyser tous vos utilisateurs et appareils et créer une politique ACL sécurisée.\n'
                  '- La politique générée s\'affiche dans le champ de texte pour inspection.\n'
                  '- Utilisez le menu (⋮) et sélectionnez **Exporter vers le serveur** pour appliquer les règles.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '**2. Créer des exceptions pour la maintenance :**\n'
                  '- Si vous avez besoin d\'autoriser temporairement un appareil de Jean à communiquer avec un appareil de Clarisse, utilisez la section **Autorisations Spécifiques**.\n'
                  '- Sélectionnez un tag `Source` et un tag `Destination`.\n'
                  '- Cliquez sur **Ajouter et Appliquer**.\n'
                  '- La politique sera **automatiquement mise à jour et appliquée** sur le serveur.\n'
                  '- Pour retirer l\'autorisation, cliquez simplement sur la croix (x) de la règle active.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.4. Testeur ACL (ACL Tester)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Cette nouvelle page vous permet de tester et de visualiser l\'impact de différentes politiques ACL sans les appliquer directement à votre serveur Headscale. C\'est un environnement sûr pour expérimenter.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Fonctionnalités :**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Génération de Politique :** Similaire à la page ACL principale, vous pouvez générer une politique basée sur vos utilisateurs et nœuds existants.\n'
                  '- **Règles Temporaires :** Ajoutez et supprimez des règles temporaires pour voir comment elles affectent la politique générée.\n'
                  '- **Visualisation Instantanée :** La politique ACL résultante est affichée en temps réel dans un champ de texte, vous permettant de l\'inspecter.\n'
                  '- **Exportation Optionnelle :** Une fois satisfait du résultat, vous pouvez choisir d\'exporter la politique vers votre serveur Headscale.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.5. Vue d\'overview du réseau'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Cet écran, accessible depuis la barre de navigation, offre une vue dynamique et en temps réel de votre topologie réseau du point de vue de l\'appareil actuel. Il est particulièrement utile pour diagnostiquer les connexions et vérifier quel `exit node` est utilisé.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Fonctionnalités principales :**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Sélecteur de Nœud Actuel :** En haut de la page, un menu déroulant vous permet de sélectionner l\'appareil que vous considérez comme votre point de départ.\n'
                  '- **Visualisation du Chemin :** Un graphique simple montre le chemin réseau depuis votre appareil sélectionné vers Internet. Si le trafic passe par un `exit node` de votre réseau Headscale, celui-ci sera affiché comme intermédiaire.\n'
                  '- **Détection d\'Exit Node :** La page effectue un `traceroute` vers une destination publique (Google DNS) pour cartographier les sauts. Si l\'un des sauts correspond à l\'adresse IP d\'un de vos nœuds, ce dernier est identifié comme l\'exit node en cours d\'utilisation.\n'
                  '- **Statut des Pings :** Une liste de tous les autres nœuds de votre réseau s\'affiche avec leur statut (en ligne/hors ligne) et la latence moyenne.\n'
                  '- **Détails du Traceroute :** Une section dépliable vous montre le résultat brut du `traceroute`, listant chaque saut (adresse IP) entre votre appareil et la destination finale.',
                  isSmall: true,
                ),
              ]),
              const SizedBox(height: 24),

              _buildInfoCard(context, children: [
                _buildBodyText(
                  context,
                  '**Note Importante sur les Modifications des Nœuds :**\n'
                  'Toute modification apportée à un nœud (ajout, renommage, déplacement, modification des tags, activation/désactivation de routes) via cette application est enregistrée immédiatement dans la base de données de Headscale. Cependant, pour que ces changements soient réellement pris en compte par les autres nœuds du réseau et que la nouvelle configuration soit propagée, il est souvent nécessaire de redémarrer le service Headscale sur votre serveur. Headscale pousse les informations de sa base de données aux autres nœuds principalement au démarrage du service.',
                  isBold: true,
                ),
              ]),
              const SizedBox(height: 24),

              _buildBodyText(
                  context,
                  'Pour toute question ou problème, veuillez consulter la documentation officielle de Headscale ou les ressources de la communauté.'),
              const SizedBox(height: 24),

              // Carte GitHub
              _buildLinkCard(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context) {
    final Uri githubUri =
        Uri.parse('https://github.com/hkdone/headscalemanager');
    const String githubUrl = 'https://github.com/hkdone/headscalemanager';

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () async {
          if (await canLaunchUrl(githubUri)) {
            await launchUrl(githubUri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  githubUrl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: githubUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Lien GitHub copié !',
                            style: TextStyle(
                                color:
                                    Theme.of(context).colorScheme.onPrimary)),
                        backgroundColor: Theme.of(context).colorScheme.primary),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required List<Widget> children}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 16.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildSubTitle(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildBodyText(BuildContext context, String text,
      {bool isBold = false, bool isSmall = false}) {
    // Utiliser RichText pour gérer le gras avec les astérisques
    List<TextSpan> spans = [];
    text.splitMapJoin(
      RegExp(r'\*\*(.*?)\*\*'),
      onMatch: (m) {
        spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight:
                FontWeight.bold, // Toujours en gras pour ce qui est matché
            height: 1.5,
          ),
        ));
        return '';
      },
      onNonMatch: (n) {
        spans.add(TextSpan(
          text: n,
          style: TextStyle(
            fontSize: isSmall ? 13 : 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            height: 1.5,
          ),
        ));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      width: double.infinity,
      child: SelectableText(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontFamily: 'monospace', fontSize: 12.5),
      ),
    );
  }
}
