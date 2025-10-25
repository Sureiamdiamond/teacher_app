class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String studentNumber;

  Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.studentNumber,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'studentNumber': studentNumber,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      studentNumber: json['studentNumber'],
    );
  }

  Student copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? studentNumber,
  }) {
    return Student(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      studentNumber: studentNumber ?? this.studentNumber,
    );
  }
}
