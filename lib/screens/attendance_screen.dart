import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/data_service.dart';

class AttendanceScreen extends StatefulWidget {
  final List<Student> students;
  final DateTime selectedDate;
  final bool isResultMode;

  const AttendanceScreen({
    super.key,
    required this.students,
    required this.selectedDate,
    this.isResultMode = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, AttendanceStatus> attendanceMap = {};
  Map<String, String> notesMap = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() => isLoading = true);
    
    // Initialize all students as absent by default
    for (final student in widget.students) {
      attendanceMap[student.id] = AttendanceStatus.absent;
    }

    // Load existing attendance records for this date
    final existingRecords = await DataService.getAttendanceForDate(widget.selectedDate);
    for (final record in existingRecords) {
      attendanceMap[record.studentId] = record.status;
      if (record.notes != null) {
        notesMap[record.studentId] = record.notes!;
      }
    }

    setState(() => isLoading = false);
  }

  String _getPersianDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر',
      'مرداد', 'شهریور', 'مهر', 'آبان',
      'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return '${jalali.day} ${months[jalali.month - 1]}';
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.excused:
        return Colors.blue;
    }
  }

  String _getStatusText(AttendanceStatus status) {
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

  Future<void> _saveAttendance() async {
    setState(() => isLoading = true);

    try {
      for (final student in widget.students) {
        final status = attendanceMap[student.id] ?? AttendanceStatus.absent;
        final notes = notesMap[student.id];
        
        await DataService.markAttendance(
          student.id,
          widget.selectedDate,
          status,
          notes: notes,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حضور و غیاب با موفقیت ثبت شد'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ذخیره: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'نتیجه حضور و غیاب',
          style: TextStyle(
            fontFamily: 'BYekan',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          if (!isLoading)
            TextButton(
              onPressed: _saveAttendance,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.save,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ذخیره',
                    style: TextStyle(
                      fontFamily: 'BYekan',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark 
                        ? [Colors.blue[900]!, Colors.blue[800]!]
                        : [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.1),
                        spreadRadius: 0,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue[700] : Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today,
                          size: 28,
                          color: isDark ? Colors.blue[200] : Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 16),
                        Text(
                          _getPersianDate(widget.selectedDate),
                          style: TextStyle(
                            fontFamily: 'BYekan',
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.blue[200] : Colors.blue[800],
                          ),
                        ),
                      const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue[700] : Colors.blue[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'تعداد دانش‌آموزان: ${widget.students.length}',
                            style: TextStyle(
                              fontFamily: 'BYekan',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.blue[200] : Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Students list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.students.length,
                    itemBuilder: (context, index) {
                      final student = widget.students[index];
                      final status = attendanceMap[student.id] ?? AttendanceStatus.absent;
                      return _buildStudentAttendanceCard(student, status);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStudentAttendanceCard(Student student, AttendanceStatus status) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            leading: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor(status),
                    _getStatusColor(status).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
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
            title: Text(
              student.fullName,
              style: TextStyle(
                fontFamily: 'BYekan',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.2,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getStatusColor(status),
                    _getStatusColor(status).withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(status),
                    style: const TextStyle(
                      fontFamily: 'BYekan',
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Status buttons (only show in edit mode)
          if (!widget.isResultMode) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      student.id,
                      'حاضر',
                      AttendanceStatus.present,
                      status,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      student.id,
                      'غایب',
                      AttendanceStatus.absent,
                      status,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      student.id,
                      'تأخیر',
                      AttendanceStatus.late,
                      status,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusButton(
                      student.id,
                      'موجه',
                      AttendanceStatus.excused,
                      status,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Notes section (only show in edit mode and for non-present status)
          if (!widget.isResultMode && status != AttendanceStatus.present)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: TextField(
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'یادداشت (اختیاری)',
                  hintText: 'دلیل غیاب یا تأخیر...',
                  labelStyle: TextStyle(
                    fontFamily: 'BYekan',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  hintStyle: TextStyle(
                    fontFamily: 'BYekan',
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  fillColor: isDark ? theme.colorScheme.surface : null,
                  filled: isDark,
                ),
                onChanged: (value) {
                  notesMap[student.id] = value;
                },
                controller: TextEditingController(
                  text: notesMap[student.id] ?? '',
                ),
              ),
            ),
          
          // Show notes in result mode (read-only)
          if (widget.isResultMode && status != AttendanceStatus.present && notesMap[student.id] != null && notesMap[student.id]!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                      ? theme.colorScheme.surface
                      : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text(
                        'یادداشت:',
                        style: TextStyle(
                          fontFamily: 'BYekan',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notesMap[student.id]!,
                        style: TextStyle(
                          fontFamily: 'BYekan',
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(
    String studentId,
    String text,
    AttendanceStatus status,
    AttendanceStatus currentStatus,
    Color color,
  ) {
    final isSelected = currentStatus == status;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          attendanceMap[studentId] = status;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected 
          ? color 
          : isDark 
            ? theme.colorScheme.surface
            : Colors.grey[100],
        foregroundColor: isSelected 
          ? Colors.white 
          : isDark
            ? theme.colorScheme.onSurface
            : color,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'BYekan',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getStatusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Icons.check_circle;
      case AttendanceStatus.absent:
        return Icons.cancel;
      case AttendanceStatus.late:
        return Icons.schedule;
      case AttendanceStatus.excused:
        return Icons.info;
    }
  }
}

