class DaySummary {
  const DaySummary({
    required this.summary,
    required this.highlights,
    required this.issues,
    required this.suggestions,
  });

  final String summary;
  final List<String> highlights;
  final List<String> issues;
  final List<String> suggestions;

  factory DaySummary.fromMap(Map<String, dynamic> map) {
    return DaySummary(
      summary: (map['summary'] as String? ?? '').trim(),
      highlights: _stringList(map['highlights']),
      issues: _stringList(map['issues']),
      suggestions: _stringList(map['suggestions']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'summary': summary,
      'highlights': highlights,
      'issues': issues,
      'suggestions': suggestions,
    };
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }
}
