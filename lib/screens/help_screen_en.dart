import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// English help screen for the application.
///
/// Provides information on prerequisites, Headscale server installation,
/// and a page-by-page guide to using the application.
class HelpScreenEn extends StatelessWidget {
  const HelpScreenEn({super.key});

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
                'Help and User Guide',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildBodyText(
                context,
                'Welcome to the Headscale Manager app user guide!',
              ),
              const SizedBox(height: 8),
              _buildBodyText(
                context,
                'This application allows you to easily manage your Headscale server. This guide will help you configure your server and use the application.',
              ),
              const SizedBox(height: 24),

              // API Section
              _buildSectionTitle(context, 'How it works: API'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'The application uses direct calls to the Headscale API for all management operations.'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Direct Actions (via API):'),
                const SizedBox(height: 8),
                _buildCodeBlock(
                  context,
                  'These actions are performed directly by the application:\n'
                  '- List users and nodes.\n'
                  '- Create and delete users.\n'
                  '- Create and invalidate pre-authentication keys.\n'
                  '- Manage API keys.\n'
                  '- Move a node to another user.\n'
                  '- Delete a node.\n'
                  '- Enable/Disable routes (subnets and exit node).',
                ),
              ]),
              const SizedBox(height: 24),

              // Tutorial Section
              _buildSectionTitle(
                  context, 'Tutorial: Add and configure a device'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'Here are the complete steps to add a new device (node) to your Headscale network.'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Step 1: Create a user'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'If not already done, go to the "Users" tab and create a new user (e.g., "my-user").'),
                const SizedBox(height: 16),
                _buildSubTitle(context, 'Step 2: Register the device'),
                const SizedBox(height: 8),
                _buildBodyText(
                    context, 'There are two main methods:'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'A) With a pre-authentication key (Recommended)',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '1. In the "Users" tab, click the key icon and create a key for your user. Even if no boxes are checked, it is necessary to set a 1-day expiration for the key to generate a valid key.\n'
                  '2. Copy the provided `tailscale up ...` command.\n'
                  '3. Run this command on the device you want to add. It will be automatically registered and will appear on your dashboard.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'B) Registration via the application (for mobile clients)',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '1. On the client device (iOS/Android): In the Tailscale app, go to settings, select "Use alternate server", and paste your Headscale server URL.\n'
                  '2. In the Headscale Manager app: After completing step 1, the Tailscale client will provide you with a unique registration URL. In the Headscale Manager app, go to the user details, click "Register a new device", and paste the URL provided by the client. The device will be registered directly via the API.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context,
                    'Step 3 (Optional): Rename the node and add tags'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Once the node appears on the dashboard, you can configure it. This is a crucial step if you use tag-based ACLs.'),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '1. Go to the node details by clicking on it.\n'
                  '2. Use the menu to rename it (e.g., "my-phone").\n'
                  '3. Click the pencil icon to edit the tags. Add the relevant tags (e.g., `tag:user-phone`, `tag:user-laptop`). The application will update the tags directly via the API.',
                  isSmall: true,
                ),
              ]),
              const SizedBox(height: 24),

              // Prerequisites Section
              _buildSectionTitle(
                  context, '1. Prerequisites and Headscale Server Installation'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'To use this application, you must have a functional Headscale server. Here\'s how to set it up:'),
                const SizedBox(height: 16),
                _buildSubTitle(
                    context, '1.1. Installing Headscale with Docker'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'It is recommended to install Headscale via Docker using the official `headscale/headscale` image. Make sure to configure data persistence by mounting the necessary volumes.'),
                const SizedBox(height: 8),
                _buildBodyText(
                    context, 'Example Docker command (to be adapted):'),
                const SizedBox(height: 4),
                _buildCodeBlock(
                  context,
                  '''docker run -d --name headscale 
  -v <local_config_path>:/etc/headscale 
  -v <local_data_path>:/var/lib/headscale 
  -p 8080:8080 
  headscale/headscale:latest''',
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '- `<local_config_path>`: Path on your host machine where the `config.yaml` file will be located.\n'
                  '- `<local_data_path>`: Path on your host machine for Headscale data persistence (database, etc.).',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '1.2. Configuration Files'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'In the configuration volume (`<local_config_path>`), you will need two files:'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '- **`config.yaml`**: The main configuration file for Headscale. Here is a "turnkey" configuration example:'),
                const SizedBox(height: 4),
                _buildCodeBlock(
                  context,
                  '''server_url: https://<YOUR_PUBLIC_FQDN>:8081
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
   enabled: true''',
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**Don\'t forget to replace `<YOUR_PUBLIC_FQDN>` with the public domain name you will be using.**',
                    isBold: true),
                const SizedBox(height: 16),
                _buildSubTitle(context,
                    '1.3. Configuring a Reverse Proxy (Recommended)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'For security and accessibility reasons, it is highly recommended to place your Headscale server behind a reverse proxy (like Nginx, Caddy, or Traefik).'),
                const SizedBox(height: 8),
                _buildBodyText(context, 'Make sure that:'),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- You have a **public FQDN (Fully Qualified Domain Name)** (e.g., `headscale.mydomain.com`).\n'
                  '- You have a **valid SSL/TLS certificate** for this FQDN (e.g., via Let\'s Encrypt).\n'
                  '- The reverse proxy redirects the **external HTTPS port (8081)** to the **internal HTTP port (8080)** of your Headscale container.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(
                    context, '1.4. Generating the Headscale API Key'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Once your Headscale server is operational and accessible via your public FQDN, you will need to generate an API key for the application to connect to it.'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Connect to your Headscale server (e.g., via SSH on the Docker host machine) and use the command:'),
                const SizedBox(height: 4),
                _buildCodeBlock(context, 'headscale apikeys create'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**Keep this unique API key safe in a password manager.** It is essential for application authentication.',
                    isBold: true),
              ]),
              const SizedBox(height: 24),

              const SizedBox(height: 24),
              _buildSectionTitle(context, '2. Application Configuration'),
              _buildInfoCard(context, children: [
                _buildBodyText(
                    context, 'In the Headscale Manager application:'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '1.  Go to the **Settings** screen (gear icon in the top right).'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '2.  Enter the **public address of your Headscale server** (your public FQDN, e.g., `https://headscale.mydomain.com`).'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '3.  Paste the **API key** you generated earlier.'),
                const SizedBox(height: 4),
                _buildBodyText(context,
                    '4.  Save the settings. The application is now ready to connect to your server!'),
              ]),
              const SizedBox(height: 24),

              _buildSectionTitle(context, '3. Using the Application'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'The application is divided into several sections accessible via the bottom navigation bar:'),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.1. Dashboard'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'This screen displays an overview of the status of your Headscale network. You will find information on the number of online/offline nodes, the number of users, etc. Nodes are grouped by user and can be expanded to show more details. Tapping on a node will take you to its details screen.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Buttons and Features:**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Expand/Collapse user groups:** Tap on a user\'s name to show or hide the nodes associated with them.\n'
                  '- **Show node details:** Tap on any node in the list to navigate to its details screen (`Node Details`).\n'
                  '- **Manage API keys (api icon):** Opens a screen to manage the API keys of your Headscale server.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.2. Users'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Manage the users of your Headscale server. You can see the list of existing users, create new ones, and delete them.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Buttons and Features:**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Add User (+ icon at the bottom right):** Opens a dialog to create a new user. Simply enter the desired username. The application will automatically add `the domain suffix of your Headscale server (e.g., \'@your_domain.com\')` to the username if not present.\n'
                  '- **Manage pre-authentication keys (vpn_key icon at the bottom right):** Opens a screen to manage the pre-authentication keys of your Headscale server.\n'
                  '- **Delete User (trash can icon next to each user):** Deletes the selected user. A confirmation will be requested. Note that deletion will fail if the user still has devices.\n'
                  '- **User Details (click on a user):** Displays user details, including associated nodes and pre-authentication keys.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.3. ACLs (Access Control Lists)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'This section allows you to generate and manage your network\'s access control policy.'),
                const SizedBox(height: 16),
                _buildBodyText(
                  context,
                  '**Important Note:** Adding one or more users may require an update to the ACL policy for their devices to work correctly.',
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    '**Basic Principle: Strict User Isolation**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  'The policy generator in this application is based on a fundamental security principle: **each user is isolated in their own "bubble"**. By default:\n'
                  '- A user\'s devices can only communicate with other devices of the same user.\n'
                  '- If a user has an **exit node**, only their own devices can use it.\n'
                  '- If a user shares a **local subnet**, only their own devices can access it.\n'
                  '- John cannot see or contact the devices, exit nodes, or subnets of Clarisse, and vice versa.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildBodyText(
                    context, '**Workflow for using the ACL page:**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  'The ACL page has two main functions:',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '**1. Generate the secure base policy:**\n'
                  '- Press the **Generate Policy** button.\n'
                  '- The application will analyze all your users and devices and create a secure ACL policy.\n'
                  '- The generated policy is displayed in the text field for inspection.\n'
                  '- Use the menu (⋮) and select **Export to server** to apply the rules.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(
                  context,
                  '**2. Create exceptions for maintenance:**\n'
                  '- If you need to temporarily allow a device from John to communicate with a device from Clarisse, use the **Specific Permissions** section.\n'
                  '- Select a `Source` tag and a `Destination` tag.\n'
                  '- Click **Add and Apply**.\n'
                  '- The policy will be **automatically updated and applied** on the server.\n'
                  '- To remove the permission, simply click the cross (x) on the active rule.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.4. ACL Tester'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'This new page allows you to test and visualize the impact of different ACL policies without applying them directly to your Headscale server. It is a safe environment for experimentation.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Features:**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Policy Generation:** Similar to the main ACL page, you can generate a policy based on your existing users and nodes.\n'
                  '- **Temporary Rules:** Add and remove temporary rules to see how they affect the generated policy.\n'
                  '- **Instant Visualization:** The resulting ACL policy is displayed in real-time in a text field, allowing you to inspect it.\n'
                  '- **Optional Export:** Once satisfied with the result, you can choose to export the policy to your Headscale server.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '3.5. Network Overview'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'This screen, accessible from the navigation bar, offers a dynamic, real-time view of your network topology from the perspective of the current device. It is particularly useful for diagnosing connections and checking which `exit node` is being used.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Main Features:**',
                    isBold: true),
                const SizedBox(height: 4),
                _buildBodyText(
                  context,
                  '- **Current Node Selector:** At the top of the page, a dropdown menu allows you to select the device you consider your starting point.\n'
                  '- **Path Visualization:** A simple graph shows the network path from your selected device to the Internet. If traffic passes through an `exit node` on your Headscale network, it will be displayed as an intermediary.\n'
                  '- **Exit Node Detection:** The page performs a `traceroute` to a public destination (Google DNS) to map the hops. If one of the hops matches the IP address of one of your nodes, that node is identified as the exit node currently in use.\n'
                  '- **Ping Status:** A list of all other nodes on your network is displayed with their status (online/offline) and average latency.\n'
                  '- **Traceroute Details:** An expandable section shows you the raw `traceroute` result, listing each hop (IP address) between your device and the final destination.',
                  isSmall: true,
                ),
              ]),
              const SizedBox(height: 24),

              // Advanced Features Section
              _buildSectionTitle(context, '4. Advanced Features'),
              _buildInfoCard(context, children: [
                _buildBodyText(context,
                    'This section describes advanced features that simplify security management and network monitoring.'),
                const SizedBox(height: 16),
                _buildSubTitle(
                    context, '4.1. Simplified Permission Management (ACLs)'),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'Headscale Manager introduces several mechanisms to make Access Control List (ACL) management more intuitive and less error-prone.'),
                const SizedBox(height: 16),
                _buildBodyText(context, 'A. Automation from the Dashboard',
                    isBold: true),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'The dashboard is now your command center for common permissions. When nodes request to share subnets or become an "Exit Node", warning icons appear.'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**One-Click Approval:**',
                    isBold: true),
                _buildBodyText(
                  context,
                  '1. **Adds the relevant tags** to the node (e.g., `;lan-sharer` or `;exit-node`).\n'
                  '2. **Approves the requested routes**.\n'
                  '3. **Regenerates and applies the full ACL policy**.\n'
                  '*Benefit:* No more need to manually edit tags and the ACL policy. Everything is done in a single step.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Smart Cleanup:**', isBold: true),
                _buildBodyText(
                  context,
                  'If a client disables sharing, a blue icon appears. The cleanup process:\n'
                  '1. **Removes obsolete tags**.\n'
                  '2. **Deletes unadvertised routes**.\n'
                  '3. **Regenerates the ACL policy** to revoke permissions.\n'
                  '*Benefit:* Keeps your configuration clean and synchronized.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildBodyText(context, 'B. Specific Permissions (ACL Exceptions)',
                    isBold: true),
                const SizedBox(height: 8),
                _buildBodyText(context,
                    'The "ACLs" page allows creating exceptions to the user isolation rule (e.g., allowing access between devices of `John` and `Jane`).'),
                const SizedBox(height: 8),
                _buildBodyText(context, '**Specific Case: Access to Shared Subnets**',
                    isBold: true),
                _buildBodyText(
                  context,
                  'If the destination shares subnets, you can grant **Full Access** or **Custom Access** (specific IPs/ports), providing very fine-grained control.',
                  isSmall: true,
                ),
                const SizedBox(height: 16),
                _buildSubTitle(context, '4.2. Notifications and Monitoring'),
                const SizedBox(height: 8),
                _buildBodyText(context, 'A. Background Notifications',
                    isBold: true),
                _buildBodyText(
                  context,
                  'Enable in **Settings**. The app checks every 15 minutes and notifies you if an approval or cleanup is required.',
                  isSmall: true,
                ),
                const SizedBox(height: 8),
                _buildBodyText(context, 'B. Per-Node Status Monitoring',
                    isBold: true),
                _buildBodyText(
                  context,
                  'On a **node\'s detail page**, enable **"Monitor Status"** to be notified whenever that node goes from "online" to "offline", or vice-versa.',
                  isSmall: true,
                ),
              ]),
              const SizedBox(height: 24),

              _buildInfoCard(context, children: [
                _buildBodyText(
                  context,
                  '**Important Note on Node Modifications:**\n'
                  'Any modification made to a node (addition, renaming, moving, tag modification, enabling/disabling routes) via this application is immediately saved in the Headscale database. However, for these changes to be truly taken into account by other nodes on the network and for the new configuration to be propagated, it is often necessary to restart the Headscale service on your server. Headscale pushes information from its database to other nodes mainly when the service starts.',
                  isBold: true,
                ),
              ]),
              const SizedBox(height: 24),

              _buildBodyText(
                  context,
                  'For any questions or issues, please consult the official Headscale documentation or community resources.'),
              const SizedBox(height: 24),

              // GitHub Card
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
                        content: Text('GitHub link copied!',
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
    // Use RichText to handle bold with asterisks
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
                FontWeight.bold, // Always bold for what is matched
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
