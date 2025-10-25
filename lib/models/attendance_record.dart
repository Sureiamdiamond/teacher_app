import 'package:persian_datetime_picker/persian_datetime_picker.dart';

enum AttendanceStatus {
  present,
  absent,
  late,
  excused,
}

class AttendanceRecord {
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;

  AttendanceRecord({
    required this.studentId,
    required this.date,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'date': date.toIso8601String(),
      'status': status.name,
      'notes': notes,
    };
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentId: json['studentId'],
      date: DateTime.parse(json['date']),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      notes: json['notes'],
    );
  }

  String get persianDate {
    final jalali = Jalali.fromDateTime(date);
    return '${jalali.year}/${jalali.month.toString().padLeft(2, '0')}/${jalali.day.toString().padLeft(2, '0')}';
  }

  String get statusText {
    switch (status) {
      case AttendanceStatus.present:
        return 'حاضر';
      case AttendanceStatus.absent:
        return 'غایب';
      case AttendanceStatus.late:
        return 'تأخیر';
      case AttendanceStatus.excused:
        return 'موجه';
    }
  }
}
