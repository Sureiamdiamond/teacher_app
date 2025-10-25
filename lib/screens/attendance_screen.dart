import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../services/data_service.dart';

class AttendanceScreen extends StatefulWidget {
  final List<Student> students;
  final DateTime selectedDate;

  const AttendanceScreen({
    super.key,
    required this.students,
    required this.selectedDate,
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
    return '${jalali.day} ${months[jalali.month - 1]} ${jalali.year}';
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'ثبت حضور و غیاب',
          style: TextStyle(
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
              child: const Text(
                'ذخیره',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 32,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getPersianDate(widget.selectedDate),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'تعداد دانش‌آموزان: ${widget.students.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
              backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
              child: Text(
                student.studentNumber,
                style: TextStyle(
                  color: _getStatusColor(status),
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
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Text(
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          // Status buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          
          // Notes section
          if (status != AttendanceStatus.present)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'یادداشت (اختیاری)',
                  hintText: 'دلیل غیاب یا تأخیر...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (value) {
                  notesMap[student.id] = value;
                },
                controller: TextEditingController(
                  text: notesMap[student.id] ?? '',
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
    return ElevatedButton(
      onPressed: () {
        setState(() {
          attendanceMap[studentId] = status;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[100],
        foregroundColor: isSelected ? Colors.white : color,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
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
