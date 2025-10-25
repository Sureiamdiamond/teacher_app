import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/data_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<Student> students = [];
  List<AttendanceRecord> allRecords = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  bool showLatestStatus = true;
  String sortBy = 'number'; // 'number', 'name', or 'firstName'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    final loadedStudents = await DataService.getStudents();
    final loadedRecords = await DataService.getAttendanceRecords();
    
    setState(() {
      students = loadedStudents..sort((a, b) => a.studentNumber.compareTo(b.studentNumber));
      allRecords = loadedRecords;
      isLoading = false;
    });
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

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.excused:
        return Colors.blue;
      case AttendanceStatus.late:
        return Colors.orange;
    }
  }

  String _getStatusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'حاضر';
      case AttendanceStatus.absent:
        return 'غایب';
      case AttendanceStatus.excused:
        return 'موجه';
      case AttendanceStatus.late:
        return 'تأخیر';
    }
  }

  List<AttendanceRecord> _getRecordsForDate(DateTime date) {
    return allRecords.where((record) => 
        record.date.year == date.year &&
        record.date.month == date.month &&
        record.date.day == date.day).toList();
  }


  List<AttendanceRecord> _getTodayRecords() {
    final today = DateTime.now();
    return allRecords.where((record) => 
        record.date.year == today.year &&
        record.date.month == today.month &&
        record.date.day == today.day).toList();
  }

  List<AttendanceRecord> _getReportData() {
    List<AttendanceRecord> records;
    if (showLatestStatus) {
      // Show only today's records for latest status
      records = _getTodayRecords();
    } else {
      records = _getRecordsForDate(selectedDate);
    }
    
    // Sort records based on sortBy preference
    if (sortBy == 'name') {
      records.sort((a, b) {
        final studentA = students.firstWhere((s) => s.id == a.studentId);
        final studentB = students.firstWhere((s) => s.id == b.studentId);
        return studentA.lastName.compareTo(studentB.lastName);
      });
    } else if (sortBy == 'firstName') {
      records.sort((a, b) {
        final studentA = students.firstWhere((s) => s.id == a.studentId);
        final studentB = students.firstWhere((s) => s.id == b.studentId);
        return studentA.firstName.compareTo(studentB.firstName);
      });
    } else {
      records.sort((a, b) {
        final studentA = students.firstWhere((s) => s.id == a.studentId);
        final studentB = students.firstWhere((s) => s.id == b.studentId);
        return int.parse(studentA.studentNumber).compareTo(int.parse(studentB.studentNumber));
      });
    }
    
    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'گزارش‌گیری حضور و غیاب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: Colors.white),
            onSelected: (value) async {
              if (value == 'pdf') {
                await _exportToPDF();
              } else if (value == 'excel') {
                await _exportToExcel();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red),
                    SizedBox(width: 8),
                    Text('خروجی PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'excel',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Colors.green),
                    SizedBox(width: 8),
                    Text('خروجی Excel'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Toggle buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue[50],
                  child: Column(
                    children: [
                      // Toggle buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  showLatestStatus = true;
                                });
                              },
                              icon: Icon(
                                Icons.update,
                                color: showLatestStatus ? Colors.white : Colors.blue[700],
                              ),
                              label: Text(
                                'وضعیت امروز',
                                style: TextStyle(
                                  color: showLatestStatus ? Colors.white : Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: showLatestStatus ? Colors.blue[700] : Colors.white,
                                side: BorderSide(color: Colors.blue[700]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  showLatestStatus = false;
                                });
                              },
                              icon: Icon(
                                Icons.calendar_today,
                                color: !showLatestStatus ? Colors.white : Colors.blue[700],
                              ),
                              label: Text(
                                'تاریخ مشخص',
                                style: TextStyle(
                                  color: !showLatestStatus ? Colors.white : Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !showLatestStatus ? Colors.blue[700] : Colors.white,
                                side: BorderSide(color: Colors.blue[700]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sort options
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: DropdownButtonFormField<String>(
                          value: sortBy,
                          onChanged: (String? newValue) {
                            setState(() {
                              sortBy = newValue!;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'مرتب‌سازی بر اساس',
                            labelStyle: TextStyle(color: Colors.blue[700]),
                            prefixIcon: Icon(Icons.filter_list, color: Colors.blue[700]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[700]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[700]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.blue[700]!),
                            ),
                            filled: true,
                            fillColor: Colors.blue[50],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          items: <String>['number', 'name', 'firstName'].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(
                                    value == 'number' ? Icons.numbers : 
                                    value == 'name' ? Icons.sort_by_alpha : Icons.person,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    value == 'number' ? 'شماره ترتیب' : 
                                    value == 'name' ? 'الفبا (نام خانوادگی)' : 'الفبا (نام)',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date selector (only show when not showing latest status)
                      if (!showLatestStatus)
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedDate = selectedDate.add(const Duration(days: 1));
                                });
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
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedDate = selectedDate.subtract(const Duration(days: 1));
                                });
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
                    ],
                  ),
                ),

                // Report
                Expanded(
                  child: _getReportData().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                showLatestStatus 
                                    ? 'هیچ رکوردی ثبت نشده است'
                                    : 'هیچ رکوردی برای این تاریخ ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Report header
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.assessment,
                                    size: 32,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    showLatestStatus 
                                        ? 'وضعیت امروز'
                                        : 'گزارش حضور و غیاب',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                
                                ],
                              ),
                            ),
                            // Report items
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: _getReportData().length,
                                itemBuilder: (context, index) {
                                  final record = _getReportData()[index];
                                  final student = students.firstWhere((s) => s.id == record.studentId);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor(record.status).withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Status indicator
                                        Container(
                                          width: 4,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(record.status),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Student info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${student.fullName} - ${_getStatusText(record.status)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getStatusColor(record.status),
                                                ),
                                              ),
                                              if (record.notes != null && record.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  record.notes!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Date
                                        Text(
                                          _getPersianDate(record.date),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
    );
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
    }
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
    try {
      final reportData = _getReportData();
      if (reportData.isEmpty) {
        _showMessage('هیچ داده‌ای برای خروجی وجود ندارد');
        return;
      }

      final pdf = pw.Document();
      final persianFont = await _loadPersianFont();
      
      // Add content to PDF with UTF-8 encoding
      pdf.addPage(
        pw.Page(
          textDirection: pw.TextDirection.rtl,
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'گزارش حضور و غیاب',
                    style: pw.TextStyle(
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold,
                      font: persianFont,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'تاریخ: ${_getPersianDate(selectedDate)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    font: pw.Font.helvetica(),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(50),
                    1: const pw.FixedColumnWidth(100),
                    2: const pw.FixedColumnWidth(100),
                    3: const pw.FixedColumnWidth(80),
                    4: const pw.FixedColumnWidth(80),
                    5: const pw.FlexColumnWidth(),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('ترتیب', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('نام', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('نام خانوادگی', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('تاریخ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('وضعیت', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('یادداشت', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: persianFont)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...reportData.map((record) {
                      final student = students.firstWhere((s) => s.id == record.studentId);
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(student.studentNumber.toString(), style: pw.TextStyle(font: persianFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(student.firstName, style: pw.TextStyle(font: persianFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(student.lastName, style: pw.TextStyle(font: persianFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_getPersianDate(record.date), style: pw.TextStyle(font: persianFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(_getStatusTextForExport(record.status), style: pw.TextStyle(font: persianFont)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(record.notes ?? '', style: pw.TextStyle(font: persianFont)),
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

      // Save PDF
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      final pdfBytes = await pdf.save();
      await file.writeAsBytes(pdfBytes, mode: FileMode.write);
      
      // Open file
      await OpenFile.open(file.path);
      _showMessage('فایل PDF با موفقیت ایجاد شد\nمسیر: ${file.path}');
    } catch (e) {
      _showMessage('خطا در ایجاد فایل PDF: $e');
    }
  }

  Future<void> _exportToExcel() async {
    try {
      final reportData = _getReportData();
      if (reportData.isEmpty) {
        _showMessage('هیچ داده‌ای برای خروجی وجود ندارد');
        return;
      }

      final excel = Excel.createExcel();
      final sheet = excel['گزارش حضور و غیاب'];
      
      // Add headers
      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('ترتیب');
      sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('نام');
      sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('نام خانوادگی');
      sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('تاریخ');
      sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('وضعیت');
      sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('یادداشت');

      // Add data
      for (int i = 0; i < reportData.length; i++) {
        final record = reportData[i];
        final student = students.firstWhere((s) => s.id == record.studentId);
        final row = i + 2;
        
        sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(student.studentNumber.toString());
        sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(student.firstName);
        sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(student.lastName);
        sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(_getPersianDate(record.date));
        sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(_getStatusTextForExport(record.status));
        sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(record.notes ?? '');
      }

      // Save Excel
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      final bytes = excel.encode();
      await file.writeAsBytes(bytes!);
      
      // Open file
      await OpenFile.open(file.path);
      _showMessage('فایل Excel با موفقیت ایجاد شد\nمسیر: ${file.path}');
    } catch (e) {
      _showMessage('خطا در ایجاد فایل Excel: $e');
    }
  }

  String _getStatusTextForExport(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'حاضر';
      case AttendanceStatus.absent:
        return 'غایب';
      case AttendanceStatus.excused:
        return 'موجه';
      case AttendanceStatus.late:
        return 'تأخیر';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[700],
      ),
    );
  }
}
