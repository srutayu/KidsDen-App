import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/controllers/classroom_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:provider/provider.dart';



class ClassroomDetails extends StatefulWidget {
  const ClassroomDetails({super.key});

  @override
  State<ClassroomDetails> createState() => _ClassroomDetailsState();
}

class _ClassroomDetailsState extends State<ClassroomDetails> {
  late final String token;
  late final String userId;
  final ClassroomController _controller = ClassroomController();

  List<ClassroomModel> _classes = [];
  ClassroomModel? _selectedClass;

  List<ClassroomModel> _teachersInClass = [];
  List<ClassroomModel> _studentsInClass = [];

  List<ClassroomModel> _teachersNotInClass = [];
  List<ClassroomModel> _studentsNotInClass = [];

  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    userId = Provider.of<UserProvider>(context, listen: false).user!.id;

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final classes = await _controller.getAllClasses(token);
      if (classes.isNotEmpty) {
        _selectedClass = classes[0];
        await _loadClassMembers(_selectedClass!.id);
      }
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load classes: $e');
    }
  }

Future<void> _loadClassMembers(String classId) async {
  if (!mounted) return;
  setState(() => _loading = true);

  try {
    final teachers = await _controller.getTeacherInClass(classId, token);
    final students = await _controller.getStudentsInClass(classId, token);
    final teachersNotIn = await _controller.getTeachersNotInClass(classId, token);
    final studentsNotIn = await _controller.getStudentsNotInClass(classId, token);

    if (!mounted) return; // ensure widget is still active before setState
    setState(() {
      _teachersInClass = teachers;
      _studentsInClass = students;
      _teachersNotInClass = teachersNotIn;
      _studentsNotInClass = studentsNotIn;
      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    _showError('Failed to load class members: $e');
  }
}


  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addTeacher(ClassroomModel teacher) async {
    if (_selectedClass == null) return;
    setState(() => _loading = true);
    try {
      await _controller.addTeachers(_selectedClass!.id, [teacher.id], token);
      await _loadClassMembers(_selectedClass!.id);
    } catch (e) {
      _showError('Failed to add teacher: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeTeacher(ClassroomModel teacher) async {
    if (_selectedClass == null) return;
    setState(() => _loading = true);
    try {
      await _controller.deleteTeacher(_selectedClass!.id, teacher.id, token);
      await _loadClassMembers(_selectedClass!.id);
    } catch (e) {
      _showError('Failed to remove teacher: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addStudent(ClassroomModel student) async {
    if (_selectedClass == null) return;
    setState(() => _loading = true);
    try {
      await _controller.addStudents(_selectedClass!.id, [student.id], token);
      await _loadClassMembers(_selectedClass!.id);
    } catch (e) {
      _showError('Failed to add student: $e');
    } finally {
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
    } finally {
      setState(() => _loading = false);
    }
  }

  void _confirmDeleteClass() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Class'),
          content: Text('Are you sure you want to delete class "${_selectedClass!.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteClass();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
  Future<void> _deleteClass() async {
    if (_selectedClass == null) return;

    setState(() => _loading = true);

    try {
      await _controller.deleteClass(_selectedClass!.id, token);

      // Reload classes list after deletion
      final classes = await _controller.getAllClasses(token);
      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) {
          _selectedClass = classes[0];
          _loadClassMembers(_selectedClass!.id);
        } else {
          _selectedClass = null;
          _teachersInClass = [];
          _studentsInClass = [];
          _teachersNotInClass = [];
          _studentsNotInClass = [];
        }
      });
    } catch (e) {
      _showError('Failed to delete class: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showCreateClassDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Class'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'Enter the new class name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final className = nameController.text.trim();
                if (className.isNotEmpty) {
                  Navigator.pop(context);
                  await _createClass(className, userId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Class name cannot be empty')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createClass(String className, String userId) async {
    setState(() => _loading = true);

    try {
      // You need to set createdBy, you can get admin userId from AuthProvider or pass a param
      final createdBy = userId; // TODO: Replace with actual logged-in admin ID
      print("createdBy $createdBy");
      print("className $className");
      print("userId: $userId");

      await _controller.createClass(className, createdBy, token);

      // After creation, reload class list and select the new class
      final classes = await _controller.getAllClasses(token);
      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) {
          // Optionally select the new class by name or last inserted
          _selectedClass = classes.firstWhere((c) => c.name == className, orElse: () => classes[0]);
          _loadClassMembers(_selectedClass!.id);
        }
      });
    } catch (e) {
      _showError('Failed to create class: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showAddDialog(String title, List<ClassroomModel> candidates, Function(ClassroomModel) onAdd) {
    ClassroomModel? selected;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add $title'),
              content: DropdownButton<ClassroomModel>(
                isExpanded: true,
                value: selected,
                hint: Text('Select $title to add'),
                items: candidates.map((c) {
                  return DropdownMenuItem<ClassroomModel>(
                    value: c,
                    child: Text(c.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selected = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selected == null
                      ? null
                      : () {
                    onAdd(selected!);
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }




  Widget _buildMemberList(String title, List<ClassroomModel> members, List<ClassroomModel> candidates,
      Function(ClassroomModel) onAdd, Function(ClassroomModel) onRemove) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: candidates.isEmpty ? null : () => _showAddDialog(title, candidates, onAdd),
                icon: const Icon(Icons.add),
                label: Text('Add $title'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            Text('No $title found')
          else
            ...members.map(
                  (m) => ListTile(
                title: Text(m.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    if (title.toLowerCase() == 'teachers') {
                      _removeTeacher(m);
                    } else {
                      _removeStudent(m);
                    }
                  },
                ),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Classroom Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Class',
            onPressed: _showCreateClassDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Class',
            onPressed: _selectedClass == null ? null : _confirmDeleteClass,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 236, 242, 240),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 219, 218, 218),
                      spreadRadius: 1,
                      blurRadius: 1,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<ClassroomModel>(
                    isExpanded: true,
                    value: _selectedClass,
                    hint: const Text(
                      'Select Class',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    items: _classes.map((cls) {
                      return DropdownMenuItem(
                        value: cls,
                        child: Text(
                          cls.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
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
                    dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMemberList('Teachers', _teachersInClass, _teachersNotInClass, _addTeacher, _removeTeacher),
                  const SizedBox(height: 20),
                  _buildMemberList('Students', _studentsInClass, _studentsNotInClass, _addStudent, _removeStudent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
