import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../services/data_service.dart';
import 'add_class_screen.dart';
import 'edit_class_screen.dart';
import 'class_home_screen.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  List<ClassModel> classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final loadedClasses = await DataService.getClasses();
    setState(() {
      classes = loadedClasses;
    });
  }

  Future<void> _addClass() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddClassScreen()),
    );
    if (result == true) {
      _loadClasses();
    }
  }

  Future<void> _editClass(ClassModel classModel) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditClassScreen(classModel: classModel),
      ),
    );
    if (result == true) {
      _loadClasses();
    }
  }

  Future<void> _deleteClass(ClassModel classModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف کلاس'),
        content: Text('آیا از حذف کلاس "${classModel.name}" اطمینان دارید؟'),
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
      await DataService.deleteClass(classModel.id);
      _loadClasses();
    }
  }

  Future<void> _deleteAllClasses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تمام کلاس‌ها'),
        content: const Text('آیا از حذف تمام کلاس‌ها اطمینان دارید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف همه', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DataService.deleteAllClasses();
      _loadClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
        ),
        title: const Text('مدیریت کلاس‌ها'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (classes.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_all') {
                  _deleteAllClasses();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف تمام کلاس‌ها'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.class_,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'هیچ کلاسی تعریف نشده است',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'برای شروع، کلاس جدیدی اضافه کنید',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final classModel = classes[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Icon(
                        Icons.class_,
                        color: Colors.blue[700],
                      ),
                    ),
                    title: Text(
                      classModel.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      classModel.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editClass(classModel);
                        } else if (value == 'delete') {
                          _deleteClass(classModel);
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
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClassHomeScreen(classModel: classModel),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClass,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
