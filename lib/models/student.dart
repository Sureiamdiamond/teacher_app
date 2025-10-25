class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String studentNumber;
  final String? classId;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentNumber,
    this.classId,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'studentNumber': studentNumber,
      'classId': classId,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      studentNumber: json['studentNumber'],
      classId: json['classId'],
    );
  }

  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? studentNumber,
    String? classId,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      studentNumber: studentNumber ?? this.studentNumber,
      classId: classId ?? this.classId,
    );
  }
}
