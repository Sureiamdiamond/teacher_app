class TodoItem {
  final String id;
  final String text;
  final bool isCompleted;
  final DateTime date;

  TodoItem({
    required this.id,
    required this.text,
    required this.isCompleted,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'date': date.toIso8601String(),
    };
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'],
      text: json['text'],
      isCompleted: json['isCompleted'],
      date: DateTime.parse(json['date']),
    );
  }

  TodoItem copyWith({
    String? id,
    String? text,
    bool? isCompleted,
    DateTime? date,
  }) {
    return TodoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
    );
  }
}

