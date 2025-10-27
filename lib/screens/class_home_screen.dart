import 'dart:async';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../services/data_service.dart';
import 'add_student_screen.dart';
import 'attendance_history_screen.dart';
import 'edit_student_screen.dart';

class ClassHomeScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassHomeScreen({
    super.key,
    required this.classModel,
  });

  @override
  State<ClassHomeScreen> createState() => _ClassHomeScreenState();
}

class _ClassHomeScreenState extends State<ClassHomeScreen> {
  List<Student> students = [];
  DateTime selectedDate = DateTime.now();
  Map<String, AttendanceStatus> attendanceMap = {};
  Map<String, String> notesMap = {};
  Map<String, TextEditingController> textControllers = {};
  Map<String, bool> isEditingNotes = {};
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'number';
  bool isGridView = false; // false = list view, true = grid view

  // Separate notes and controllers for each status
  Map<String, String> excusedNotesMap = {};
  Map<String, String> lateNotesMap = {};
  Map<String, String> absentNotesMap = {};
  Map<String, TextEditingController> excusedTextControllers = {};
  Map<String, TextEditingController> lateTextControllers = {};
  Map<String, TextEditingController> absentTextControllers = {};
  Map<String, bool> excusedEditingNotes = {};
  Map<String, bool> lateEditingNotes = {};
  Map<String, bool> absentEditingNotes = {};

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in textControllers.values) {
      controller.dispose();
    }
    for (final controller in excusedTextControllers.values) {
      controller.dispose();
    }
    for (final controller in lateTextControllers.values) {
      controller.dispose();
    }
    for (final controller in absentTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final loadedStudents = await DataService.getStudentsByClass(widget.classModel.id);
      final todayRecords = await DataService.getAttendanceForDate(selectedDate);
      
      // Initialize attendance map
      final Map<String, AttendanceStatus> todayAttendance = {};
      final Map<String, String> todayNotes = {};
      final Map<String, String> todayExcusedNotes = {};
      final Map<String, String> todayLateNotes = {};
      final Map<String, String> todayAbsentNotes = {};
      
      for (final record in todayRecords) {
        todayAttendance[record.studentId] = record.status;
        if (record.notes != null) {
          todayNotes[record.studentId] = record.notes!;
          switch (record.status) {
            case AttendanceStatus.excused:
              todayExcusedNotes[record.studentId] = record.notes!;
              break;
            case AttendanceStatus.late:
              todayLateNotes[record.studentId] = record.notes!;
              break;
            case AttendanceStatus.absent:
              todayAbsentNotes[record.studentId] = record.notes!;
              break;
            default:
              break;
          }
        }
      }

      setState(() {
        students = loadedStudents;
        attendanceMap = todayAttendance;
        notesMap = todayNotes;
        excusedNotesMap = todayExcusedNotes;
        lateNotesMap = todayLateNotes;
        absentNotesMap = todayAbsentNotes;
        
        // Initialize text controllers and editing states
        for (final student in loadedStudents) {
          if (!textControllers.containsKey(student.id)) {
            textControllers[student.id] = TextEditingController(
              text: todayNotes[student.id] ?? '',
            );
          }
          if (!excusedTextControllers.containsKey(student.id)) {
            excusedTextControllers[student.id] = TextEditingController(
              text: todayExcusedNotes[student.id] ?? '',
            );
          }
          if (!lateTextControllers.containsKey(student.id)) {
            lateTextControllers[student.id] = TextEditingController(
              text: todayLateNotes[student.id] ?? '',
            );
          }
          if (!absentTextControllers.containsKey(student.id)) {
            absentTextControllers[student.id] = TextEditingController(
              text: todayAbsentNotes[student.id] ?? '',
            );
          }
          isEditingNotes[student.id] = !(todayNotes[student.id]?.isNotEmpty ?? false);
          excusedEditingNotes[student.id] = !(todayExcusedNotes[student.id]?.isNotEmpty ?? false);
          lateEditingNotes[student.id] = !(todayLateNotes[student.id]?.isNotEmpty ?? false);
          absentEditingNotes[student.id] = !(todayAbsentNotes[student.id]?.isNotEmpty ?? false);
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final oneDayAhead = now.add(const Duration(days: 1));
    
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(selectedDate),
      firstDate: Jalali.fromDateTime(oneYearAgo),
      lastDate: Jalali.fromDateTime(oneDayAhead),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        selectedDate = date.toDateTime();
      });
      _loadStudents();
    }
  }

  List<Student> _getFilteredStudents() {
    var filtered = students.where((student) {
      final fullName = student.fullName.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return fullName.contains(query);
    }).toList();

    // Sort students
    filtered.sort((a, b) {
      switch (sortBy) {
        case 'name':
          return a.lastName.compareTo(b.lastName);
        case 'firstName':
          return a.firstName.compareTo(b.firstName);
        case 'number':
        default:
          return int.parse(a.studentNumber).compareTo(int.parse(b.studentNumber));
      }
    });

    return filtered;
  }

  String _getPersianDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final monthNames = [
      '', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    final day = _toPersianNumbers(jalali.day.toString());
    final month = monthNames[jalali.month];
    return '$day $month';
  }

  String _toPersianNumbers(String text) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    for (int i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], persian[i]);
    }
    return text;
  }

  Future<void> _addStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(classId: widget.classModel.id),
      ),
    );
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _editStudent(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStudentScreen(student: student),
      ),
    );
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _deleteStudent(Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف دانش‌آموز'),
        content: Text('آیا از حذف ${student.fullName} اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Store student data for potential undo
        final deletedStudent = student;
        
        // Delete the student
        await DataService.deleteStudent(student.id);
        _loadStudents();
        
        // Show simple deletion message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'دانش‌آموز ${deletedStudent.fullName} حذف شد',
              style: const TextStyle(
                fontFamily: 'BYekan',
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // Handle error silently
      }
    }
  }


  Future<void> _markAttendance(String studentId, AttendanceStatus status) async {
    try {
      await DataService.markAttendance(studentId, selectedDate, status);
      setState(() {
        attendanceMap[studentId] = status;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  bool _isStatusSelected(String studentId, AttendanceStatus status) {
    return attendanceMap[studentId] == status;
  }

  Widget _buildAttendanceButton(String studentId, AttendanceStatus status, String label, Color color, IconData icon) {
    final isSelected = _isStatusSelected(studentId, status);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: GestureDetector(
          onTap: () => _markAttendance(studentId, status),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: isSelected ? null : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[200]!,
                width: 1.5,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BYekan',
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final isPresent = _isStatusSelected(student.id, AttendanceStatus.present);
    final isAbsent = _isStatusSelected(student.id, AttendanceStatus.absent);
    final isExcused = _isStatusSelected(student.id, AttendanceStatus.excused);
    final isLate = _isStatusSelected(student.id, AttendanceStatus.late);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isPresent
                          ? [Colors.green[400]!, Colors.green[600]!]
                          : isAbsent
                              ? [Colors.red[400]!, Colors.red[600]!]
                              : isExcused
                                  ? [Colors.blue[400]!, Colors.blue[600]!]
                                  : isLate
                                      ? [Colors.orange[400]!, Colors.orange[600]!]
                                      : [Colors.grey[400]!, Colors.grey[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isPresent
                            ? Colors.green
                            : isAbsent
                                ? Colors.red
                                : isExcused
                                    ? Colors.blue
                                    : isLate
                                        ? Colors.orange
                                        : Colors.grey).withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      student.studentNumber,
                      style: const TextStyle(
                        fontFamily: 'BYekan',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        style: const TextStyle(
                          fontFamily: 'BYekan',
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Color(0xFF2D3748),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await _editStudent(student);
                    } else if (value == 'delete') {
                      await _deleteStudent(student);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('ویرایش'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAttendanceButton(
                  student.id,
                  AttendanceStatus.present,
                  'حاضر',
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildAttendanceButton(
                  student.id,
                  AttendanceStatus.absent,
                  'غایب',
                  Colors.red,
                  Icons.cancel,
                ),
                _buildAttendanceButton(
                  student.id,
                  AttendanceStatus.excused,
                  'موجه',
                  Colors.blue,
                  Icons.info,
                ),
                _buildAttendanceButton(
                  student.id,
                  AttendanceStatus.late,
                  'تأخیر',
                  Colors.orange,
                  Icons.schedule,
                ),
              ],
            ),
            // Note section for excused, late, or absent
            if (isExcused || isLate || isAbsent) ...[
              const SizedBox(height: 12),
              if (_getEditingState(student) ?? true) ...[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextField(
                    controller: _getTextController(student),
                    maxLines: 1,
                    maxLength: isLate ? 5 : 20,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isExcused
                          ? Colors.blue[700]
                          : isLate
                              ? Colors.orange[700]
                              : Colors.red[700],
                    ),
                    decoration: InputDecoration(
                      hintText: isExcused
                          ? 'دلیل موجه بودن را وارد نمایید'
                          : isLate
                              ? 'ساعت ورود'
                              : 'دلیل غیبت',
                      hintStyle: TextStyle(
                        color: isExcused
                            ? Colors.blue[400]
                            : isLate
                                ? Colors.orange[400]
                                : Colors.red[400],
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isExcused
                              ? Colors.blue[300]!
                              : isLate
                                  ? Colors.orange[300]!
                                  : Colors.red[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isExcused
                              ? Colors.blue[500]!
                              : isLate
                                  ? Colors.orange[500]!
                                  : Colors.red[500]!,
                        ),
                      ),
                      counterText: isLate
                          ? '${_getTextController(student)?.text.length ?? 0}/5'
                          : '${_getTextController(student)?.text.length ?? 0}/20',
                    ),
                    onChanged: (value) {
                      if (isLate) {
                        String formattedValue = _formatTimeInput(value);
                        _getTextController(student)?.text = formattedValue;
                        _getTextController(student)?.selection = TextSelection.fromPosition(
                          TextPosition(offset: formattedValue.length),
                        );
                        setState(() {
                          _updateNotesMap(student, formattedValue);
                        });
                      } else {
                        setState(() {
                          _updateNotesMap(student, value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveNotes(student),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExcused
                              ? Colors.blue[600]
                              : isLate
                                  ? Colors.orange[600]
                                  : Colors.red[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('ذخیره'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _saveWithoutNote(student),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('یادداشتی ندارم'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isExcused
                        ? Colors.blue[50]
                        : isLate
                            ? Colors.orange[50]
                            : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isExcused
                          ? Colors.blue[200]!
                          : isLate
                              ? Colors.orange[200]!
                              : Colors.red[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getSavedNote(student) ?? '',
                          style: TextStyle(
                            color: isExcused
                                ? Colors.blue[700]
                                : isLate
                                    ? Colors.orange[700]
                                    : Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteNote(student),
                        icon: Icon(
                          Icons.delete,
                          color: isExcused
                              ? Colors.blue[400]
                              : isLate
                                  ? Colors.orange[400]
                                  : Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGridStudentCard(Student student) {
    final isPresent = _isStatusSelected(student.id, AttendanceStatus.present);
    final isAbsent = _isStatusSelected(student.id, AttendanceStatus.absent);
    final isExcused = _isStatusSelected(student.id, AttendanceStatus.excused);
    final isLate = _isStatusSelected(student.id, AttendanceStatus.late);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Student info section
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isPresent
                              ? [Colors.green[400]!, Colors.green[600]!]
                              : isAbsent
                                  ? [Colors.red[400]!, Colors.red[600]!]
                                  : isExcused
                                      ? [Colors.blue[400]!, Colors.blue[600]!]
                                      : isLate
                                          ? [Colors.orange[400]!, Colors.orange[600]!]
                                          : [Colors.grey[400]!, Colors.grey[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isPresent
                                ? Colors.green
                                : isAbsent
                                    ? Colors.red
                                    : isExcused
                                        ? Colors.blue
                                        : isLate
                                            ? Colors.orange
                                            : Colors.grey).withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.transparent,
                        child: Text(
                          student.studentNumber,
                          style: const TextStyle(
                            fontFamily: 'BYekan',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 14),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editStudent(student);
                        } else if (value == 'delete') {
                          await _deleteStudent(student);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue, size: 14),
                              SizedBox(width: 6),
                              Text('ویرایش', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('حذف', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontFamily: 'BYekan',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            
            // Attendance buttons section
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _markAttendance(student.id, AttendanceStatus.present),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isPresent ? Colors.green : Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isPresent ? Colors.green : Colors.green[300]!,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            color: isPresent ? Colors.white : Colors.green[700],
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _markAttendance(student.id, AttendanceStatus.absent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isAbsent ? Colors.red : Colors.red[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isAbsent ? Colors.red : Colors.red[300]!,
                            ),
                          ),
                          child: Icon(
                            Icons.close,
                            color: isAbsent ? Colors.white : Colors.red[700],
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _markAttendance(student.id, AttendanceStatus.excused),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isExcused ? Colors.blue : Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isExcused ? Colors.blue : Colors.blue[300]!,
                            ),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: isExcused ? Colors.white : Colors.blue[700],
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _markAttendance(student.id, AttendanceStatus.late),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isLate ? Colors.orange : Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isLate ? Colors.orange : Colors.orange[300]!,
                            ),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: isLate ? Colors.white : Colors.orange[700],
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for note management
  TextEditingController? _getTextController(Student student) {
    final status = attendanceMap[student.id];
    if (status == null) return textControllers[student.id];
    switch (status) {
      case AttendanceStatus.excused:
        return excusedTextControllers[student.id];
      case AttendanceStatus.late:
        return lateTextControllers[student.id];
      case AttendanceStatus.absent:
        return absentTextControllers[student.id];
      default:
        return textControllers[student.id];
    }
  }

  bool? _getEditingState(Student student) {
    final status = attendanceMap[student.id];
    if (status == null) return true;
    switch (status) {
      case AttendanceStatus.excused:
        return excusedEditingNotes[student.id] ?? true;
      case AttendanceStatus.late:
        return lateEditingNotes[student.id] ?? true;
      case AttendanceStatus.absent:
        return absentEditingNotes[student.id] ?? true;
      default:
        return true;
    }
  }

  String? _getSavedNote(Student student) {
    final status = attendanceMap[student.id];
    if (status == null) return notesMap[student.id];
    switch (status) {
      case AttendanceStatus.excused:
        return excusedNotesMap[student.id];
      case AttendanceStatus.late:
        return lateNotesMap[student.id];
      case AttendanceStatus.absent:
        return absentNotesMap[student.id];
      default:
        return notesMap[student.id];
    }
  }

  void _updateNotesMap(Student student, String value) {
    final status = attendanceMap[student.id];
    if (status == null) return;
    switch (status) {
      case AttendanceStatus.excused:
        excusedNotesMap[student.id] = value;
        break;
      case AttendanceStatus.late:
        lateNotesMap[student.id] = value;
        break;
      case AttendanceStatus.absent:
        absentNotesMap[student.id] = value;
        break;
      default:
        break;
    }
    notesMap[student.id] = value;
  }

  void _setEditingState(Student student, bool isEditing) {
    final status = attendanceMap[student.id];
    if (status == null) return;
    switch (status) {
      case AttendanceStatus.excused:
        excusedEditingNotes[student.id] = isEditing;
        break;
      case AttendanceStatus.late:
        lateEditingNotes[student.id] = isEditing;
        break;
      case AttendanceStatus.absent:
        absentEditingNotes[student.id] = isEditing;
        break;
      default:
        break;
    }
    isEditingNotes[student.id] = isEditing;
  }

  Future<void> _saveNotes(Student student) async {
    try {
      final notes = _getTextController(student)?.text ?? '';
      final status = attendanceMap[student.id] ?? AttendanceStatus.absent;
      await DataService.markAttendance(
        student.id,
        selectedDate,
        status,
        notes: notes,
      );
      setState(() {
        _updateNotesMap(student, notes);
        _setEditingState(student, false);
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _deleteNote(Student student) async {
    try {
      final status = attendanceMap[student.id] ?? AttendanceStatus.absent;
      await DataService.markAttendance(
        student.id,
        selectedDate,
        status,
        notes: null,
      );
      setState(() {
        _updateNotesMap(student, '');
        _setEditingState(student, true);
        _getTextController(student)?.clear();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveWithoutNote(Student student) async {
    try {
      final status = attendanceMap[student.id];
      if (status == null) return;
      await DataService.markAttendance(
        student.id,
        selectedDate,
        status,
        notes: 'یادداشتی ندارم',
      );
      setState(() {
        _updateNotesMap(student, 'یادداشتی ندارم');
        _setEditingState(student, false);
        _getTextController(student)?.clear();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  String _formatTimeInput(String value) {
    // Remove non-numeric characters
    String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length <= 2) {
      return cleaned;
    } else if (cleaned.length <= 4) {
      return '${cleaned.substring(0, 2)}:${cleaned.substring(2)}';
    } else {
      return '${cleaned.substring(0, 2)}:${cleaned.substring(2, 4)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _getFilteredStudents();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حضور غیاب دانش‌آموزان'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            onPressed: _addStudent,
            icon: const Icon(Icons.person_add),
            tooltip: 'اضافه کردن دانش‌آموز',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            tooltip: 'گزینه‌های بیشتر',
            onSelected: (String value) async {
              switch (value) {
                case 'report':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceHistoryScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'report',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text('گزارش‌گیری'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Class name and date
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Class name
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.class_, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.classModel.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      if (widget.classModel.description.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '- ${widget.classModel.description}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () {
                        final now = DateTime.now();
                        final oneDayAhead = now.add(const Duration(days: 1));
                        final nextDay = selectedDate.add(const Duration(days: 1));
                        
                        // Check if next day is within limits
                        if (nextDay.isBefore(oneDayAhead) || nextDay.isAtSameMomentAs(oneDayAhead)) {
                          setState(() {
                            selectedDate = nextDay;
                          });
                          _loadStudents();
                        }
                      },
                      icon: Icon(Icons.chevron_left, color: Colors.blue[700]),
                    ),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Text(
                        _getPersianDate(selectedDate),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final now = DateTime.now();
                        final oneYearAgo = now.subtract(const Duration(days: 365));
                        final previousDay = selectedDate.subtract(const Duration(days: 1));
                        
                        // Check if previous day is within limits
                        if (previousDay.isAfter(oneYearAgo) || previousDay.isAtSameMomentAs(oneYearAgo)) {
                          setState(() {
                            selectedDate = previousDay;
                          });
                          _loadStudents();
                        }
                      },
                      icon: Icon(Icons.chevron_right, color: Colors.blue[700]),
                    ),
                  ],
                ),
                if (selectedDate.day != DateTime.now().day ||
                    selectedDate.month != DateTime.now().month ||
                    selectedDate.year != DateTime.now().year)
                  const SizedBox(height: 8),
                if (selectedDate.day != DateTime.now().day ||
                    selectedDate.month != DateTime.now().month ||
                    selectedDate.year != DateTime.now().year)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedDate = DateTime.now();
                      });
                      _loadStudents();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('برو به امروز' ,),
                  ),
              ],
            ),
          ),
          // Search and sort
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'جستجو در دانش‌آموزان...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<String>(
                    value: sortBy,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    hint: Icon(
                      sortBy == 'number' ? Icons.numbers :
                      sortBy == 'name' ? Icons.sort_by_alpha : Icons.person,
                      color: Colors.grey[700], 
                      size: 20
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: const [
                      DropdownMenuItem(
                        value: 'number',
                        child: Center(
                          child: Text('شماره ترتیب'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Center(
                          child: Text('الفبا (نام خانوادگی)'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'firstName',
                        child: Center(
                          child: Text('الفبا (نام)'),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        sortBy = value ?? 'number';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // View mode toggle button
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isGridView = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: !isGridView ? Colors.blue : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                          child: Icon(
                            Icons.list,
                            color: !isGridView ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isGridView = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isGridView ? Colors.blue : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4),
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view,
                            color: isGridView ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Students list
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'هیچ دانش‌آموزی در این کلاس وجود ندارد',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'برای شروع، دانش‌آموز جدیدی اضافه کنید',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          return _buildGridStudentCard(filteredStudents[index]);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          return _buildStudentCard(filteredStudents[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
