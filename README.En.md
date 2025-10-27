# Headscale Manager - Help and User Guide

Welcome to the Headscale Manager application user guide!

This application allows you to easily manage your Headscale server. This guide will help you configure your server and use the application.

Download the android mobile application: https://play.google.com/store/apps/details?id=com.dkstudio.headscalemanager

This application is a flutter application and allows you to compile for IOS, MAC, WEB, Windows as needed.
The code is free to use.
However, please be aware that I have published the application for free on the Play Store and I am not responsible for any paid version on the App Store that a user might publish.


## How it works: API

The application uses direct calls to the Headscale API for all management operations.

## Tutorial: Add a device and configure it (with a Tailscale client)

Here are the complete steps to add a new device (node) to your Headscale network.

### Step 1: Create a user

If you haven\'t already, go to the "Utilisateurs" (Users) tab and create a new user (for example, "my-user").

### Step 2: Register the device

There are two main methods:

**A) With a pre-authentication key**

1. In the "Utilisateurs" (Users) tab, click on the key icon and create a key for your user. Even if no box is checked, it is necessary to set a 1-day expiration for the key to generate a valid key.
2. Note that an ephemeral key will disconnect the user after the time limit.
3. Copy the provided `tailscale up ...` command.
4. Run this command on the device you want to add. It will be automatically registered and will appear on your dashboard.

**B) Registration via the application (for mobile clients)**

1.  **On the client device (iOS/Android):** In the Tailscale application, go to settings, select "Use alternate server", and paste the URL of your Headscale server.
2.  **In the Headscale Manager application:** After completing step 1, the Tailscale client will provide you with a unique registration URL as well as a command containing a registration key. In the Headscale Manager application, paste the URL provided by the client or the registration key alone. The device will be registered directly via the API.

### Step 3 (Optional): Rename the node and add tags

Once the node appears on the dashboard, you can configure it. This is a crucial step if you use tag-based ACLs.

1. Go to the node details by clicking on it.
2. Use the menu to **renommer** (rename) it (for example, "my-phone").
3. Click on the pencil icon to **modifier les tags** (edit tags). Add the relevant tags (e.g., `tag:user-phone`, `tag:user-laptop`). The application will update the tags directly via the API.

## 1. Prerequisites and Headscale Server Installation

To use this application, you must have a functional Headscale server. Here\'s how to set it up:

### 1.1. Installing Headscale with Docker

It is recommended to install Headscale via Docker using the official `headscale/headscale` image. Make sure to configure data persistence by mounting the necessary volumes.

Example Docker command (to be adapted):
```
docker run -d --name headscale \
  -v <local_config_path>:/etc/headscale \
  -v <local_data_path>:/var/lib/headscale \
  -p 8080:8080 \
  headscale/headscale:latest
```

- `<local_config_path>`: Path on your host machine where the `config.yaml` file will be located.
- `<local_data_path>`: Path on your host machine for Headscale data persistence (database, etc.).

### 1.2. Configuration Files

In the configuration volume (`<local_config_path>`), you will need two files:

- **`config.yaml`**: The main configuration file for Headscale. Here is a "turnkey" configuration example:
```yaml
server_url: https://<YOUR_PUBLIC_FQDN>:8081
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
  base_domain: <YOUR_BASE_DOMAIN>.com
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

**Don\'t forget to replace `<YOUR_PUBLIC_FQDN>` with the public domain name you will be using.**

### 1.3. Configuring a Reverse Proxy (Recommended)

For security and accessibility reasons, it is highly recommended to place your Headscale server behind a reverse proxy (like Nginx, Caddy, or Traefik).

Make sure that:
- You have a **public FQDN (Fully Qualified Domain Name)** (e.g., `headscale.mydomain.com`).
- You have a **valid SSL/TLS certificate** for this FQDN (e.g., via Let\'s Encrypt).
- The reverse proxy redirects the **external HTTPS port (8081)** to the **internal HTTP port (8080)** of your Headscale container.

### 1.4. Generating the Headscale API Key

Once your Headscale server is operational and accessible via your public FQDN, you will need to generate an API key so that the application can connect to it.

Connect to your Headscale server (e.g., via SSH on the Docker host machine) and use the command:
```
headscale apikeys create
```

**Keep this unique API key safe in a password manager.** It is essential for application authentication.

## 2. Application Configuration

In the Headscale Manager application:

1.  Go to the **Paramètres** (Settings) screen (gear icon in the top right).
2.  Enter the **public address of your Headscale server** (your public FQDN, e.g., `https://headscale.mydomain.com`).
3.  Paste the **API key** you generated earlier. This field is hidden for security reasons.
4.  Save the settings. The application will restart to apply the new settings.

