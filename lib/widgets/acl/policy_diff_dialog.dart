import 'package:material_ui/material_ui.dart';
import 'package:headscalemanager/utils/json_diff_utils.dart';

/// Dialogue d'aperçu des changements avant export vers Headscale.
///
/// Affiche un diff ligne-par-ligne coloré (`+` vert / `-` rouge) avec filtre
/// « Afficher uniquement les différences » et bascule automatique vers un résumé
/// par section au-delà de 1500 lignes.
class PolicyDiffDialog extends StatefulWidget {
  final Map<String, dynamic> currentPolicy;
  final Map<String, dynamic> newPolicy;
  final String? rawCurrentText;
  final String? rawNewText;
  final bool isFr;

  const PolicyDiffDialog({
    super.key,
    required this.currentPolicy,
    required this.newPolicy,
    this.rawCurrentText,
    this.rawNewText,
    required this.isFr,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> currentPolicy,
    required Map<String, dynamic> newPolicy,
    String? rawCurrentText,
    String? rawNewText,
    required bool isFr,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => PolicyDiffDialog(
        currentPolicy: currentPolicy,
        newPolicy: newPolicy,
        rawCurrentText: rawCurrentText,
        rawNewText: rawNewText,
        isFr: isFr,
      ),
    );
  }

  @override
  State<PolicyDiffDialog> createState() => _PolicyDiffDialogState();
}

class _PolicyDiffDialogState extends State<PolicyDiffDialog> {
  late final JsonDiffResult _diffResult;
  bool _onlyChanges = true;

  @override
  void initState() {
    super.initState();
    _diffResult = JsonDiffUtils.diffPolicies(
      currentPolicy: widget.currentPolicy,
      newPolicy: widget.newPolicy,
      rawCurrentText: widget.rawCurrentText,
      rawNewText: widget.rawNewText,
    );
  }

  String _summarize(Map<String, dynamic> policy) {
    final grants = (policy['grants'] as List?)?.length ?? 0;
    final acls = (policy['acls'] as List?)?.length ?? 0;
    final ssh = (policy['ssh'] as List?)?.length ?? 0;
    final tests = (policy['tests'] as List?)?.length ?? 0;
    final groups = (policy['groups'] as Map?)?.length ?? 0;
    return widget.isFr
        ? '$grants grants, $acls acls, $ssh ssh, $tests tests, $groups groupes'
        : '$grants grants, $acls acls, $ssh ssh, $tests tests, $groups groups';
  }

  List<_DiffDisplayEntry> _buildVisibleEntries() {
    final lines = _diffResult.lines;
    if (!_onlyChanges) {
      return [
        for (final line in lines) _DiffDisplayEntry.line(line),
      ];
    }

    const contextRadius = 2;
    final keep = List<bool>.filled(lines.length, false);
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].type != DiffLineType.unchanged) {
        final start = (i - contextRadius).clamp(0, lines.length - 1);
        final end = (i + contextRadius).clamp(0, lines.length - 1);
        for (var k = start; k <= end; k++) {
          keep[k] = true;
        }
      }
    }

    final entries = <_DiffDisplayEntry>[];
    var skippedStreak = false;
    for (var i = 0; i < lines.length; i++) {
      if (keep[i]) {
        if (skippedStreak && entries.isNotEmpty) {
          entries.add(const _DiffDisplayEntry.separator());
        }
        entries.add(_DiffDisplayEntry.line(lines[i]));
        skippedStreak = false;
      } else {
        skippedStreak = true;
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final isFr = widget.isFr;
    final theme = Theme.of(context);
    final changed = _diffResult.hasChanges;
    final entries = _diffResult.usedSectionFallback
        ? const <_DiffDisplayEntry>[]
        : _buildVisibleEntries();

    return AlertDialog(
      title: Text(
        isFr ? 'Aperçu des changements (Diff)' : 'Change Preview (Diff)',
      ),
      content: SizedBox(
        width: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isFr ? 'Serveur' : 'Server'}: ${_summarize(widget.currentPolicy)}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              '${isFr ? 'Brouillon' : 'Draft'}: ${_summarize(widget.newPolicy)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_diffResult.usedSectionFallback) ...[
                  _CountBadge(
                    label: '+${_diffResult.addedCount}',
                    color: Colors.green,
                  ),
                  _CountBadge(
                    label: '-${_diffResult.removedCount}',
                    color: Colors.red,
                  ),
                  FilterChip(
                    selected: _onlyChanges,
                    label: Text(
                      isFr
                          ? 'Afficher uniquement les différences'
                          : 'Show differences only',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onSelected: (value) => setState(() => _onlyChanges = value),
                  ),
                ] else
                  _CountBadge(
                    label: isFr
                        ? 'Résumé par section (>1500 lignes)'
                        : 'Section summary (>1500 lines)',
                    color: Colors.orange,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (!changed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.35)),
                ),
                child: Text(
                  isFr
                      ? 'Aucune différence détectée par rapport au serveur.'
                      : 'No difference detected compared to the server.',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (_diffResult.usedSectionFallback)
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _diffResult.sectionSummaries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final s = _diffResult.sectionSummaries[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          s.changed
                              ? Icons.change_circle_outlined
                              : Icons.check_circle_outline,
                          color: s.changed ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        title: Text(
                          s.section,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isFr
                              ? '${s.beforeCount} → ${s.afterCount} entrées'
                              : '${s.beforeCount} → ${s.afterCount} entries',
                        ),
                        trailing: Text(
                          s.changed
                              ? (isFr ? 'Modifié' : 'Modified')
                              : (isFr ? 'Inchangé' : 'Unchanged'),
                          style: TextStyle(
                            color: s.changed ? Colors.orange : Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 380),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (_, index) {
                        final entry = entries[index];
                        if (entry.isSeparator) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            child: const Text(
                              '⋯',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.grey,
                              ),
                            ),
                          );
                        }

                        final line = entry.line!;
                        final isAdded = line.type == DiffLineType.added;
                        final isRemoved = line.type == DiffLineType.removed;
                        final bgColor = isAdded
                            ? Colors.green.withValues(alpha: 0.16)
                            : isRemoved
                                ? Colors.red.withValues(alpha: 0.16)
                                : Colors.transparent;
                        final prefix = isAdded
                            ? '+'
                            : isRemoved
                                ? '-'
                                : ' ';
                        final textColor = isAdded
                            ? Colors.green.shade800
                            : isRemoved
                                ? Colors.red.shade800
                                : theme.colorScheme.onSurface;
                        final lineNum = isRemoved
                            ? '${line.oldLineNumber ?? ''}'
                            : '${line.newLineNumber ?? ''}';

                        return Container(
                          color: bgColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text(
                                  lineNum,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                prefix,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: SelectableText(
                                  line.content,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: changed ? () => Navigator.pop(context, true) : null,
          child: Text(isFr ? 'Confirmer export' : 'Confirm export'),
        ),
      ],
    );
  }
}

class _DiffDisplayEntry {
  final DiffLine? line;
  final bool isSeparator;

  const _DiffDisplayEntry.line(this.line) : isSeparator = false;
  const _DiffDisplayEntry.separator()
      : line = null,
        isSeparator = true;
}

class _CountBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CountBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
