import 'package:flutter/material.dart';
import 'package:headscalemanager/models/client_command.dart';

class CommandCard extends StatelessWidget {
  final ClientCommand command;
  final bool isFr;
  final String selectedPlatform;
  final Function(String) onCopy;
  final Function(ClientCommand) onShare;
  final Function(ClientCommand) onConfigure;

  const CommandCard({
    super.key,
    required this.command,
    required this.isFr,
    required this.selectedPlatform,
    required this.onCopy,
    required this.onShare,
    required this.onConfigure,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Connexion':
        return Colors.green;
      case 'Routage':
        return Colors.blue;
      case 'Dépannage':
        return Colors.orange;
      case 'Configuration':
        return Colors.purple;
      case 'Surveillance':
        return Colors.teal;
      case 'Sécurité':
        return Colors.red;
      case 'Maintenance':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Connexion':
        return Icons.link;
      case 'Routage':
        return Icons.route;
      case 'Dépannage':
        return Icons.build;
      case 'Configuration':
        return Icons.settings;
      case 'Surveillance':
        return Icons.monitor;
      case 'Sécurité':
        return Icons.security;
      case 'Maintenance':
        return Icons.handyman;
      default:
        return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformCommand = command.getCommandForPlatform(selectedPlatform);
    final isLinuxSpecific =
        command.tags.contains('linux') && selectedPlatform == 'Windows';
    final isDynamic = command.isDynamic;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(command.category),
          child: Icon(
            _getCategoryIcon(command.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                command.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (command.requiresElevation)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ADMIN',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              command.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    command.category,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isDynamic)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFr ? 'DYNAMIQUE' : 'DYNAMIC',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (isLinuxSpecific)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFr ? 'N/A Windows' : 'N/A Windows',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commande
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selectedPlatform == 'Windows'
                                ? Icons.computer
                                : Icons.terminal,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$selectedPlatform:',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        isDynamic
                            ? (isFr
                                ? 'La commande sera générée...'
                                : 'Command will be generated...')
                            : platformCommand,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              backgroundColor: isLinuxSpecific
                                  ? Colors.grey.withOpacity(0.1)
                                  : null,
                              color: isLinuxSpecific || isDynamic
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                ),

                // Notes
                if (command.notes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isFr ? 'Notes:' : 'Notes:',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          command.notes!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.blue.shade700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Boutons d'action
                if (isDynamic)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => onConfigure(command),
                      icon: const Icon(Icons.settings, size: 16),
                      label: Text(isFr ? 'Configurer et voir la commande' : 'Configure & View Command'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLinuxSpecific
                              ? null
                              : () => onCopy(platformCommand),
                          icon: const Icon(Icons.copy, size: 16),
                          label: Text(isFr ? 'Copier' : 'Copy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              isLinuxSpecific ? null : () => onShare(command),
                          icon: const Icon(Icons.share, size: 16),
                          label: Text(isFr ? 'Partager' : 'Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}