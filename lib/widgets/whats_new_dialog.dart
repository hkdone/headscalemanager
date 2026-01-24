import 'package:flutter/material.dart';
import 'package:headscalemanager/data/whats_new_data.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final versions = WhatsNewVersion.getVersions(isFr);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.new_releases_rounded,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isFr ? 'Nouveautés' : 'What\'s New',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Intro Text
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                isFr
                    ? 'Cette mise à jour inclut d\'importants changements pour assurer la compatibilité avec les serveurs Headscale v0.25 à v0.28.'
                    : 'This update includes important changes to ensure compatibility with Headscale servers v0.25 to v0.28.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // Content List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: versions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final item = versions[index];
                  // Highlight the latest version
                  final isLatest = index == 0;

                  return Card(
                    elevation: isLatest ? 2 : 0,
                    color: isLatest
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3)
                        : theme.cardColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isLatest
                              ? theme.colorScheme.primary.withValues(alpha: 0.5)
                              : theme.dividerColor.withValues(alpha: 0.5),
                        )),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.version,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          // Verification Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16,
                                    color: theme.colorScheme.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${isFr ? "Vérification" : "Verification"}: ${item.verification}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Footer Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isFr ? 'J\'ai compris' : 'Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
