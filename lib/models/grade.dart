class Grade {
  final String id;
  final String studentId;
  final String lessonId;
  final String grade;
  final DateTime createdAt;

  Grade({
    required this.id,
    required this.studentId,
    required this.lessonId,
    required this.grade,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'lessonId': lessonId,
      'grade': grade,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id'],
      studentId: json['studentId'],
      lessonId: json['lessonId'],
      grade: json['grade'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Grade copyWith({
    String? id,
    String? studentId,
    String? lessonId,
    String? grade,
    DateTime? createdAt,
  }) {
    return Grade(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      lessonId: lessonId ?? this.lessonId,
      grade: grade ?? this.grade,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
