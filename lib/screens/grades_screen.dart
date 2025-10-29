import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../models/student.dart';
import '../models/lesson.dart';
import '../models/grade.dart';
import '../models/class_model.dart';
import '../services/data_service.dart';
import '../services/theme_service.dart';

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
  Map<String, String> studentGrades = {}; // studentId -> grade
  Map<String, String> studentStatuses = {}; // studentId -> status (خ.خ/خ/ق.ب/ن.ب)
  Map<String, TextEditingController> gradeControllers = {}; // studentId -> TextEditingController
  String? editingStudentId; // Track which student is being edited
  final TextEditingController _searchController = TextEditingController();

  bool __isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
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

  Future<void> _showLessonOptions(Lesson lesson) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'گزینه‌های درس "${lesson.name}"',
                style: TextStyle(
                  fontFamily: 'BYekan',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: __isDarkMode(context) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue[600]),
                title: Text(
                  'ویرایش درس',
                  style: TextStyle(
                    fontFamily: 'BYekan',
                    color: __isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _editLesson(lesson);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[600]),
                title: Text(
                  'حذف درس',
                  style: TextStyle(
                    fontFamily: 'BYekan',
                    color: __isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLesson(lesson);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editLesson(Lesson lesson) async {
    final TextEditingController controller = TextEditingController(text: lesson.name);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor:
        __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text(
            'ویرایش درس',
            style: TextStyle(
              fontFamily: 'BYekan',
              color: __isDarkMode(context) ? Colors.white : Colors.black,
            ),
          ),
          content: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: __isDarkMode(context) ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'نام درس',
              labelStyle: TextStyle(
                color: __isDarkMode(context) ? Colors.grey[300] : Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.trim().isNotEmpty && result.trim() != lesson.name) {
      try {
        final updatedLesson = lesson.copyWith(name: result.trim());
        await DataService.updateLesson(updatedLesson);
        
        setState(() {
          final index = lessons.indexWhere((l) => l.id == lesson.id);
          if (index != -1) {
            lessons[index] = updatedLesson;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'درس "${result.trim()}" ویرایش شد',
              style: TextStyle(
                fontFamily: 'BYekan',
                color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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

  Future<void> _deleteLesson(Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text(
            'حذف درس',
            style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black),
          ),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید درس "${lesson.name}" را حذف کنید؟\nتمام نمرات مربوط به این درس نیز حذف خواهند شد.',
            style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black),
          ),
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
        await DataService.deleteLesson(lesson.id);
        
        setState(() {
          lessons.removeWhere((l) => l.id == lesson.id);
          if (selectedLesson?.id == lesson.id) {
            selectedLesson = null;
            studentGrades.clear();
            studentStatuses.clear();
            for (final controller in gradeControllers.values) {
              controller.clear();
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'درس "${lesson.name}" حذف شد',
              style: TextStyle(
                fontFamily: 'BYekan',
                color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
              ),
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _saveGrades() async {
    if (selectedLesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ابتدا یک درس انتخاب کنید',
            style: TextStyle(
              fontFamily: 'Vazir',
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Count saved grades
    int savedCount = 0;
    for (final student in students) {
      if (studentGrades[student.id] != null || studentStatuses[student.id] != null) {
        savedCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$savedCount نمره ذخیره شد',
          style: TextStyle(
            fontFamily: 'Vazir',
            color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          ),
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportGrades() async {
    if (selectedLesson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ابتدا یک درس انتخاب کنید',
            style: TextStyle(
              fontFamily: 'Vazir',
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
            ),
          ),
          backgroundColor: Colors.orange[600],
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show export options
    showModalBottomSheet(
      context: context,
      backgroundColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'گزینه‌های خروجی',
                style: TextStyle(
                  fontFamily: 'Vazir',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: __isDarkMode(context) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red[600]),
                title: Text(
                  'خروجی PDF',
                  style: TextStyle(
                    fontFamily: 'Vazir',
                    color: __isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportToPDF();
                },
              ),
              ListTile(
                leading: Icon(Icons.table_chart, color: Colors.blue[600]),
                title: Text(
                  'خروجی Excel',
                  style: TextStyle(
                    fontFamily: 'Vazir',
                    color: __isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel();
                },
              ),
              ListTile(
                leading: Icon(Icons.text_snippet, color: Colors.green[600]),
                title: Text(
                  'خروجی متنی',
                  style: TextStyle(
                    fontFamily: 'Vazir',
                    color: __isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _exportToText();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _getPersianDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final persianMonths = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    
    final day = _toPersianNumbers(jalali.day.toString());
    final month = persianMonths[jalali.month - 1];
    
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

  Future<pw.Font> _loadPersianFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/Vazir-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      // Fallback to default font if Persian font is not available
      return pw.Font.helvetica();
    }
  }

  Future<void> _exportToPDF() async {
    if (selectedLesson == null) return;

    try {
      // Create PDF document
      final pdf = pw.Document();
      final persianFont = await _loadPersianFont();
      
      // Split data into pages (max 13 students per page)
      const int studentsPerPage = 13;
      final totalPages = (students.length / studentsPerPage).ceil();
      
      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final startIndex = pageIndex * studentsPerPage;
        final endIndex = (startIndex + studentsPerPage).clamp(0, students.length);
        final pageStudents = students.sublist(startIndex, endIndex);
        
        pdf.addPage(
          pw.Page(
            textDirection: pw.TextDirection.rtl,
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Header for each page
                  pw.Header(
                    level: 0,
                    child: pw.Text(
                      'گزارش نمرات',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        font: persianFont,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Lesson info
                  pw.Text(
                    'نام درس: ${selectedLesson!.name}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      font: persianFont,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  
                  // Class info
                  pw.Text(
                    selectedClass != null 
                      ? 'نام کلاس: ${selectedClass!.name}'
                      : 'نام کلاس: همه دانش‌آموزان',
                    style: pw.TextStyle(
                      fontSize: 16,
                      font: persianFont,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  
                  // Date
                  pw.Text(
                    'تاریخ: ${_getPersianDate(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      font: persianFont,
                    ),
                  ),
                  
                  // Page info
                  if (totalPages > 1) ...[
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'صفحه ${pageIndex + 1} از $totalPages',
                      style: pw.TextStyle(
                        fontSize: 14,
                        font: persianFont,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 20),
                  
                  // Table header
                  pw.Text(
                    'جدول نمرات:',
                    style: pw.TextStyle(
                      fontSize: 16, 
                      fontWeight: pw.FontWeight.bold,
                      font: persianFont,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  
                  // Table
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),     // شماره
                      1: const pw.FlexColumnWidth(1.5),   // نام
                      2: const pw.FlexColumnWidth(2),     // نام خانوادگی
                      3: const pw.FlexColumnWidth(1),    // نمره
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'نمره',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: persianFont,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'نام خانوادگی',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: persianFont,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'نام',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: persianFont,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'شماره',
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: persianFont,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Data rows for this page
                      ...pageStudents.map((student) {
                        final grade = studentGrades[student.id];
                        final status = studentStatuses[student.id];
                        final gradeText = grade ?? status ?? '-';
                        
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                gradeText,
                                style: pw.TextStyle(font: persianFont),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                student.lastName,
                                style: pw.TextStyle(font: persianFont),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                student.firstName,
                                style: pw.TextStyle(font: persianFont),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                student.studentNumber,
                                style: pw.TextStyle(font: persianFont),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      }

      // Save PDF
      final directory = await _getDownloadDirectory();
      final fileName = '${_getPersianFileName()}.pdf';
      final file = File('${directory.path}/$fileName');
      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes, mode: FileMode.write);
      
      // Open file
      await OpenFile.open(file.path);
      _showMessage('فایل PDF با موفقیت ایجاد شد\nمسیر: ${file.path}');
    } catch (e) {
      _showMessage('خطا در تولید PDF: $e');
    }
  }

  Future<void> _exportToExcel() async {
    if (selectedLesson == null) return;

    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['گزارش نمرات'];
      
      // Header
      sheetObject.cell(CellIndex.indexByString('A1')).value = TextCellValue('گزارش نمرات');
      sheetObject.cell(CellIndex.indexByString('A2')).value = TextCellValue('نام درس: ${selectedLesson!.name}');
      
      // Class info
      if (selectedClass != null) {
        sheetObject.cell(CellIndex.indexByString('A3')).value = TextCellValue('نام کلاس: ${selectedClass!.name}');
      } else {
        sheetObject.cell(CellIndex.indexByString('A3')).value = TextCellValue('نام کلاس: همه دانش‌آموزان');
      }
      
      // Date
      final now = DateTime.now();
      final persianDate = '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
      sheetObject.cell(CellIndex.indexByString('A4')).value = TextCellValue('تاریخ: $persianDate');
      
      // Empty row
      sheetObject.cell(CellIndex.indexByString('A6')).value = TextCellValue('جدول نمرات:');
      
      // Table headers (RTL order: شماره, نام, نام خانوادگی, نمره)
      sheetObject.cell(CellIndex.indexByString('A8')).value = TextCellValue('نمره');
      sheetObject.cell(CellIndex.indexByString('B8')).value = TextCellValue('نام خانوادگی');
      sheetObject.cell(CellIndex.indexByString('C8')).value = TextCellValue('نام');
      sheetObject.cell(CellIndex.indexByString('D8')).value = TextCellValue('شماره');
      
      // Table data
      int rowIndex = 9;
      for (final student in students) {
        final grade = studentGrades[student.id];
        final status = studentStatuses[student.id];
        final gradeText = grade ?? status ?? '-';
        
        sheetObject.cell(CellIndex.indexByString('A$rowIndex')).value = TextCellValue(gradeText);
        sheetObject.cell(CellIndex.indexByString('B$rowIndex')).value = TextCellValue(student.lastName);
        sheetObject.cell(CellIndex.indexByString('C$rowIndex')).value = TextCellValue(student.firstName);
        sheetObject.cell(CellIndex.indexByString('D$rowIndex')).value = TextCellValue(student.studentNumber);
        rowIndex++;
      }

      // Save Excel file
      final directory = await _getDownloadDirectory();
      final fileName = '${_getPersianFileName()}.xlsx';
      final file = File('${directory.path}/$fileName');
      final bytes = excel.encode();
      await file.writeAsBytes(bytes!, mode: FileMode.write);
      
      await OpenFile.open(file.path);
      _showMessage('فایل Excel با موفقیت ایجاد شد\nمسیر: ${file.path}');
    } catch (e) {
      _showMessage('خطا در تولید Excel: $e');
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // For Android, try to get the main Downloads directory
      try {
        // Try to access the main Downloads directory
        final downloadPath = Directory('/storage/emulated/0/Download');
        if (!await downloadPath.exists()) {
          await downloadPath.create(recursive: true);
        }
        return downloadPath;
      } catch (e) {
        // Fallback to external storage directory
        try {
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            final fallbackPath = Directory('${directory.path}/Download');
            if (!await fallbackPath.exists()) {
              await fallbackPath.create(recursive: true);
            }
            return fallbackPath;
          }
        } catch (e) {
          // Final fallback to application documents directory
        }
      }
    }
    
    // Fallback to application documents directory
    return await getApplicationDocumentsDirectory();
  }

  String _getPersianFileName() {
    final now = DateTime.now();
    final persianDate = _getPersianDate(now);
    // Convert Persian date to a safe filename format
    final safeDate = persianDate.replaceAll('/', '_').replaceAll(' ', '_');
    return 'گزارش_نمرات_${selectedLesson?.name ?? 'نامشخص'}_$safeDate';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            fontFamily: 'Vazir',
            color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportToText() async {
    if (selectedLesson == null) return;

    try {
      final StringBuffer content = StringBuffer();
      
      // Header
      content.writeln('گزارش نمرات');
      content.writeln('=' * 50);
      content.writeln('نام درس: ${selectedLesson!.name}');
      
      // Class info
      if (selectedClass != null) {
        content.writeln('نام کلاس: ${selectedClass!.name}');
      } else {
        content.writeln('نام کلاس: همه دانش‌آموزان');
      }
      
      // Date
      content.writeln('تاریخ: ${_getPersianDate(DateTime.now())}');
      content.writeln('تعداد کل دانش‌آموزان: ${students.length}');
      
      // Count grades
      int gradedCount = 0;
      int numericGrades = 0;
      int descriptiveGrades = 0;
      
      for (final student in students) {
        if (studentGrades[student.id] != null) {
          gradedCount++;
          numericGrades++;
        } else if (studentStatuses[student.id] != null) {
          gradedCount++;
          descriptiveGrades++;
        }
      }
      
      content.writeln('تعداد نمره‌گذاری شده: $gradedCount');
      content.writeln('تعداد نمره عددی: $numericGrades');
      content.writeln('تعداد نمره توصیفی: $descriptiveGrades');
      content.writeln('');
      content.writeln('جزئیات:');
      content.writeln('-' * 80);
      
      // Table header (RTL order: شماره, نام, نام خانوادگی, نمره)
      content.writeln('${'نمره'.padRight(12)} ${'نام خانوادگی'.padRight(15)} ${'نام'.padRight(15)} ${'شماره'.padRight(8)}');
      content.writeln('-' * 80);
      
      // Table data
      for (final student in students) {
        final grade = studentGrades[student.id];
        final status = studentStatuses[student.id];
        final gradeText = grade ?? status ?? '-';
        
        content.writeln(
          '${gradeText.padRight(12)} '
          '${student.lastName.padRight(15)} '
          '${student.firstName.padRight(15)} '
          '${student.studentNumber.padRight(8)}'
        );
      }
      
      content.writeln('-' * 80);
      content.writeln('تاریخ ایجاد گزارش: ${_getPersianDate(DateTime.now())}');

      // Save text file
      final directory = await _getDownloadDirectory();
      final fileName = '${_getPersianFileName()}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content.toString(), encoding: utf8, mode: FileMode.write);
      
      await OpenFile.open(file.path);
      _showMessage('فایل متنی با موفقیت ایجاد شد\nمسیر: ${file.path}');
    } catch (e) {
      _showMessage('خطا در ایجاد فایل متنی: $e');
    }
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
          backgroundColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text('اضافه کردن درس جدید', style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black),
                controller: lessonNameController,
                decoration: InputDecoration(
                  labelText: 'نام درس',
                  labelStyle: TextStyle(color: __isDarkMode(context) ? Colors.white54 : Colors.black),
                  hintText: 'نام درس را وارد کنید',
                  hintStyle: TextStyle(color: __isDarkMode(context) ? Colors.white70 : Colors.black),
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
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
          backgroundColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text('پاک کردن نمرات', style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black)),
          content: Text('آیا مطمئن هستید که می‌خواهید تمام نمرات درس "${selectedLesson!.name}" را پاک کنید؟', style: TextStyle(color: __isDarkMode(context) ? Colors.white : Colors.black)),
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
                color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
              color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
        color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: __isDarkMode(context) ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
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
                  style: TextStyle(
                    fontFamily: 'BYekan',
                    color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                color: __isDarkMode(context) ? Colors.white : const Color(0xFF2D3748),
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
                        color: __isDarkMode(context) ? Colors.grey[700] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: __isDarkMode(context) ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child:TextField(
                        controller: gradeControllers[student.id],
                        textAlign: TextAlign.center, // وسط افقی
                        textAlignVertical: TextAlignVertical.center, // وسط عمودی
                        keyboardType: TextInputType.number,
                        enabled: selectedLesson != null && studentStatuses[student.id] == null,
                        style: TextStyle(
                          color: __isDarkMode(context) ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'نمره عددی',
                          hintStyle: TextStyle(
                            fontSize: 13,

                            color: __isDarkMode(context) ? Colors.grey[400] : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          isCollapsed: true, // این باعث میشه ارتفاع دقیق‌تری بگیره
                          contentPadding: EdgeInsets.symmetric(vertical: 8), // کمک به وسط قرار گرفتن کامل hint
                        ),
                        onTap: () {
                          if (selectedLesson == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'ابتدا درس را انتخاب کنید',
                                  style: TextStyle(
                                    fontFamily: 'BYekan',
                                    color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                        color: __isDarkMode(context) ? Colors.grey[700] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: __isDarkMode(context) ? Colors.grey[600]! : Colors.grey[300]!),
                      ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                                    color: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
                                  ),
                                ),
                                backgroundColor: Colors.orange[600],
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        hint: Center(
                          child: Text(
                            'نمره توصیفی',
                            style: TextStyle(
                              fontSize: 12,
                              color: __isDarkMode(context) ? Colors.grey[400] : Colors.grey[600],
                            ),
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
                                    color: __isDarkMode(context) ? Colors.white : Colors.black,
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
      backgroundColor: __isDarkMode(context) ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'نمرات درس',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: __isDarkMode(context) ? Colors.white70 : Colors.white,
            fontSize: 20
          ),
        ),
        backgroundColor: __isDarkMode(context) ? Colors.blue[900] : Colors.blue[700],
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: __isDarkMode(context) ? Colors.white70 : Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.clear_all,
              color: __isDarkMode(context) ? Colors.white70 : Colors.white,
            ),
            onPressed: () {
              _clearAllGrades();
            },
            tooltip: 'پاک کردن نمرات',
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
                  color: __isDarkMode(context) ? Colors.grey[900] : Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'انتخاب درس',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: __isDarkMode(context) ? Colors.white : Colors.grey[700],
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
                                  onLongPress: () => _showLessonOptions(lesson),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selectedLesson?.id == lesson.id ? Colors.blue[700] : (__isDarkMode(context) ? Colors.grey[800] : Colors.grey[200]),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selectedLesson?.id == lesson.id ? Colors.blue[700]! : Colors.grey[400]!,
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
                    color: __isDarkMode(context) ? Colors.grey[950] : Colors.grey[50],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'انتخاب کلاس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: __isDarkMode(context) ? Colors.white : Colors.grey[700],
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
                                      color: selectedClass == null ? Colors.blue[700] : (__isDarkMode(context) ? Colors.grey[800] : Colors.grey[200]),
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
                                // Class options
                                ...classes.reversed.map((classModel) => Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: GestureDetector(
                                    onTap: () => _selectClass(classModel),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selectedClass?.id == classModel.id ? Colors.blue[700] : (__isDarkMode(context) ? Colors.grey[800] : Colors.grey[200]),
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
                          color: __isDarkMode(context) ? Colors.grey[750] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: __isDarkMode(context) ? Colors.white24 : Colors.blue[700]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: __isDarkMode(context) ? Colors.grey[800] : Colors.white,
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
                              color: __isDarkMode(context) ? Colors.grey[800] : Colors.blue[700],
                              size: 20
                            ),
                            icon: Icon(Icons.keyboard_arrow_down, color: __isDarkMode(context) ? Colors.white60 : Colors.blue[700]),
                            items: <String>['number', 'name', 'firstName'].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Center(
                                  child: Text(
                                    value == 'number' ? 'شماره' :
                                    value == 'name' ? 'فامیلی' : 'نام',
                                    style: TextStyle(
                                      color: __isDarkMode(context) ? Colors.blue[300] : Colors.blue[700],
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
                                color: __isDarkMode(context) ? Colors.white : Colors.black,
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
                                  color: __isDarkMode(context) ? Colors.grey[400] : Colors.grey[500],
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: __isDarkMode(context) ? Colors.grey[300] : Colors.grey[600],
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: __isDarkMode(context) ? Colors.grey[300] : Colors.grey[600],
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
                                    color: __isDarkMode(context) ? Colors.grey[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: __isDarkMode(context) ? Colors.grey[700]! : Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: __isDarkMode(context) ? Colors.blue[400]! : Colors.blue[600]!,
                                  ),
                                ),
                                filled: true,
                                fillColor: __isDarkMode(context) ? Colors.grey[850] : Colors.grey[50],
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
                  // Instruction message

                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: __isDarkMode(context) ? Colors.blue[900] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: __isDarkMode(context) ? Colors.blue[700]! : Colors.blue[200]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [

                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'نکته: فقط یکی از فیلدها را می‌توانید پر کنید ( نمره عددی یا نمره توصیفی )',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'BYekan',
                              color: __isDarkMode(context) ? Colors.blue[200] : Colors.blue[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,

                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.info_outline,
                          color: __isDarkMode(context) ? Colors.blue[300] : Colors.blue[600],
                          size: 20,
                        ),
                      ],
                    ),
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
                                color: __isDarkMode(context) ? Colors.grey[500] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'هیچ دانش‌آموزی ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: __isDarkMode(context) ? Colors.grey[400] : Colors.grey[600],
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
                                    color: __isDarkMode(context) ? Colors.grey[500] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'هیچ دانش‌آموزی با این نام یافت نشد',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: __isDarkMode(context) ? Colors.grey[400] : Colors.grey[600],
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
                // Bottom buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: __isDarkMode(context) ? Colors.grey[900] : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: __isDarkMode(context) ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Export button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _exportGrades,
                          icon: Icon(Icons.download, color: Colors.white),
                          label: Text(
                            'خروجی',
                            style: TextStyle(
                              fontFamily: 'Vazir',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Save button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveGrades,
                          icon: Icon(Icons.save, color: Colors.white),
                          label: Text(
                            'ثبت',
                            style: TextStyle(
                              fontFamily: 'Vazir',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
