import 'package:flutter/material.dart';
import 'package:headscalemanager/models/client_command.dart';
import 'package:headscalemanager/widgets/client_commands/command_card.dart';

class CommandsList extends StatelessWidget {
  final List<ClientCommand> filteredCommands;
  final bool isFr;
  final String selectedPlatform;
  final Function(String) onCopy;
  final Function(ClientCommand) onShare;
  final Function(ClientCommand) onConfigure;

  const CommandsList({
    super.key,
    required this.filteredCommands,
    required this.isFr,
    required this.selectedPlatform,
    required this.onCopy,
    required this.onShare,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredCommands.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Aucune commande trouvée' : 'No commands found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Essayez de modifier vos critères de recherche'
                  : 'Try adjusting your search criteria',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: filteredCommands.length,
      itemBuilder: (context, index) {
        final command = filteredCommands[index];
        return CommandCard(
          command: command,
          isFr: isFr,
          selectedPlatform: selectedPlatform,
          onCopy: onCopy,
          onShare: onShare,
          onConfigure: onConfigure,
        );
      },
    );
  }
}
