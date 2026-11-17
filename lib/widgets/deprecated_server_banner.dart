import 'package:flutter/material.dart';
import 'package:headscalemanager/models/version_info.dart';

/// Bandeau rouge d'avertissement affiché lorsque le serveur Headscale connecté
/// accuse au moins 2 versions majeures/mineures de retard (<= N-2, soit <= 0.27
/// par rapport à la référence courante 0.29).
class DeprecatedServerBanner extends StatelessWidget {
  final String? serverVersion;
  final bool isFr;
  final VoidCallback? onOpenDiagnostic;
  final EdgeInsetsGeometry margin;

  const DeprecatedServerBanner({
    super.key,
    required this.serverVersion,
    required this.isFr,
    this.onOpenDiagnostic,
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    if (!VersionInfo.isServerDeprecated(serverVersion)) {
      return const SizedBox.shrink();
    }

    final versionLabel = (serverVersion ?? '').trim();
    final isPre26 = VersionInfo.isPreV26(serverVersion);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.red.shade300 : Colors.red.shade800;
    final bodyColor = isDark ? Colors.red.shade100 : Colors.red.shade900;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade700.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.red.shade400 : Colors.red.shade700,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: accentColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFr
                          ? 'Serveur Headscale obsolète ($versionLabel)'
                          : 'Outdated Headscale server ($versionLabel)',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFr
                          ? 'Votre serveur a au moins 2 versions de retard sur la version courante (v${VersionInfo.currentReferenceShort}). Veuillez mettre à jour votre serveur Headscale : la prise en charge des fonctions dépréciées pour cette version sera retirée lors de la prochaine mise à jour majeure de l\'application.${isPre26 ? ' Les règles pré-0.26 (sans @ ou exitNodes) ne sont plus supportées.' : ''}'
                          : 'Your server is at least 2 versions behind the current release (v${VersionInfo.currentReferenceShort}). Please upgrade your Headscale server: deprecated compatibility features for this version will be removed in the next major app update.${isPre26 ? ' Pre-0.26 policy workarounds are no longer supported.' : ''}',
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onOpenDiagnostic != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onOpenDiagnostic,
                icon: Icon(
                  Icons.health_and_safety_outlined,
                  size: 16,
                  color: accentColor,
                ),
                label: Text(
                  isFr
                      ? 'Vérifier la compatibilité ACL'
                      : 'Check ACL compatibility',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: accentColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