## 3. Using the Application

The application is divided into several sections accessible via the bottom navigation bar:

### 3.1. Tableau de Bord (Dashboard)

This screen displays an overview of the status of your Headscale network. You will find information on the number of online/offline nodes, the number of users, etc. Nodes are grouped by user and can be expanded to show more details. Tapping on a node will take you to its details screen (`Détails du Nœud` - Node Details).

**Buttons and Features:**
- **Expand/Collapse user groups:** Tap on a user\'s name to show or hide the nodes associated with them.
- **Show node details:** Tap on any node in the list to navigate to its details screen (`Détails du Nœud` - Node Details).
- **Manage API keys (icon \'api\'):** Opens a screen to manage your Headscale server\'s API keys.

### 3.2. Utilisateurs (Users)

Manage your Headscale server\'s users. You can see the list of existing users, create new ones, and delete them.

**Buttons and Features:**
- **Ajouter Utilisateur** (Add User) (icon \'+\' at the bottom right): Opens a dialog to create a new user. Simply enter the desired username. The application will automatically add `the domain suffix of your Headscale server (for example, "@your_domain.com")` to the username if it is not present.
- **Gérer les clés de pré-authentification** (Manage pre-authentication keys) (icon \'vpn_key\' at the bottom right): Opens a screen to manage your Headscale server\'s pre-authentication keys.
- **Supprimer Utilisateur** (Delete User) (trash can icon next to each user): Deletes the selected user. You will be asked for confirmation. Note that deletion will fail if the user still has devices.
- **Détails Utilisateur** (User Details) (click on a user): Displays the user\'s details, including their associated nodes and pre-authentication keys.

### 3.3. ACLs (Access Control Lists)

This section allows you to generate and manage your network\'s access control policy.

> **Important Note:** Adding one or more users may require an update to the ACL policy for their devices to work correctly.

**Basic principle: Strict Isolation by User**

This application\'s policy generator is based on a fundamental security principle: **each user is isolated in their own "bubble"**. By default:
- A user\'s devices can only communicate with that same user\'s other devices.
- If a user has an **exit node**, only their own devices can use it.
- If a user shares a **local subnet**, only their own devices can access it.
- John cannot see or contact Jane\'s devices, exit nodes, or subnets, and vice-versa.

**ACL page workflow:**

The ACL page has two main functions:

1.  **Generate the secure base policy:**
    - Press the **Générer la Politique** (Generate Policy) button.
    - The application will analyze all your users and devices and create a secure ACL policy based on the isolation principle described above.
    - The generated policy is displayed in the text field for inspection.
    - Use the menu (⋮) and select **Exporter vers le serveur** (Export to server) to apply the rules.

2.  **Create exceptions for maintenance:**
    - If you need to temporarily allow one of John\'s devices to communicate with one of Jane\'s devices, use the **Autorisations Spécifiques** (Specific Permissions) section.
    - Select a `Source` tag and a `Destination` tag.
    - Click **Ajouter et Appliquer** (Add and Apply).
    - The policy will be **automatically updated and applied** on the server to authorize this specific communication.
    - To remove the authorization, simply click the cross (x) on the active rule.

### 3.4. Testeur ACL (ACL Tester)

This new page, accessible via a dedicated button, allows you to test and visualize the impact of different ACL policies without applying them directly to your Headscale server. It\'s a safe environment for experimentation.
