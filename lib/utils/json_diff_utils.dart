import 'dart:convert';

/// Type d'une ligne dans un diff textuel.
enum DiffLineType { unchanged, added, removed }

/// Représente une ligne du comparateur ligne-par-ligne.
class DiffLine {
  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

/// Résumé d'évolution pour une section JSON de premier niveau
/// (utilisé au-delà du seuil de 1500 lignes pour garantir la fluidité UI).
class SectionDiffSummary {
  final String section;
  final int beforeCount;
  final int afterCount;
  final bool changed;

  const SectionDiffSummary({
    required this.section,
    required this.beforeCount,
    required this.afterCount,
    required this.changed,
  });
}

/// Résultat complet d'une comparaison JSON/HuJSON.
class JsonDiffResult {
  final List<DiffLine> lines;
  final int addedCount;
  final int removedCount;
  final bool usedSectionFallback;
  final List<SectionDiffSummary> sectionSummaries;

  const JsonDiffResult({
    required this.lines,
    required this.addedCount,
    required this.removedCount,
    this.usedSectionFallback = false,
    this.sectionSummaries = const [],
  });

  bool get hasChanges =>
      addedCount > 0 ||
      removedCount > 0 ||
      sectionSummaries.any((summary) => summary.changed);
}

/// Utilitaire de calcul de diff ligne-par-ligne (LCS) avec garde-fou 1500 lignes.
class JsonDiffUtils {
  static const int maxExactDiffLines = 1500;
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Compare deux politiques ACL (et éventuellement leurs textes bruts HuJSON).
  ///
  /// Utilise le texte brut dès qu'un commentaire ou une modification purement
  /// textuelle/HuJSON existe, sinon formate les maps avec indentation 2 espaces.
  static JsonDiffResult diffPolicies({
    required Map<String, dynamic> currentPolicy,
    required Map<String, dynamic> newPolicy,
    String? rawCurrentText,
    String? rawNewText,
    int maxExactLines = maxExactDiffLines,
  }) {
    final beforeFormatted = _encoder.convert(currentPolicy);
    final afterFormatted = _encoder.convert(newPolicy);
    final structChanged = beforeFormatted != afterFormatted;

    final hasRawPair = rawCurrentText != null && rawNewText != null;
    final hasComments = hasRawPair &&
        (_containsHuJsonSyntax(rawCurrentText) ||
            _containsHuJsonSyntax(rawNewText));

    final beforeText = (hasRawPair && (!structChanged || hasComments))
        ? rawCurrentText
        : beforeFormatted;
    final afterText = (hasRawPair && (!structChanged || hasComments))
        ? rawNewText
        : afterFormatted;

    final beforeLines = _splitLines(beforeText);
    final afterLines = _splitLines(afterText);

    if (beforeLines.length > maxExactLines ||
        afterLines.length > maxExactLines) {
      final summaries = summarizeSections(currentPolicy, newPolicy);
      return JsonDiffResult(
        lines: const [],
        addedCount: 0,
        removedCount: 0,
        usedSectionFallback: true,
        sectionSummaries: summaries,
      );
    }

    return diffText(beforeText, afterText, maxExactLines: maxExactLines);
  }

