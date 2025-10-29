import 'dart:async';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../models/class_model.dart';
import '../services/data_service.dart';
import 'add_student_screen.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'edit_student_screen.dart';
import 'class_management_screen.dart';
import 'grades_screen.dart';
import 'todo_screen.dart';
import '../services/theme_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> students = [];
  List<ClassModel> classes = [];
  ClassModel? selectedClass;
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  Map<String, AttendanceStatus> attendanceMap = {};
  Map<String, String> notesMap = {};
  Map<String, TextEditingController> textControllers = {};
  Map<String, bool> isEditingNotes = {};
  // Separate note maps for each status
  Map<String, String> excusedNotesMap = {};
  Map<String, String> lateNotesMap = {};
  Map<String, String> absentNotesMap = {};
  Map<String, TextEditingController> excusedTextControllers = {};
  Map<String, TextEditingController> lateTextControllers = {};
  Map<String, TextEditingController> absentTextControllers = {};
  Map<String, bool> excusedEditingNotes = {};
  Map<String, bool> lateEditingNotes = {};
  Map<String, bool> absentEditingNotes = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'number'; // 'number', 'name', or 'firstName'
  bool isGridView = false; // false = list view, true = grid view
  final ThemeService _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    setState(() {});
  }

  bool get isDarkMode => _themeService.isDarkMode;

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    // Dispose all text controllers
    for (final controller in textControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => isLoading = true);
    
    // Load classes first
    final loadedClasses = await DataService.getClasses();
    
    // Load students based on selected class
    List<Student> loadedStudents;
    if (selectedClass != null) {
      loadedStudents = await DataService.getStudentsByClass(selectedClass!.id);
    } else {
      loadedStudents = await DataService.getStudents();
    }
    
    // Load attendance data for today
    final todayRecords = await DataService.getAttendanceForDate(selectedDate);
    final Map<String, AttendanceStatus> todayAttendance = {};
    final Map<String, String> todayNotes = {};
    final Map<String, String> todayExcusedNotes = {};
    final Map<String, String> todayLateNotes = {};
    final Map<String, String> todayAbsentNotes = {};
    
    for (final record in todayRecords) {
      todayAttendance[record.studentId] = record.status;
      if (record.notes != null) {
        todayNotes[record.studentId] = record.notes!;
        // Separate notes by status
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
      classes = loadedClasses;
      // Sort students by student number
      students = loadedStudents..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
      attendanceMap = todayAttendance;
      notesMap = todayNotes;
      excusedNotesMap = todayExcusedNotes;
      lateNotesMap = todayLateNotes;
      absentNotesMap = todayAbsentNotes;
      
      // Initialize text controllers for each student
      for (final student in loadedStudents) {
        if (!textControllers.containsKey(student.id)) {
          textControllers[student.id] = TextEditingController(
            text: todayNotes[student.id] ?? '',
          );
        }
        // Initialize separate controllers for each status
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
        
        // Initialize editing state - if there's a saved note, don't show editing mode
        isEditingNotes[student.id] = !(todayNotes[student.id]?.isNotEmpty ?? false);
        excusedEditingNotes[student.id] = !(todayExcusedNotes[student.id]?.isNotEmpty ?? false);
        lateEditingNotes[student.id] = !(todayLateNotes[student.id]?.isNotEmpty ?? false);
        absentEditingNotes[student.id] = !(todayAbsentNotes[student.id]?.isNotEmpty ?? false);
      }
      
      isLoading = false;
    });
  }

  Future<void> _selectClass(ClassModel? classModel) async {
    setState(() {
      selectedClass = classModel;
    });
    await _loadStudents();
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
        final isDark = isDarkMode;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: isDark
                  ? ColorScheme.dark(
                      primary: Colors.blue[400]!,
                      onPrimary: Colors.white,
                      surface: Colors.grey[800]!,
                      onSurface: Colors.white,
                    )
                  : ColorScheme.light(
                      primary: Colors.blue[700]!,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
            ),
            child: child!,
          ),
        );
      },
    );
    
    if (date != null) {
      setState(() {
        selectedDate = date.toDateTime();
      });
      _loadStudents(); // Reload students and attendance data for the new date
    }
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
        child: Column(
          children: [
            ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        leading: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
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
              style:  TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
              student.fullName,
          style: TextStyle(
            fontFamily: 'BYekan',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: isDarkMode ? Colors.white : const Color(0xFF2D3748),
            letterSpacing: 0.2,
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          iconColor: isDarkMode ? Colors.white : Colors.black,
          onSelected: (value) async {
            if (value == 'edit') {
                  await _editStudent(student);
            } else if (value == 'delete') {
              await _deleteStudent(student);
            }
          },
          itemBuilder: (context) => [
             PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('ویرایش' ,  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.red)),
                ],
              ),
                ),
              ],
            ),
          ),
          // Attendance buttons - four buttons in one row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceButton(student, 'تأخیر', Colors.orange, Icons.schedule),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceButton(student, 'موجه', Colors.blue, Icons.info),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceButton(student, 'غایب', Colors.red, Icons.cancel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAttendanceButton(student, 'حاضر', Colors.green, Icons.check_circle),
                    ),
                  ],
                ),
                // Notes section for excused, late, and absent status
                if (attendanceMap[student.id] == AttendanceStatus.excused ||
                    attendanceMap[student.id] == AttendanceStatus.late ||
                    attendanceMap[student.id] == AttendanceStatus.absent) ...[
                  const SizedBox(height: 12),
                  // Show editing mode if no saved note or user wants to edit
                  if (_getEditingState(student) ?? true) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: attendanceMap[student.id] == AttendanceStatus.late
                            ?  isDarkMode ?Color(0xF04E3A23):Colors.orange[50]
                            : attendanceMap[student.id] == AttendanceStatus.absent
                                ? isDarkMode ?Color(0xF04E2323):Colors.red[50]
                                : isDarkMode ?Color(0xF023344E):Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: attendanceMap[student.id] == AttendanceStatus.late
                              ? isDarkMode ?Color(0xF03C2F1E):Colors.orange[200]!
                              : attendanceMap[student.id] == AttendanceStatus.absent
                                  ? isDarkMode ?Color(0xF0421F1F):Colors.red[200]!
                                  : isDarkMode ?Color(0xF0212D42):Colors.blue[200]!,
                        ),
                      ),
                      child: Column(
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextField(
                              controller: _getTextController(student),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              maxLength: attendanceMap[student.id] == AttendanceStatus.late ? 5 : 20,
                              keyboardType: attendanceMap[student.id] == AttendanceStatus.late
                                  ? TextInputType.number
                                  : TextInputType.text,
                              style: TextStyle( // 👈 رنگ متن وارد شده
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 20,
                              ),
                              decoration: InputDecoration(
                                labelText: attendanceMap[student.id] == AttendanceStatus.excused
                                    ? 'دلیل موجه بودن را وارد نمایید'
                                    : attendanceMap[student.id] == AttendanceStatus.late
                                    ? 'ساعت ورود را وارد نمایید'
                                    : 'دلیل غیبت را وارد نمایید',
                                hintText: attendanceMap[student.id] == AttendanceStatus.excused
                                    ? 'دلیل موجه بودن...'
                                    : attendanceMap[student.id] == AttendanceStatus.late
                                    ? '8:30'
                                    : 'دلیل غیبت...',
                                border: InputBorder.none,
                                counterText: attendanceMap[student.id] == AttendanceStatus.late
                                    ? '${_getTextController(student)?.text.length ?? 0}/5'
                                    : '${_getTextController(student)?.text.length ?? 0}/20',
                                counterStyle: TextStyle(
                                  fontSize: 10,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  fontWeight: FontWeight.normal,
                                ),
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (value) {
                                if (attendanceMap[student.id] == AttendanceStatus.late) {
                                  // Format time input (HH:MM)
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
                            )
                            ,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _saveNotes(student),
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text('ذخیره'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: attendanceMap[student.id] == AttendanceStatus.late
                                    ? Colors.orange[600]
                                    : attendanceMap[student.id] == AttendanceStatus.absent
                                        ? Colors.red[600]
                                        : Colors.blue[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          // Add "No Note" button below save button
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _saveWithoutNote(student),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('یادداشتی ندارم'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Show saved note with delete button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: attendanceMap[student.id] == AttendanceStatus.late
                            ? Colors.orange[50]
                            : attendanceMap[student.id] == AttendanceStatus.absent
                                ? Colors.red[50]
                                : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: attendanceMap[student.id] == AttendanceStatus.late
                              ? Colors.orange[200]!
                              : attendanceMap[student.id] == AttendanceStatus.absent
                                  ? Colors.red[200]!
                                  : Colors.blue[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            attendanceMap[student.id] == AttendanceStatus.excused
                                ? Icons.note
                                : attendanceMap[student.id] == AttendanceStatus.late
                                    ? Icons.schedule
                                    : Icons.cancel,
                            size: 16,
                            color: attendanceMap[student.id] == AttendanceStatus.late
                                ? Colors.orange[600]
                                : attendanceMap[student.id] == AttendanceStatus.absent
                                    ? Colors.red[600]
                                    : Colors.blue[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                _getSavedNote(student) ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: attendanceMap[student.id] == AttendanceStatus.late
                                      ? Colors.orange[700]
                                      : attendanceMap[student.id] == AttendanceStatus.absent
                                          ? Colors.red[700]
                                          : Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteNote(student),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Icon(
                                Icons.delete,
                                size: 16,
                                color: Colors.red[600],
                              ),
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
        ],
      ),
    );
  }

  Widget _buildGridStudentCard(Student student) {
    final isPresent = _isStatusSelected(student, 'حاضر');
    final isAbsent = _isStatusSelected(student, 'غایب');
    final isExcused = _isStatusSelected(student, 'موجه');
    final isLate = _isStatusSelected(student, 'تأخیر');

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
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
                          style:  TextStyle(
                            fontFamily: 'BYekan',
                            color: isDarkMode ? Colors.grey[800] : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      color:  isDarkMode ?Colors.grey[800]:Colors.white,
                      icon: Icon(Icons.more_vert, size: 14 , color:  isDarkMode ?Colors.white : Colors.black,),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editStudent(student);
                        } else if (value == 'delete') {
                          await _deleteStudent(student);
                        }
                      },
                      itemBuilder: (context) => [
                         PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue, size: 14),
                              SizedBox(width: 6),
                              Text('ویرایش', style: TextStyle(fontSize: 12 , color:  isDarkMode ?Colors.white:Colors.black)),
                            ],
                          ),
                        ),
                         PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 14),
                              SizedBox(width: 6),
                              Text('حذف', style: TextStyle(fontSize: 12 ,  color:  isDarkMode ?Colors.white:Colors.black)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                Text(
                  student.fullName,
                  style: TextStyle(
                    fontFamily: 'BYekan',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Attendance buttons section
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _markAttendance(student, 'حاضر', Colors.green),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isPresent ? LinearGradient(
                              colors: [Colors.green[400]!, Colors.green[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : null,
                            color: isPresent ? null : (isDarkMode ? Colors.green[900] : Colors.green[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPresent ? Colors.green : Colors.green[200]!,
                              width: 1.5,
                            ),
                            boxShadow: isPresent ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
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
                        onTap: () => _markAttendance(student, 'غایب', Colors.red),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isAbsent ? LinearGradient(
                              colors: [Colors.red[400]!, Colors.red[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : null,
                            color: isAbsent ? null : (isDarkMode ? Colors.red[900] : Colors.red[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAbsent ? Colors.red : Colors.red[200]!,
                              width: 1.5,
                            ),
                            boxShadow: isAbsent ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
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
                        onTap: () => _markAttendance(student, 'موجه', Colors.blue),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isExcused ? LinearGradient(
                              colors: [Colors.blue[400]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : null,
                            color: isExcused ? null : (isDarkMode ? Colors.blue[900] : Colors.blue[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isExcused ? Colors.blue : Colors.blue[200]!,
                              width: 1.5,
                            ),
                            boxShadow: isExcused ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
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
                        onTap: () => _markAttendance(student, 'تأخیر', Colors.orange),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            gradient: isLate ? LinearGradient(
                              colors: [Colors.orange[400]!, Colors.orange[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ) : null,
                            color: isLate ? null : (isDarkMode ? Colors.orange[900] : Colors.orange[50]),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isLate ? Colors.orange : Colors.orange[200]!,
                              width: 1.5,
                            ),
                            boxShadow: isLate ? [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                spreadRadius: 0,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
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

  Widget _buildAttendanceButton(Student student, String statusText, Color color, IconData icon) {
    final isSelected = _isStatusSelected(student, statusText);
    
    return GestureDetector(
      onTap: () => _markAttendance(student, statusText, color),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: isSelected ? null : (isDarkMode ? Colors.grey[700] : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDarkMode ? Colors.grey[600]! : Colors.grey[200]!),
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
              color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[300] : Colors.grey[600]),
              size: 16,
            ),
            const SizedBox(height: 2),
            Text(
              statusText,
              style: TextStyle(
                fontFamily: 'BYekan',
                color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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

  bool _isStatusSelected(Student student, String statusText) {
    final currentStatus = attendanceMap[student.id];
    if (currentStatus == null) return false;
    
    switch (statusText) {
      case 'تأخیر':
        return currentStatus == AttendanceStatus.late;
      case 'موجه':
        return currentStatus == AttendanceStatus.excused;
      case 'غایب':
        return currentStatus == AttendanceStatus.absent;
      case 'حاضر':
        return currentStatus == AttendanceStatus.present;
      default:
        return false;
    }
  }

  Future<void> _markAttendance(Student student, String statusText, Color color) async {
    AttendanceStatus status;
    switch (statusText) {
      case 'تأخیر':
        status = AttendanceStatus.late;
        break;
      case 'موجه':
        status = AttendanceStatus.excused;
        break;
      case 'غایب':
        status = AttendanceStatus.absent;
        break;
      case 'حاضر':
        status = AttendanceStatus.present;
        break;
      default:
        return;
    }

    try {
      final notes = (status == AttendanceStatus.excused || status == AttendanceStatus.late || status == AttendanceStatus.absent)
          ? textControllers[student.id]?.text
          : null;

      await DataService.markAttendance(
        student.id,
        selectedDate,
        status,
        notes: notes,
      );

      setState(() {
        attendanceMap[student.id] = status;
        // If status changes, reset editing mode for notes
        if (status != AttendanceStatus.excused && status != AttendanceStatus.late && status != AttendanceStatus.absent) {
          isEditingNotes[student.id] = true;
          textControllers[student.id]?.clear();
          notesMap[student.id] = '';
        } else {
          // If it's an editable status, keep editing mode if no note, or switch to display if note exists
          isEditingNotes[student.id] = !(notesMap[student.id]?.isNotEmpty ?? false);
        }
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
        notes: 'یادداشتی ندارم', // Save "No note" text
      );

      setState(() {
        _updateNotesMap(student, 'یادداشتی ندارم');
        _setEditingState(student, false); // Hide TextField
        _getTextController(student)?.clear();
      });
    } catch (e) {
      // Handle error silently
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
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('حذف دانش‌آموز', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: Text('آیا مطمئن هستید که می‌خواهید ${student.fullName} را حذف کنید؟', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
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
              style:  TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        // Handle error silently
      }
    }
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
        _setEditingState(student, false); // Switch to display mode
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
        notes: null, // Remove the note
      );

      setState(() {
        _updateNotesMap(student, '');
        _setEditingState(student, true); // Switch back to editing mode
        _getTextController(student)?.clear();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  String _formatTimeInput(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) return '';

    // Limit to 4 digits (HHMM)
    if (digitsOnly.length > 4) {
      digitsOnly = digitsOnly.substring(0, 4);
    }

    // Format as HH:MM
    if (digitsOnly.length <= 2) {
      return digitsOnly;
    } else if (digitsOnly.length == 3) {
      return '${digitsOnly.substring(0, 1)}:${digitsOnly.substring(1)}';
    } else {
      return '${digitsOnly.substring(0, 2)}:${digitsOnly.substring(2)}';
    }
  }

  bool _canSaveAttendance() {
    // Check if all students have an attendance status selected
    for (final student in students) {
      if (!attendanceMap.containsKey(student.id)) {
        return false;
      }
    }
    return students.isNotEmpty;
  }

  void _resetAllAttendance() {
      setState(() {
      // Clear all attendance statuses
      attendanceMap.clear();
      notesMap.clear();

      // Clear all text controllers
      for (final controller in textControllers.values) {
        controller.clear();
      }

      // Reset editing state for all students
      for (final student in students) {
        isEditingNotes[student.id] = true;
      }
    });
  }

  Future<void> _deleteAllStudents() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('تأیید حذف', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: Text('آیا مطمئن هستید که می‌خواهید تمام دانش‌آموزان را حذف کنید؟\nاین عمل قابل بازگشت نیست.', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ),
    );

    if (confirmed == true) {
      try {
        // Store all students data for potential undo
        final deletedStudents = List<Student>.from(students);

        // Delete all students
        await DataService.deleteAllStudents();
        setState(() {
          students.clear();
          attendanceMap.clear();
          notesMap.clear();
          for (final controller in textControllers.values) {
            controller.dispose();
          }
          textControllers.clear();
          isEditingNotes.clear();
        });

        // Show simple deletion message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمام دانش‌آموزان حذف شدند (${deletedStudents.length} نفر)',
              style:  TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _loadClasses() async {
    final loadedClasses = await DataService.getClasses();
    setState(() {
      classes = loadedClasses;
    });
  }

  Future<void> _showAddClassDialog() async {
    final TextEditingController classNameController = TextEditingController();
    
    final result = await showDialog<bool>(

      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('اضافه کردن کلاس جدید', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: TextStyle(color:  isDarkMode ?Colors.white:Colors.black),
              controller: classNameController,
              decoration:  InputDecoration(
                labelText: 'نام کلاس',
                labelStyle:  TextStyle(color:  isDarkMode ?Colors.white54:Colors.black),
                hintText: 'نام کلاس را وارد کنید',
                hintStyle: TextStyle(color:  isDarkMode ?Colors.white70:Colors.black),
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              if (classNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('اضافه کردن'),
          ),
        ],
      ),
    ),
    );

    if (result == true && classNameController.text.trim().isNotEmpty) {
      final newClass = ClassModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: classNameController.text.trim(),
        description: '',
        createdAt: DateTime.now(),
      );
      
      await DataService.addClass(newClass);
      await _loadClasses();
      
      // Select the newly created class
      setState(() {
        selectedClass = newClass;
      });
      await _loadStudents();
    }
  }

  Future<void> _showClassContextMenu(ClassModel classModel) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        color:   isDarkMode ?Colors.grey[900]:Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'گزینه‌های کلاس "${classModel.name}"',
              style:  TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                  color:  isDarkMode ?Colors.white:Colors.black
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: Text('ویرایش کلاس', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context, 'edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('حذف کلاس', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
              onTap: () {
                Navigator.pop(context, 'delete');
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (result == 'edit') {
      await _editClass(classModel);
    } else if (result == 'delete') {
      await _deleteClass(classModel);
    }
  }

  Future<void> _editClass(ClassModel classModel) async {
    final TextEditingController classNameController = TextEditingController(text: classModel.name);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('ویرایش کلاس', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: classNameController,
              decoration: const InputDecoration(
                labelText: 'نام کلاس',
                hintText: 'نام کلاس را وارد کنید',
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              if (classNameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ),
    );

    if (result == true && classNameController.text.trim().isNotEmpty) {
      final updatedClass = classModel.copyWith(
        name: classNameController.text.trim(),
      );
      
      await DataService.updateClass(updatedClass);
      await _loadClasses();
      
      // Update selected class if it's the one being edited
      if (selectedClass?.id == classModel.id) {
        setState(() {
          selectedClass = updatedClass;
        });
      }
    }
  }

  Future<void> _deleteClass(ClassModel classModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('حذف کلاس', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: Text('آیا از حذف کلاس "${classModel.name}" اطمینان دارید؟\nتمام دانش‌آموزان این کلاس نیز حذف خواهند شد.', style:  TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
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
    ),
    );

    if (confirmed == true) {
      await DataService.deleteClass(classModel.id);
      await _loadClasses();
      
      // If the deleted class was selected, clear selection
      if (selectedClass?.id == classModel.id) {
        setState(() {
          selectedClass = null;
          students.clear();
          attendanceMap.clear();
          notesMap.clear();
        });
      }
    }
  }

  List<Student> _getFilteredStudents() {
    List<Student> filteredStudents;
    
    if (_searchQuery.isEmpty) {
      filteredStudents = students;
    } else {
      filteredStudents = students.where((student) {
        final fullName = student.fullName.toLowerCase();
        final searchQuery = _searchQuery.toLowerCase();
        return fullName.contains(searchQuery);
      }).toList();
    }
    
    // Sort students based on sortBy preference
    if (sortBy == 'name') {
      filteredStudents.sort((a, b) => a.lastName.compareTo(b.lastName));
    } else if (sortBy == 'firstName') {
      filteredStudents.sort((a, b) => a.firstName.compareTo(b.firstName));
    } else {
      filteredStudents.sort((a, b) => int.parse(a.studentNumber).compareTo(int.parse(b.studentNumber)));
    }
    
    return filteredStudents;
  }

  String _getPersianDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final persianMonths = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    
    // ترتیب: روز ماه
    final month = persianMonths[jalali.month - 1];
    final day = _toPersianNumbers(jalali.day.toString());
    
    return '$day $month';
  }

  String _toPersianNumbers(String text) {
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianNumbers = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    
    String result = text;
    for (int i = 0; i < englishNumbers.length; i++) {
      result = result.replaceAll(englishNumbers[i], persianNumbers[i]);
    }
    return result;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  Future<void> _showAboutDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 28),
              const SizedBox(width: 8),
              Text(
                'درباره',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 8),
                Text(
                  'این  اپلیکیشن امکان مدیریت کلاس، حضور و غیاب دانش‌آموزان، وارد کردن نمرات درسی و ... را  به معلمان عزیز می‌دهد.',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'ساخته شده توسط Parsa Banitaba',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blue[900] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final Uri url = Uri.parse('https://github.com/Sureiamdiamond');
                            if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('نمی‌توان لینک را باز کرد'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('خطا: ${e.toString()}'),
                                  backgroundColor: Colors.red[600],
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.code, size: 20),
                        label: const Text('GitHub'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final Uri url = Uri.parse('https://www.linkedin.com/in/parsabanitaba/?lipi=urn%3Ali%3Apage%3Aprofile_common_profile_index%3B29b7ecf2-b4bb-4020-ab7e-bacb9f645424');
                            if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('نمی‌توان لینک را باز کرد'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('خطا: ${e.toString()}'),
                                  backgroundColor: Colors.red[600],
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.business_center, size: 20),
                        label: const Text('LinkedIn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'بستن',
                style: TextStyle(
                  color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title:  Text(
          'حضور و غیاب دانش‌آموزان',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.white,
            fontSize: 20
          ),
        ),
        backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[700],
        elevation: 0,
        leading:  IconButton(
          icon: Icon(
            isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: isDarkMode ? Colors.white70: Colors.white,
          ),
          onPressed: () {
            _themeService.toggleTheme();
          },
          tooltip: isDarkMode ? 'حالت روشن' : 'حالت تاریک',
        ),
        actions: [
          // Theme toggle button

          // Add student button
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddStudentScreen(classId: selectedClass?.id),
                ),
              );
              if (result == true) {
                _loadStudents();
              }
            },
            icon:  Icon(Icons.person_add, color:  isDarkMode ? Colors.white70: Colors.white,),
            tooltip: 'اضافه کردن دانش‌آموز',
          ),
          // Menu button
          PopupMenuButton<String>(
            color:   isDarkMode ?Colors.grey[850]:Colors.white,
            icon:  Icon(Icons.more_vert,    color: isDarkMode ? Colors.white70: Colors.white,),
            tooltip: 'گزینه‌های بیشتر',
             onSelected: (String value) async {
               switch (value) {
                 case 'add_class':
                   await _showAddClassDialog();
                   break;
                 case 'manage_classes':
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const ClassManagementScreen(),
                     ),
                   );
                   break;
                 case 'report':
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const AttendanceHistoryScreen(),
                     ),
                   );
                   break;
                 case 'reset':
                   if (attendanceMap.isNotEmpty) {
                     _resetAllAttendance();
                   }
                   break;
                 case 'delete':
                   if (students.isNotEmpty) {
                     await _deleteAllStudents();
                   }
                   break;
                 case 'grades':
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const GradesScreen(),
                     ),
                   );
                   break;
                 case 'todo':
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => const TodoScreen(),
                     ),
                   );
                   break;
                 case 'about':
                   _showAboutDialog();
                   break;
               }
             },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'add_class',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.class_, color: Colors.green[700]),
                    const SizedBox(width: 8),
                     Text('ساخت کلاس' , style: TextStyle(color:  isDarkMode ?Colors.white70:Colors.black),),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'report',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                     Text('گزارش‌گیری' , style: TextStyle(color:  isDarkMode ?Colors.white70:Colors.black),),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'grades',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.grade, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                     Text('نمرات درس' , style: TextStyle(color:  isDarkMode ?Colors.white70:Colors.black),),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'todo',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.checklist, color: Colors.teal[700]),
                    const SizedBox(width: 8),
                     Text('فهرست کارها' , style: TextStyle(color:  isDarkMode ?Colors.white70:Colors.black),),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'reset',
                enabled: attendanceMap.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      color: attendanceMap.isNotEmpty ? Colors.orange[600] : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ریست وضعیت‌ها',
                      style: TextStyle(
                        color: attendanceMap.isNotEmpty ? isDarkMode ?Colors.white70: Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                enabled: students.isNotEmpty,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever,
                      color: students.isNotEmpty ? Colors.red[600] : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'حذف تمام دانش‌آموزان',
                      style: TextStyle(
                        color: students.isNotEmpty ? isDarkMode ?Colors.white70: Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'about',
                enabled: true,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text('درباره', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // Date display with navigation
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color:  isDarkMode ?Colors.grey[900] : Colors.blue[50],
                  child: Row(
                    children: [
                      // Next day button (moved to left)
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
                        icon: Icon(Icons.chevron_left, color: isDarkMode ? Colors.white:Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor:isDarkMode ?Colors.blue[900]: Colors.blue[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date display (clickable)
                      Expanded(
                        child: GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color:  isDarkMode ? Colors.blue[900]:  Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color:isDarkMode ?Colors.black45: Colors.blue[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, color:  isDarkMode ?Colors.white:Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  _getPersianDate(selectedDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:  isDarkMode ?Colors.white:Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: isDarkMode ?Colors.white:Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Previous day button (moved to right)
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
                        icon: Icon(Icons.chevron_right,  color: isDarkMode ? Colors.white:Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: isDarkMode ?Colors.blue[900]: Colors.blue[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Class selector
                if (classes.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(left: 16 , right: 16 , bottom: 5 , top: 5),
                    color:  isDarkMode ?Colors.grey[950] : Colors.grey[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'انتخاب کلاس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:  isDarkMode ?Colors.white: Colors.grey[700],
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                // All students option
                                GestureDetector(
                                  onTap: () => _selectClass(null),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedClass == null ? Colors.blue[700] :  isDarkMode ?Colors.grey[880] :Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selectedClass == null ? Colors.blue[700]! : Colors.grey[400]!,
                                      ),
                                    ),
                                    child: Text(
                                      'همه دانش‌آموزان',
                                      style: TextStyle(
                                        color: selectedClass == null ? Colors.white : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Class options - reversed order for RTL
                                ...classes.reversed.map((classModel) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: GestureDetector(
                                    onTap: () => _selectClass(classModel),
                                    onLongPress: () => _showClassContextMenu(classModel),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selectedClass?.id == classModel.id ? Colors.blue[700] :  isDarkMode ?Colors.grey[880]: Colors.grey[200],

                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selectedClass?.id == classModel.id ? Colors.blue[700]! : Colors.grey[400]!,
                                        ),
                                      ),
                                      child: Text(
                                        classModel.name,
                                        style: TextStyle(
                                          color: selectedClass?.id == classModel.id ? Colors.white : Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Go to today button (only show if not today)
                if (!_isToday(selectedDate))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime.now();
                        });
                        _loadStudents();
                      },
                      icon: const Icon(Icons.today, color: Colors.white),
                      label:  Text(
                        'برو به امروز',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                


                  // Search field and Sort options
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Row(
                      children: [




                        // View mode toggle button
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: isDarkMode ?Colors.white24 : Colors.grey),
                            borderRadius: BorderRadius.circular(6),
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
                                  height: 39,
                                  width: 36,

                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: !isGridView ? Colors.blue[800] : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      bottomLeft: Radius.circular(4),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.list,
                                    color: !isGridView ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
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
                                  height: 38,
                                  width: 35,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isGridView ? Colors.blue[800] : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(4),
                                      bottomRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.grid_view,
                                    color: isGridView ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          children: [
                            // Filter icon button
                            Container(
                              height: 41,
                              width: 80,
                              decoration: BoxDecoration(
                                color: isDarkMode ?Colors.grey[750] :  Colors.blue[50],
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color:  isDarkMode ?Colors.white24 : Colors.blue[700]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: isDarkMode ?Colors.grey[800] : Colors.white,
                                  value: sortBy,
                                  alignment: Alignment.topCenter,
                                  isExpanded: true,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      sortBy = newValue!;
                                    });
                                  },
                                  hint: Icon(
                                    sortBy == 'number' ? Icons.numbers :
                                    sortBy == 'name' ? Icons.sort_by_alpha : Icons.person,
                                    color:  isDarkMode ?Colors.grey[800] :  Colors.blue[700] ,
                                    size: 20
                                  ),
                                  icon: Icon(Icons.keyboard_arrow_down, color:  isDarkMode ?Colors.white60: Colors.blue[700]),
                                   items: <String>['number', 'name', 'firstName'].map<DropdownMenuItem<String>>((String value) {
                                     return DropdownMenuItem<String>(

                                       value: value,
                                       child: Center(
                                         child: Text(
                                           value == 'number' ? 'شماره' :
                                           value == 'name' ? 'فامیلی' : 'نام',
                                           style: TextStyle(
                                             color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                                             fontWeight: FontWeight.bold,
                                             fontSize: 13,
                                           ),
                                           textAlign: TextAlign.center,
                                         ),
                                       ),
                                     );
                                   }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        // Search field
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: SizedBox(
                              height: 42,
                              child:TextField(
                                style: TextStyle( // 👈 رنگ متن وارد شده
                                  color: isDarkMode ? Colors.white : Colors.black,
                                  fontSize: 15,
                                ),
                                controller: _searchController,
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'جستجو در نام دانش‌آموزان',
                                  hintStyle: TextStyle(
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: isDarkMode ? Colors.blue[400]! : Colors.blue[600]!,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                ),
                              ),

                            ),
                          ),
                        ),

                     
                        // Sort options
                       ],
                    ),
                  ),
                
                // Students list
                Expanded(
                  child: students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.school,
                                size: 64,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'هیچ دانش‌آموزی ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'برای شروع، دانش‌آموز جدید اضافه کنید',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : _getFilteredStudents().isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'هیچ دانش‌آموزی با این نام یافت نشد',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
                                  itemCount: _getFilteredStudents().length,
                                  itemBuilder: (context, index) {
                                    final student = _getFilteredStudents()[index];
                                    return _buildGridStudentCard(student);
                                  },
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: _getFilteredStudents().length,
                                  itemBuilder: (context, index) {
                                    final student = _getFilteredStudents()[index];
                                    return _buildStudentCard(student);
                                  },
                                ),
                ),
                
                // Take attendance button
                if (students.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _canSaveAttendance() ? () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AttendanceScreen(
                              students: students,
                              selectedDate: selectedDate,
                              isResultMode: true,
                            ),
                          ),
                        );
                        if (result == true) {
                          setState(() {});
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSaveAttendance() 
                            ? Colors.green[600] 
                            : Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.checklist, 
                            color: _canSaveAttendance() ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _canSaveAttendance() 
                                ? 'ثبت حضور و غیاب' 
                                : 'ابتدا وضعیت همه دانش‌آموزان را انتخاب کنید',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _canSaveAttendance() ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: null, // Disabled button
                      icon: const Icon(Icons.checklist, color: Colors.grey),
                      label:  Text(
                        'ابتدا دانش‌آموز اضافه کنید',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: 8)
              ],
            ),
    );
  }
}
