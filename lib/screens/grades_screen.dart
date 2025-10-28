import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/lesson.dart';
import '../models/grade.dart';
import '../models/class_model.dart';
import '../services/data_service.dart';

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Student> students = [];
  List<Lesson> lessons = [];
  List<ClassModel> classes = [];
  ClassModel? selectedClass;
  Lesson? selectedLesson;
  bool isLoading = true;
  bool isDarkMode = false;
  Map<String, String> studentGrades = {}; // studentId -> grade
  Map<String, String> studentStatuses = {}; // studentId -> status (خ.خ/خ/ق.ب/ن.ب)
  Map<String, TextEditingController> gradeControllers = {}; // studentId -> TextEditingController
  String? editingStudentId; // Track which student is being edited
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String sortBy = 'number'; // 'number', 'name', or 'firstName'
  
  // Status options
  final List<String> statusOptions = ['خیلی خوب', 'خوب', 'قابل قبول', 'نیاز به تلاش بیشتر'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all grade controllers
    for (final controller in gradeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    // Load classes, lessons, and students
    final loadedClasses = await DataService.getClasses();
    final loadedLessons = await DataService.getLessons();
    
    List<Student> loadedStudents;
    if (selectedClass != null) {
      loadedStudents = await DataService.getStudentsByClass(selectedClass!.id);
    } else {
      loadedStudents = await DataService.getStudents();
    }
    
    // Load grades and statuses for selected lesson
    Map<String, String> gradesMap = {};
    Map<String, String> statusesMap = {};
    if (selectedLesson != null) {
      final grades = await DataService.getGradesForLesson(selectedLesson!.id);
      for (final grade in grades) {
        // Check if the grade is a status (خیلی خوب/خوب/قابل قبول/نیاز به تلاش بیشتر) or a numeric grade
        if (statusOptions.contains(grade.grade)) {
          statusesMap[grade.studentId] = grade.grade;
        } else {
          gradesMap[grade.studentId] = grade.grade;
        }
      }
    }

    setState(() {
      classes = loadedClasses;
      lessons = loadedLessons;
      students = loadedStudents..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
      studentGrades = gradesMap;
      studentStatuses = statusesMap;
      
      // Initialize text controllers for each student with current lesson grades
      for (final student in loadedStudents) {
        if (!gradeControllers.containsKey(student.id)) {
          gradeControllers[student.id] = TextEditingController();
        }
        // Update controller text with current lesson's grade (only if not a status)
        gradeControllers[student.id]!.text = gradesMap[student.id] ?? '';
      }
      
      // Clear editing state when lesson changes
      editingStudentId = null;
      
      isLoading = false;
    });
  }

  Future<void> _selectClass(ClassModel? classModel) async {
    setState(() {
      selectedClass = classModel;
    });
    await _loadData();
  }

  Future<void> _selectLesson(Lesson? lesson) async {
    setState(() {
      selectedLesson = lesson;
    });
    await _loadData();
  }

  Future<void> _addNewLesson() async {
    final TextEditingController lessonNameController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('اضافه کردن درس جدید', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                controller: lessonNameController,
                decoration: InputDecoration(
                  labelText: 'نام درس',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black),
                  hintText: 'نام درس را وارد کنید',
                  hintStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black),
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
                if (lessonNameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('اضافه کردن'),
            ),
          ],
        ),
      ),
    );

    if (result == true && lessonNameController.text.trim().isNotEmpty) {
      final newLesson = Lesson(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: lessonNameController.text.trim(),
        createdAt: DateTime.now(),
      );
      
      await DataService.addLesson(newLesson);
      await _loadData();
      
      // Select the newly created lesson
      setState(() {
        selectedLesson = newLesson;
      });
    }
  }

  void _startEditingStudent(String studentId) {
    setState(() {
      editingStudentId = studentId;
    });
  }

  void _cancelEditingStudent() {
    setState(() {
      editingStudentId = null;
    });
  }

  Future<void> _clearAllGrades() async {
    if (selectedLesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ابتدا درس را انتخاب کنید',
            style: TextStyle(
              fontFamily: 'BYekan',
              color: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
          title: Text('پاک کردن نمرات', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          content: Text('آیا مطمئن هستید که می‌خواهید تمام نمرات درس "${selectedLesson!.name}" را پاک کنید؟', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('پاک کردن', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        // Delete all grades for the selected lesson
        final grades = await DataService.getGradesForLesson(selectedLesson!.id);
        for (final grade in grades) {
          await DataService.deleteGrade(grade.id);
        }
        
        setState(() {
          studentGrades.clear();
          studentStatuses.clear();
          for (final controller in gradeControllers.values) {
            controller.clear();
          }
          editingStudentId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمام نمرات درس "${selectedLesson!.name}" پاک شد',
              style: TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _updateStudentStatus(Student student, String status) async {
    if (selectedLesson == null) return;
    
    // Allow empty status to clear the status
    if (status.isEmpty) {
      try {
        final existingGrade = await DataService.getStudentGradeForLesson(student.id, selectedLesson!.id);
        if (existingGrade != null) {
          await DataService.deleteGrade(existingGrade.id);
        }
        
        setState(() {
          studentStatuses.remove(student.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'وضعیت ${student.fullName} پاک شد',
              style: TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.orange[600],
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      } catch (e) {
        // Handle error silently
        return;
      }
    }
    
    try {
      final existingGrade = await DataService.getStudentGradeForLesson(student.id, selectedLesson!.id);
      
      if (existingGrade != null) {
        // Update existing grade/status
        final updatedGrade = existingGrade.copyWith(grade: status);
        await DataService.updateGrade(updatedGrade);
      } else {
        // Add new status
        final newGrade = Grade(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          studentId: student.id,
          lessonId: selectedLesson!.id,
          grade: status,
          createdAt: DateTime.now(),
        );
        await DataService.addGrade(newGrade);
      }
      
      setState(() {
        studentStatuses[student.id] = status;
        studentGrades.remove(student.id); // Remove grade if status is selected
        gradeControllers[student.id]!.clear(); // Clear text field
        editingStudentId = null; // Clear editing state after saving
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'وضعیت ${student.fullName} ذخیره شد: $status',
            style: TextStyle(
              fontFamily: 'BYekan',
              color: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _updateStudentGrade(Student student, String grade) async {
    if (selectedLesson == null) return;
    
    // Allow empty grade to clear the grade
    if (grade.trim().isEmpty) {
      try {
        final existingGrade = await DataService.getStudentGradeForLesson(student.id, selectedLesson!.id);
        if (existingGrade != null) {
          await DataService.deleteGrade(existingGrade.id);
        }
        
        setState(() {
          studentGrades.remove(student.id);
          editingStudentId = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'نمره ${student.fullName} پاک شد',
              style: TextStyle(
                fontFamily: 'BYekan',
                color: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.orange[600],
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      } catch (e) {
        // Handle error silently
        return;
      }
    }
    
    // Validate grade (should be between 0 and 20, including decimals)
    final gradeValue = double.tryParse(grade.trim());
    if (gradeValue == null || gradeValue < 0 || gradeValue > 20) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'نمره باید بین ۰ تا ۲۰ باشد (مثال: ۱۹.۵)',
            style: TextStyle(
              fontFamily: 'BYekan',
              color: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
    try {
      final existingGrade = await DataService.getStudentGradeForLesson(student.id, selectedLesson!.id);
      
      if (existingGrade != null) {
        // Update existing grade
        final updatedGrade = existingGrade.copyWith(grade: grade.trim());
        await DataService.updateGrade(updatedGrade);
      } else {
        // Add new grade
        final newGrade = Grade(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          studentId: student.id,
          lessonId: selectedLesson!.id,
          grade: grade.trim(),
          createdAt: DateTime.now(),
        );
        await DataService.addGrade(newGrade);
      }
      
      setState(() {
        studentGrades[student.id] = grade.trim();
        studentStatuses.remove(student.id); // Remove status if grade is selected
        editingStudentId = null; // Clear editing state after saving
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'نمره ${student.fullName} ذخیره شد: ${grade.trim()}',
            style: TextStyle(
              fontFamily: 'BYekan',
              color: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Handle error silently
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
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
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
                  style: TextStyle(
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
          ),
          // Grade and status fields below the name
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Grade text input field
                Expanded(
                  child: Opacity(
                    opacity: studentStatuses[student.id] != null ? 0.6 : 1.0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: TextField(
                        controller: gradeControllers[student.id],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        enabled: selectedLesson != null && studentStatuses[student.id] == null,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'نمره عددی',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onTap: () {
                          if (selectedLesson == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'ابتدا درس را انتخاب کنید',
                                  style: TextStyle(
                                    fontFamily: 'BYekan',
                                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.orange[600],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          _startEditingStudent(student.id);
                        },
                        onChanged: (value) {
                          if (selectedLesson == null) return;
                          _startEditingStudent(student.id);
                        },
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(width: 8),
                // Status dropdown
                Expanded(
                  child: Opacity(
                    opacity: studentGrades[student.id] != null ? 0.6 : 1.0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDarkMode ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                        value: studentStatuses[student.id],
                        isExpanded: true,
                        onChanged: selectedLesson != null && studentGrades[student.id] == null ? (String? newValue) {
                          if (newValue != null) {
                            _updateStudentStatus(student, newValue);
                          }
                        } : (String? newValue) {
                          if (selectedLesson == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'ابتدا درس را انتخاب کنید',
                                  style: TextStyle(
                                    fontFamily: 'BYekan',
                                    color: isDarkMode ? Colors.grey[800] : Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.orange[600],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        hint: Text(
                          'نمره توصیفی',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        items: [
                          // Clear option
                          DropdownMenuItem<String>(
                            value: '',
                            child: Center(
                              child: Text(
                                'پاک کردن',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          // Status options
                          ...statusOptions.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Center(
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),),
                // Show confirmation button when editing this student
                if (editingStudentId == student.id) ...[
                  const SizedBox(width: 8),
                  // Confirm button
                  GestureDetector(
                    onTap: () {
                      final grade = gradeControllers[student.id]?.text ?? '';
                      _updateStudentGrade(student, grade);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Cancel button
                  GestureDetector(
                    onTap: () {
                      _cancelEditingStudent();
                      // Reset the text field to the saved grade
                      gradeControllers[student.id]!.text = studentGrades[student.id] ?? '';
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'نمرات درس',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.white,
            fontSize: 20
          ),
        ),
        backgroundColor: isDarkMode ? Colors.purple[900] : Colors.purple[700],
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white70 : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.clear_all,
              color: isDarkMode ? Colors.white70 : Colors.white,
            ),
            onPressed: () {
              _clearAllGrades();
            },
            tooltip: 'پاک کردن نمرات',
          ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: isDarkMode ? Colors.white70 : Colors.white,
            ),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
            tooltip: isDarkMode ? 'حالت روشن' : 'حالت تاریک',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Lesson selector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: isDarkMode ? Colors.grey[900] : Colors.purple[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'انتخاب درس',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.grey[700],
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
                              // Add lesson button
                              GestureDetector(
                                onTap: _addNewLesson,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green[600]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'اضافه کردن درس',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Lesson options
                              ...lessons.map((lesson) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: GestureDetector(
                                  onTap: () => _selectLesson(lesson),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedLesson?.id == lesson.id ? Colors.purple[700] : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selectedLesson?.id == lesson.id ? Colors.purple[700]! : Colors.grey[400]!,
                                      ),
                                    ),
                                    child: Text(
                                      lesson.name,
                                      style: TextStyle(
                                        color: selectedLesson?.id == lesson.id ? Colors.white : Colors.grey[600],
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
                
                // Class selector
                if (classes.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: isDarkMode ? Colors.grey[950] : Colors.grey[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'انتخاب کلاس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.grey[700],
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
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedClass == null ? Colors.purple[700] : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selectedClass == null ? Colors.purple[700]! : Colors.grey[400]!,
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
                                // Class options
                                ...classes.reversed.map((classModel) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: GestureDetector(
                                    onTap: () => _selectClass(classModel),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selectedClass?.id == classModel.id ? Colors.purple[700] : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: selectedClass?.id == classModel.id ? Colors.purple[700]! : Colors.grey[400]!,
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

                // Search field and Sort options
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Row(
                    children: [
                      // Sort options
                      Container(
                        height: 42,
                        width: 80,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[750] : Colors.purple[50],
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: isDarkMode ? Colors.white24 : Colors.purple[700]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
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
                              color: isDarkMode ? Colors.grey[800] : Colors.purple[700],
                              size: 20
                            ),
                            icon: Icon(Icons.keyboard_arrow_down, color: isDarkMode ? Colors.white60 : Colors.purple[700]),
                            items: <String>['number', 'name', 'firstName'].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Center(
                                  child: Text(
                                    value == 'number' ? 'شماره' :
                                    value == 'name' ? 'فامیلی' : 'نام',
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.purple[300] : Colors.purple[700],
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
                      const SizedBox(width: 6),
                      // Search field
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: SizedBox(
                            height: 42,
                            child: TextField(
                              style: TextStyle(
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
                                    color: isDarkMode ? Colors.purple[400]! : Colors.purple[600]!,
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
                          : ListView.builder(
                              padding: const EdgeInsets.all(14),
                              itemCount: _getFilteredStudents().length,
                              itemBuilder: (context, index) {
                                final student = _getFilteredStudents()[index];
                                return _buildStudentCard(student);
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