  /// Calcule le diff LCS ligne-par-ligne entre deux chaînes.
  static JsonDiffResult diffText(
    String beforeText,
    String afterText, {
    int maxExactLines = maxExactDiffLines,
  }) {
    final oldLines = _splitLines(beforeText);
    final newLines = _splitLines(afterText);

    if (oldLines.length > maxExactLines || newLines.length > maxExactLines) {
      return const JsonDiffResult(
        lines: [],
        addedCount: 0,
        removedCount: 0,
        usedSectionFallback: true,
      );
    }

    // Réduction préliminaire du préfixe et du suffixe communs pour accélérer le LCS.
    var prefixLen = 0;
    final minLen =
        oldLines.length < newLines.length ? oldLines.length : newLines.length;
    while (prefixLen < minLen && oldLines[prefixLen] == newLines[prefixLen]) {
      prefixLen++;
    }

    var suffixLen = 0;
    while (suffixLen < (oldLines.length - prefixLen) &&
        suffixLen < (newLines.length - prefixLen) &&
        oldLines[oldLines.length - 1 - suffixLen] ==
            newLines[newLines.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final result = <DiffLine>[];
    for (var i = 0; i < prefixLen; i++) {
      result.add(DiffLine(
        type: DiffLineType.unchanged,
        content: oldLines[i],
        oldLineNumber: i + 1,
        newLineNumber: i + 1,
      ));
    }

    final oldMid = oldLines.sublist(prefixLen, oldLines.length - suffixLen);
    final newMid = newLines.sublist(prefixLen, newLines.length - suffixLen);
    final midDiff = _computeLcsDiff(
      oldMid,
      newMid,
      oldLineOffset: prefixLen,
      newLineOffset: prefixLen,
    );
    result.addAll(midDiff);

    final oldSuffixStart = oldLines.length - suffixLen;
    final newSuffixStart = newLines.length - suffixLen;
    for (var i = 0; i < suffixLen; i++) {
      result.add(DiffLine(
        type: DiffLineType.unchanged,
        content: oldLines[oldSuffixStart + i],
        oldLineNumber: oldSuffixStart + i + 1,
        newLineNumber: newSuffixStart + i + 1,
      ));
    }

    var added = 0;
    var removed = 0;
    for (final line in result) {
      if (line.type == DiffLineType.added) added++;
      if (line.type == DiffLineType.removed) removed++;
    }

    return JsonDiffResult(
      lines: result,
      addedCount: added,
      removedCount: removed,
    );
  }

  /// Construit un résumé par section JSON de premier niveau (`groups`, `acls`, `grants`, `ssh`, `tests`, ...).
  static List<SectionDiffSummary> summarizeSections(
    Map<String, dynamic> currentPolicy,
    Map<String, dynamic> newPolicy,
  ) {
    const preferredOrder = <String>[
      'groups',
      'tagOwners',
      'hosts',
      'autoApprovers',
      'acls',
      'grants',
      'ssh',
      'tests',
      'nodeAttrs',
      'ipsets',
    ];

    final allKeys = <String>{
      ...preferredOrder.where(
          (k) => currentPolicy.containsKey(k) || newPolicy.containsKey(k)),
      ...currentPolicy.keys,
      ...newPolicy.keys,
    };

    return allKeys.map((key) {
      final beforeVal = currentPolicy[key];
      final afterVal = newPolicy[key];
      final changed =
          jsonEncode(beforeVal) != jsonEncode(afterVal);
      return SectionDiffSummary(
        section: key,
        beforeCount: _countEntries(beforeVal),
        afterCount: _countEntries(afterVal),
        changed: changed,
      );
    }).toList();
  }

  static List<DiffLine> _computeLcsDiff(
    List<String> oldMid,
    List<String> newMid, {
    required int oldLineOffset,
    required int newLineOffset,
  }) {
    final m = oldMid.length;
    final n = newMid.length;

    if (m == 0 && n == 0) return const [];
    if (m == 0) {
      return [
        for (var j = 0; j < n; j++)
          DiffLine(
            type: DiffLineType.added,
            content: newMid[j],
            newLineNumber: newLineOffset + j + 1,
          ),
      ];
    }
    if (n == 0) {
      return [
        for (var i = 0; i < m; i++)
          DiffLine(
            type: DiffLineType.removed,
            content: oldMid[i],
            oldLineNumber: oldLineOffset + i + 1,
          ),
      ];
    }

    final cols = n + 1;
    final dp = List<int>.filled((m + 1) * cols, 0);

    for (var i = m - 1; i >= 0; i--) {
      final rowOffset = i * cols;
      final nextRowOffset = (i + 1) * cols;
      for (var j = n - 1; j >= 0; j--) {
        if (oldMid[i] == newMid[j]) {
          dp[rowOffset + j] = dp[nextRowOffset + j + 1] + 1;
        } else {
          final down = dp[nextRowOffset + j];
          final right = dp[rowOffset + j + 1];
          dp[rowOffset + j] = down >= right ? down : right;
        }
      }
    }

    final out = <DiffLine>[];
    var i = 0;
    var j = 0;
    while (i < m && j < n) {
      if (oldMid[i] == newMid[j]) {
        out.add(DiffLine(
          type: DiffLineType.unchanged,
          content: oldMid[i],
          oldLineNumber: oldLineOffset + i + 1,
          newLineNumber: newLineOffset + j + 1,
        ));
        i++;
        j++;
      } else if (dp[(i + 1) * cols + j] >= dp[i * cols + (j + 1)]) {
        out.add(DiffLine(
          type: DiffLineType.removed,
          content: oldMid[i],
          oldLineNumber: oldLineOffset + i + 1,
        ));
        i++;
      } else {
        out.add(DiffLine(
          type: DiffLineType.added,
          content: newMid[j],
          newLineNumber: newLineOffset + j + 1,
        ));
        j++;
      }
    }

    while (i < m) {
      out.add(DiffLine(
        type: DiffLineType.removed,
        content: oldMid[i],
        oldLineNumber: oldLineOffset + i + 1,
      ));
      i++;
    }
    while (j < n) {
      out.add(DiffLine(
        type: DiffLineType.added,
        content: newMid[j],
        newLineNumber: newLineOffset + j + 1,
      ));
      j++;
    }

    return out;
  }

  static List<String> _splitLines(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trimRight();
    if (normalized.isEmpty) return const [];
    return normalized.split('\n');
  }

  static bool _containsHuJsonSyntax(String text) =>
      text.contains('//') || text.contains('/*');

  static int _countEntries(dynamic value) {
    if (value is List) return value.length;
    if (value is Map) return value.length;
    if (value == null) return 0;
    return 1;
  }
}
