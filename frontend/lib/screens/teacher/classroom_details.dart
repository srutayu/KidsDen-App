import 'package:flutter/material.dart';
import 'package:frontend/controllers/teacher_controller.dart'; // TeacherController file
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ClassroomDetailsTeacher extends StatefulWidget {
  const ClassroomDetailsTeacher({super.key});

  @override
  State<ClassroomDetailsTeacher> createState() =>
      _ClassroomDetailsTeacherState();
}

class _ClassroomDetailsTeacherState extends State<ClassroomDetailsTeacher> {
  late final String token;
  final TeacherController _controller = TeacherController();

  List<ClassroomModel> _classes = [];
  ClassroomModel? _selectedClass;

  List<ClassroomModel> _studentsInClass = [];
  List<ClassroomModel> _studentsNotInClass = [];

  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    _initializeData();
  }

Future<void> _initializeData() async {
  try {
    final classes = await _controller.getAllClasses(token);

    if (!mounted) return; 

    if (classes.isNotEmpty) {
      _selectedClass = classes[0];
      await _loadClassMembers(_selectedClass!.id);

      if (!mounted) return; 
    }

    setState(() {
      _classes = classes;
      _loading = false;
    });
  } catch (e) {
    if (mounted) {
      setState(() => _loading = false);
      _showError('Failed to load classes: $e');
    }
  }
}


  Future<void> _loadClassMembers(String classId) async {
    setState(() => _loading = true);
    try {
      final students = await _controller.getStudentsInClass(classId, token);
      final studentsNotIn =
          await _controller.getStudentsNotInClass(classId, token);

      setState(() {
        _studentsInClass = students;
        _studentsNotInClass = studentsNotIn;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load class members: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addStudent(ClassroomModel student) async {
    if (_selectedClass == null) return;
    setState(() => _loading = true);
    try {
      await _controller.addStudents(_selectedClass!.id, [student.id], token);
      await _loadClassMembers(_selectedClass!.id);
    } catch (e) {
      _showError('Failed to add student: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _removeStudent(ClassroomModel student) async {
    if (_selectedClass == null) return;
    setState(() => _loading = true);
    try {
      await _controller.deleteStudent(_selectedClass!.id, student.id, token);
      await _loadClassMembers(_selectedClass!.id);
    } catch (e) {
      _showError('Failed to remove student: $e');
      setState(() => _loading = false);
    }
  }

  void _showAddStudentDialog() {
    ClassroomModel? selected;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Student'),
              content: DropdownButton<ClassroomModel>(
                isExpanded: true,
                value: selected,
                hint: const Text('Select Student to add'),
                items: _studentsNotInClass.map((student) {
                  return DropdownMenuItem(
                    value: student,
                    child: Text(student.name),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selected = val;
                  });
                },
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () {
                          _addStudent(selected!);
                          Navigator.pop(context);
                        },
                  child: const Text('Add'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStudentList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Students',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _studentsNotInClass.isEmpty
                      ? null
                      : _showAddStudentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Student'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_studentsInClass.isEmpty)
              const Text('No students in this class')
            else
              ..._studentsInClass.map((student) => ListTile(
                    title: Text(student.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeStudent(student),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<ClassroomModel>(
              isExpanded: true,
              value: _selectedClass,
              hint: const Text('Select Class'),
              items: _classes.map((cls) {
                return DropdownMenuItem(
                  value: cls,
                  child: Text(cls.name),
                );
              }).toList(),
              onChanged: (cls) {
                if (cls != null) {
                  setState(() {
                    _selectedClass = cls;
                  });
                  _loadClassMembers(cls.id);
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
    );
  }
}
