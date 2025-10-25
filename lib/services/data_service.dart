import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';

class DataService {
  static const String _studentsKey = 'students';
  static const String _attendanceKey = 'attendance';
  static const String _classesKey = 'classes';

  // Student management
  static Future<List<Student>> getStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final studentsJson = prefs.getStringList(_studentsKey) ?? [];
    return studentsJson
        .map((json) => Student.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStudents(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    final studentsJson = students
        .map((student) => jsonEncode(student.toJson()))
        .toList();
    await prefs.setStringList(_studentsKey, studentsJson);
  }

  static Future<void> addStudent(Student student) async {
    final students = await getStudents();
    students.add(student);
    await saveStudents(students);
  }

  static Future<void> updateStudent(Student student) async {
    final students = await getStudents();
    final index = students.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      students[index] = student;
      await saveStudents(students);
    }
  }

  static Future<void> deleteStudent(String studentId) async {
    final students = await getStudents();
    students.removeWhere((s) => s.id == studentId);
    await saveStudents(students);
    
    // Also remove attendance records for this student
    final attendance = await getAttendanceRecords();
    attendance.removeWhere((record) => record.studentId == studentId);
    await saveAttendanceRecords(attendance);
  }

  static Future<void> deleteAllStudents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_studentsKey);
    await prefs.remove(_attendanceKey);
  }

  // Attendance management
  static Future<List<AttendanceRecord>> getAttendanceRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final attendanceJson = prefs.getStringList(_attendanceKey) ?? [];
    return attendanceJson
        .map((json) => AttendanceRecord.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveAttendanceRecords(List<AttendanceRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = records
        .map((record) => jsonEncode(record.toJson()))
        .toList();
    await prefs.setStringList(_attendanceKey, recordsJson);
  }

  static Future<void> markAttendance(String studentId, DateTime date, AttendanceStatus status, {String? notes}) async {
    final records = await getAttendanceRecords();
    
    // Remove existing record for this student and date
    records.removeWhere((record) => 
        record.studentId == studentId && 
        record.date.year == date.year &&
        record.date.month == date.month &&
        record.date.day == date.day);
    
    // Add new record
    records.add(AttendanceRecord(
      studentId: studentId,
      date: date,
      status: status,
      notes: notes,
    ));
    
    await saveAttendanceRecords(records);
  }

  static Future<List<AttendanceRecord>> getAttendanceForDate(DateTime date) async {
    final records = await getAttendanceRecords();
    return records.where((record) => 
        record.date.year == date.year &&
        record.date.month == date.month &&
        record.date.day == date.day).toList();
  }

  static Future<AttendanceRecord?> getStudentAttendanceForDate(String studentId, DateTime date) async {
    final records = await getAttendanceRecords();
    try {
      return records.firstWhere((record) => 
          record.studentId == studentId &&
          record.date.year == date.year &&
          record.date.month == date.month &&
          record.date.day == date.day);
    } catch (e) {
      return null;
    }
  }

  // Class management
  static Future<List<ClassModel>> getClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final classesJson = prefs.getStringList(_classesKey) ?? [];
    return classesJson
        .map((json) => ClassModel.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveClasses(List<ClassModel> classes) async {
    final prefs = await SharedPreferences.getInstance();
    final classesJson = classes
        .map((classModel) => jsonEncode(classModel.toJson()))
        .toList();
    await prefs.setStringList(_classesKey, classesJson);
  }

  static Future<void> addClass(ClassModel classModel) async {
    final classes = await getClasses();
    classes.add(classModel);
    await saveClasses(classes);
  }

  static Future<void> updateClass(ClassModel classModel) async {
    final classes = await getClasses();
    final index = classes.indexWhere((c) => c.id == classModel.id);
    if (index != -1) {
      classes[index] = classModel;
      await saveClasses(classes);
    }
  }

  static Future<void> deleteClass(String classId) async {
    final classes = await getClasses();
    classes.removeWhere((c) => c.id == classId);
    await saveClasses(classes);
  }

  static Future<void> deleteAllClasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_classesKey);
  }

  // Get students by class
  static Future<List<Student>> getStudentsByClass(String classId) async {
    final allStudents = await getStudents();
    return allStudents.where((student) => student.classId == classId).toList();
  }

  // Get students without class
  static Future<List<Student>> getStudentsWithoutClass() async {
    final allStudents = await getStudents();
    return allStudents.where((student) => student.classId == null).toList();
  }
}
