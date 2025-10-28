class Lesson {
  final String id;
  final String name;
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Lesson copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return Lesson(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
