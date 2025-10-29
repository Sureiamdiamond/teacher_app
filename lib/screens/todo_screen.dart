import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import '../models/todo_item.dart';
import '../services/data_service.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  DateTime selectedDate = DateTime.now();
  List<TodoItem> todos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    setState(() => isLoading = true);
    final loadedTodos = await DataService.getTodosForDate(selectedDate);
    setState(() {
      todos = loadedTodos;
      // Sort by creation time or keep order
      todos.sort((a, b) => a.id.compareTo(b.id));
      isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    final oneYearAhead = now.add(const Duration(days: 365));
    
    final date = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(selectedDate),
      firstDate: Jalali.fromDateTime(oneYearAgo),
      lastDate: Jalali.fromDateTime(oneYearAhead),
      builder: (context, child) {
        final isDark = _isDarkMode(context);
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
      await _loadTodos();
    }
  }

  String _getPersianDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final persianMonths = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    
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

  Future<void> _addTodo() async {
    if (todos.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('حداکثر 8 مورد می‌توانید اضافه کنید'),
          backgroundColor: Colors.red[600],
        ),
      );
      return;
    }

    final TextEditingController controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text(
            'افزودن یادداشت',
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
          ),
          content: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'متن یادداشت',
              labelStyle: TextStyle(color: _isDarkMode(context) ? Colors.white70 : Colors.black87),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('افزودن'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final newTodo = TodoItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: controller.text.trim(),
        isCompleted: false,
        date: selectedDate,
      );
      
      await DataService.addTodo(newTodo);
      await _loadTodos();
    }
  }

  Future<void> _editTodo(TodoItem todo) async {
    final TextEditingController controller = TextEditingController(text: todo.text);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text(
            'ویرایش یادداشت',
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
          ),
          content: TextField(
            controller: controller,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'متن یادداشت',
              labelStyle: TextStyle(color: _isDarkMode(context) ? Colors.white70 : Colors.black87),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لغو'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('ذخیره'),
            ),
          ],
        ),
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty) {
      final updatedTodo = todo.copyWith(text: controller.text.trim());
      await DataService.updateTodo(updatedTodo);
      await _loadTodos();
    }
  }

  Future<void> _toggleTodo(TodoItem todo) async {
    final updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
    await DataService.updateTodo(updatedTodo);
    await _loadTodos();
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _isDarkMode(context) ? Colors.grey[800] : Colors.white,
          title: Text(
            'حذف یادداشت',
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
          ),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید این یادداشت را حذف کنید؟',
            style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
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
      await DataService.deleteTodo(todo.id);
      await _loadTodos();
    }
  }

  bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _isDarkMode(context);
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white70 : Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          'فهرست کارها',
          style: TextStyle(fontWeight: FontWeight.bold , color: Colors.white , fontSize: 20),
        ),
        backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[700],
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date selector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: isDarkMode ? Colors.grey[900] : Colors.blue[50],
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          final previousDay = selectedDate.subtract(const Duration(days: 1));
                          setState(() {
                            selectedDate = previousDay;
                          });
                          _loadTodos();
                        },
                        icon: Icon(Icons.chevron_left, color: isDarkMode ? Colors.white : Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[100],
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
                              color: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDarkMode ? Colors.black45 : Colors.blue[300]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today, color: isDarkMode ? Colors.white : Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text(
                                  _getPersianDate(selectedDate),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, color: isDarkMode ? Colors.white : Colors.blue[700]),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          final nextDay = selectedDate.add(const Duration(days: 1));
                          setState(() {
                            selectedDate = nextDay;
                          });
                          _loadTodos();
                        },
                        icon: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white : Colors.blue[700]),
                        style: IconButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.blue[900] : Colors.blue[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Todo list
                Expanded(
                  child: todos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.checklist_outlined,
                                size: 64,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'هیچ یادداشتی برای این تاریخ ثبت نشده است',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: todos.length,
                          itemBuilder: (context, index) {
                            final todo = todos[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08),
                                    spreadRadius: 0,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Directionality(
                                textDirection: TextDirection.rtl,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      // Checkbox (rightmost)
                                      Checkbox(
                                        value: todo.isCompleted,
                                        onChanged: (value) => _toggleTodo(todo),
                                        activeColor: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 12),
                                      // Text (middle)
                                      Expanded(
                                        child: Text(
                                          todo.text,
                                          style: TextStyle(
                                            fontFamily: 'BYekan',
                                            fontSize: 16,
                                            color: isDarkMode ? Colors.white : Colors.black,
                                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.grey,
                                          ),
                                          textDirection: TextDirection.rtl,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Three dots menu (leftmost)
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white70 : Colors.black54),
                                        color: isDarkMode ? Colors.grey[850] : Colors.white,
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _editTodo(todo);
                                          } else if (value == 'delete') {
                                            _deleteTodo(todo);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit, size: 20, color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'ویرایش',
                                                  style: TextStyle(color: _isDarkMode(context) ? Colors.white : Colors.black),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete, size: 20, color: Colors.red),
                                                const SizedBox(width: 8),
                                                const Text('حذف', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Add button
                if (todos.length < 6)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: _addTodo,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'افزودن یادداشت',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'حداکثر ۶ مورد می‌توانید اضافه کنید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

