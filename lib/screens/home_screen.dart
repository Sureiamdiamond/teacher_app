import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/data_service.dart';
import 'add_student_screen.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'edit_student_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Student> students = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  Map<String, AttendanceStatus> attendanceMap = {};
  Map<String, String> notesMap = {};
  Map<String, TextEditingController> textControllers = {};
  Map<String, bool> isEditingNotes = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'number'; // 'number', 'name', or 'firstName'

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    // Dispose all text controllers
    for (final controller in textControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => isLoading = true);
    final loadedStudents = await DataService.getStudents();
    
    // Load attendance data for today
    final todayRecords = await DataService.getAttendanceForDate(selectedDate);
    final Map<String, AttendanceStatus> todayAttendance = {};
    final Map<String, String> todayNotes = {};
    for (final record in todayRecords) {
      todayAttendance[record.studentId] = record.status;
      if (record.notes != null) {
        todayNotes[record.studentId] = record.notes!;
      }
    }

    setState(() {
      // Sort students by student number
      students = loadedStudents..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
      attendanceMap = todayAttendance;
      notesMap = todayNotes;
      
      // Initialize text controllers for each student
      for (final student in loadedStudents) {
        if (!textControllers.containsKey(student.id)) {
          textControllers[student.id] = TextEditingController(
            text: todayNotes[student.id] ?? '',
          );
        }
        // Initialize editing state - if there's a saved note, don't show editing mode
        isEditingNotes[student.id] = !(todayNotes[student.id]?.isNotEmpty ?? false);
      }
      
      isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(selectedDate),
      firstDate: Jalali(1400),
      lastDate: Jalali(1450),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
                student.studentNumber,
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
                  fontSize: 12,
            ),
          ),
        ),
        title: Text(
              student.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: PopupMenuButton<String>(
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
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('ویرایش'),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                  if (isEditingNotes[student.id] ?? true) ...[
                    Container(
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
                      child: Column(
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextField(
                              controller: textControllers[student.id],
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              maxLength: attendanceMap[student.id] == AttendanceStatus.late ? 5 : 20,
                              keyboardType: attendanceMap[student.id] == AttendanceStatus.late
                                  ? TextInputType.number
                                  : TextInputType.text,
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
                                    ? '${textControllers[student.id]?.text.length ?? 0}/5'
                                    : '${textControllers[student.id]?.text.length ?? 0}/20',
                                counterStyle: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey[500],
                                ),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.normal,
                                ),
                                hintStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
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
                                  textControllers[student.id]?.text = formattedValue;
                                  textControllers[student.id]?.selection = TextSelection.fromPosition(
                                    TextPosition(offset: formattedValue.length),
                                  );
                                  setState(() {
                                    notesMap[student.id] = formattedValue;
                                  });
                                } else {
                                  setState(() {
                                    notesMap[student.id] = value;
                                  });
                                }
                              },
                            ),
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
                                notesMap[student.id] ?? '',
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

  Widget _buildAttendanceButton(Student student, String statusText, Color color, IconData icon) {
    final isSelected = _isStatusSelected(student, statusText);
    
    return GestureDetector(
      onTap: () => _markAttendance(student, statusText, color),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: 2,
          ),
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
              statusText,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
        content: Text('آیا مطمئن هستید که می‌خواهید ${student.fullName} را حذف کنید؟'),
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
      await DataService.deleteStudent(student.id);
      _loadStudents();
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _saveNotes(Student student) async {
    try {
      final notes = textControllers[student.id]?.text ?? '';
      final status = attendanceMap[student.id] ?? AttendanceStatus.absent;

      await DataService.markAttendance(
        student.id,
        selectedDate,
        status,
        notes: notes,
      );

      setState(() {
        notesMap[student.id] = notes;
        isEditingNotes[student.id] = false; // Switch to display mode
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
        notesMap[student.id] = '';
        isEditingNotes[student.id] = true; // Switch back to editing mode
        textControllers[student.id]?.clear();
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
      builder: (context) => AlertDialog(
        title: const Text('تأیید حذف'),
        content: const Text('آیا مطمئن هستید که می‌خواهید تمام دانش‌آموزان را حذف کنید؟\nاین عمل قابل بازگشت نیست.'),
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
    );

    if (confirmed == true) {
      try {
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
      } catch (e) {
        // Handle error silently
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'حضور و غیاب دانش‌آموزان',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          // Add student button
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddStudentScreen(),
                ),
              );
              if (result == true) {
                _loadStudents();
              }
            },
            icon: const Icon(Icons.person_add, color: Colors.white),
            tooltip: 'اضافه کردن دانش‌آموز',
          ),
          // Menu button
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
                        color: attendanceMap.isNotEmpty ? Colors.black : Colors.grey,
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
                        color: students.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                    ),
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
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      // Next day button (moved to left)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            selectedDate = selectedDate.add(const Duration(days: 1));
                          });
                          _loadStudents();
                        },
                        icon: Icon(Icons.chevron_left, color: Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[100],
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  _getPersianDate(selectedDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Previous day button (moved to right)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            selectedDate = selectedDate.subtract(const Duration(days: 1));
                          });
                          _loadStudents();
                        },
                        icon: Icon(Icons.chevron_right, color: Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedDate = DateTime.now();
                        });
                        _loadStudents();
                      },
                      icon: const Icon(Icons.today, color: Colors.white),
                      label: const Text(
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Row(
                      children: [
                          Column(
                          children: [
                            // Filter icon button
                            Container(
                              width: 110,
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[700]!),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: sortBy,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      sortBy = newValue!;
                                    });
                                  },
                                  icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue[700]),
                                   items: <String>['number', 'name', 'firstName'].map<DropdownMenuItem<String>>((String value) {
                                     return DropdownMenuItem<String>(
                                       value: value,
                                       child: Align(
                                         alignment: Alignment.center,
                                         child: Text(
                                           value == 'number' ? 'شماره' : 
                                           value == 'name' ? 'نام خانوادگی' : 'نام',
                                           style: TextStyle(
                                             color: Colors.blue[700],
                                             fontWeight: FontWeight.bold,
                                             fontSize: 12,
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
                           const SizedBox(width: 8),
                        // Search field
                        Expanded(
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextField(
                              controller: _searchController,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'جستجو در نام دانش‌آموزان...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue[600]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
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
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'هیچ دانش‌آموزی ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'برای شروع، دانش‌آموز جدید اضافه کنید',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
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
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'هیچ دانش‌آموزی با این نام یافت نشد',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
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
                              color: _canSaveAttendance() ? Colors.white : Colors.grey,
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
                      label: const Text(
                        'ابتدا دانش‌آموز اضافه کنید',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
