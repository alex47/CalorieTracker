class EntryGroup {
  EntryGroup({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.prompt,
    required this.response,
  });

  final int id;
  final DateTime date;
  final DateTime createdAt;
  final String prompt;
  final String response;

  factory EntryGroup.fromMap(Map<String, Object?> map) {
    return EntryGroup(
      id: map['id'] as int,
      date: DateTime.parse(map['entry_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      prompt: map['prompt'] as String,
      response: map['response'] as String,
    );
  }
}
