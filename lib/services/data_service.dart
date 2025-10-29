import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../models/lesson.dart';
import '../models/grade.dart';
import '../models/todo_item.dart';

class DataService {
  static const String _studentsKey = 'students';
  static const String _attendanceKey = 'attendance';
  static const String _classesKey = 'classes';
  static const String _lessonsKey = 'lessons';
  static const String _gradesKey = 'grades';
  static const String _todosKey = 'todos';

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

  static Future<void> saveStudent(Student student) async {
    final students = await getStudents();
    final existingIndex = students.indexWhere((s) => s.id == student.id);
    
    if (existingIndex != -1) {
      // Update existing student
      students[existingIndex] = student;
    } else {
      // Add new student
      students.add(student);
    }
    
    await saveStudents(students);
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

  // Add test students
  static Future<void> addTestStudents() async {
    final testStudents = <Student>[];
    
    // Generate 42 test students
    for (int i = 1; i <= 42; i++) {
      testStudents.add(Student(
        id: 'test_student_$i',
        firstName: 'دانش‌آموز',
        lastName: '$i',
        studentNumber: i.toString(),
        classId: null, // No class assigned
      ));
    }
    
    // Add to existing students
    final existingStudents = await getStudents();
    existingStudents.addAll(testStudents);
    await saveStudents(existingStudents);
  }

  // Lesson management
  static Future<List<Lesson>> getLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final lessonsJson = prefs.getStringList(_lessonsKey) ?? [];
    return lessonsJson
        .map((json) => Lesson.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveLessons(List<Lesson> lessons) async {
    final prefs = await SharedPreferences.getInstance();
    final lessonsJson = lessons
        .map((lesson) => jsonEncode(lesson.toJson()))
        .toList();
    await prefs.setStringList(_lessonsKey, lessonsJson);
  }

  static Future<void> addLesson(Lesson lesson) async {
    final lessons = await getLessons();
    lessons.add(lesson);
    await saveLessons(lessons);
  }

  static Future<void> updateLesson(Lesson lesson) async {
    final lessons = await getLessons();
    final index = lessons.indexWhere((l) => l.id == lesson.id);
    if (index != -1) {
      lessons[index] = lesson;
      await saveLessons(lessons);
    }
  }

  static Future<void> deleteLesson(String lessonId) async {
    final lessons = await getLessons();
    lessons.removeWhere((l) => l.id == lessonId);
    await saveLessons(lessons);
    
    // Also remove grades for this lesson
    final grades = await getGrades();
    grades.removeWhere((grade) => grade.lessonId == lessonId);
    await saveGrades(grades);
  }

  // Grade management
  static Future<List<Grade>> getGrades() async {
    final prefs = await SharedPreferences.getInstance();
    final gradesJson = prefs.getStringList(_gradesKey) ?? [];
    return gradesJson
        .map((json) => Grade.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveGrades(List<Grade> grades) async {
    final prefs = await SharedPreferences.getInstance();
    final gradesJson = grades
        .map((grade) => jsonEncode(grade.toJson()))
        .toList();
    await prefs.setStringList(_gradesKey, gradesJson);
  }

  static Future<void> addGrade(Grade grade) async {
    final grades = await getGrades();
    grades.add(grade);
    await saveGrades(grades);
  }

  static Future<void> updateGrade(Grade grade) async {
    final grades = await getGrades();
    final index = grades.indexWhere((g) => g.id == grade.id);
    if (index != -1) {
      grades[index] = grade;
      await saveGrades(grades);
    }
  }

  static Future<void> deleteGrade(String gradeId) async {
    final grades = await getGrades();
    grades.removeWhere((g) => g.id == gradeId);
    await saveGrades(grades);
  }

  static Future<Grade?> getStudentGradeForLesson(String studentId, String lessonId) async {
    final grades = await getGrades();
    try {
      return grades.firstWhere((grade) => 
          grade.studentId == studentId && grade.lessonId == lessonId);
    } catch (e) {
      return null;
    }
  }

  static Future<List<Grade>> getGradesForLesson(String lessonId) async {
    final grades = await getGrades();
    return grades.where((grade) => grade.lessonId == lessonId).toList();
  }

  static Future<List<Grade>> getGradesForStudent(String studentId) async {
    final grades = await getGrades();
    return grades.where((grade) => grade.studentId == studentId).toList();
  }

  // Todo management
  static Future<List<TodoItem>> getTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getStringList(_todosKey) ?? [];
    return todosJson
        .map((json) => TodoItem.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveTodos(List<TodoItem> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = todos
        .map((todo) => jsonEncode(todo.toJson()))
        .toList();
    await prefs.setStringList(_todosKey, todosJson);
  }

  static Future<List<TodoItem>> getTodosForDate(DateTime date) async {
    final todos = await getTodos();
    return todos.where((todo) => 
        todo.date.year == date.year &&
        todo.date.month == date.month &&
        todo.date.day == date.day).toList();
  }

  static Future<void> addTodo(TodoItem todo) async {
    final todos = await getTodos();
    todos.add(todo);
    await saveTodos(todos);
  }

  static Future<void> updateTodo(TodoItem todo) async {
    final todos = await getTodos();
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
      await saveTodos(todos);
    }
  }

  static Future<void> deleteTodo(String todoId) async {
    final todos = await getTodos();
    todos.removeWhere((t) => t.id == todoId);
    await saveTodos(todos);
  }

  static Future<void> deleteTodosForDate(DateTime date) async {
    final todos = await getTodos();
    todos.removeWhere((todo) => 
        todo.date.year == date.year &&
        todo.date.month == date.month &&
        todo.date.day == date.day);
    await saveTodos(todos);
  }
}
