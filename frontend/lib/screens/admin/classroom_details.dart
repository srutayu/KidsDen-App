import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/controllers/classroom_controller.dart';
import 'package:frontend/controllers/fees_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:provider/provider.dart';



class ClassroomDetails extends StatefulWidget {
  const ClassroomDetails({super.key});

  @override
  State<ClassroomDetails> createState() => _ClassroomDetailsState();
}

class _ClassroomDetailsState extends State<ClassroomDetails> {
  late String token;
  late String userId;
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
      showToast('${teacher.name} added to ${_selectedClass?.name}');
    } catch (e) {
      _showError('Failed to add teacher: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeTeacher(ClassroomModel teacher) async {
  if (_selectedClass == null) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Deletion'),
      content: Text('Are you sure you want to remove ${teacher.name} from ${_selectedClass?.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // cancel
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true), // confirm
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  // --- Proceed with deletion ---
  setState(() => _loading = true);
  try {
    await _controller.deleteTeacher(_selectedClass!.id, teacher.id, token);
    await _loadClassMembers(_selectedClass!.id);
    showToast('${teacher.name} deleted from ${_selectedClass?.name}');
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
      showToast('${student.name} added to ${_selectedClass?.name}');
    } catch (e) {
      _showError('Failed to add student: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

Future<void> _removeStudent(ClassroomModel student) async {
  if (_selectedClass == null) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Deletion'),
      content: Text('Are you sure you want to remove ${student.name} from ${_selectedClass?.name}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // cancel
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true), // confirm
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  // --- If user cancels, stop here ---
  if (confirm != true) return;

  // --- Proceed with deletion ---
  setState(() => _loading = true);
  try {
    await _controller.deleteStudent(_selectedClass!.id, student.id, token);
    await _loadClassMembers(_selectedClass!.id);
    showToast('${student.name} deleted from ${_selectedClass?.name}');
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
                showToast('Class ${_selectedClass?.name} deleted');
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
  final TextEditingController feeController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text(
        'Create New Class',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🏫 Class name input
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              hintText: 'Enter the new class name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.class_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // 💰 Fees input
          TextField(
            controller: feeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Fees Amount',
              hintText: 'Enter the fees for this class',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final className = nameController.text.trim();
            final feeText = feeController.text.trim();

            if (className.isEmpty || feeText.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter both class name and fees'),
                ),
              );
              return;
            }

            final fee = double.tryParse(feeText);
            if (fee == null || fee < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid fee amount'),
                ),
              );
              return;
            }

            Navigator.pop(context);
            await _createClass(className, userId, fee);
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}


  Future<void> _createClass(String className, String userId, dynamic fee) async {
    setState(() => _loading = true);

    try {
      final createdBy = userId;

      await _controller.createClass(className, createdBy, token);

      // After creation, reload class list and select the new class
      final classes = await _controller.getAllClasses(token);
      setState(() {
        _classes = classes;
        if (classes.isNotEmpty) {
          _selectedClass = classes.firstWhere((c) => c.name == className, orElse: () => classes[0]);
          showToast('Class $className created');
          _loadClassMembers(_selectedClass!.id);
          // set fees for the newly created class
          FeesController.updateFeesAmountByClassId(className, fee, token);
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
            DropdownButtonHideUnderline(
              child: DropdownButton2<ClassroomModel>(
                isExpanded: true,
                value: _selectedClass,
                hint: Text(
                  'Select Class',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade400 // softer grey for dark mode
                        : Colors.grey.shade600, // darker grey for light mode
                  ),
                ),
                items: _classes.map((cls) {
                  return DropdownMenuItem(
                    value: cls,
                    child: Text(
                      cls.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
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
            
                // 🎨 Button styling
                buttonStyleData: ButtonStyleData(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFFF7F7F7),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
            
                // 📋 Dropdown menu styling
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E1E1E)
                        : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black45
                            : Colors.grey.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
            
                // ⬇️ Dropdown arrow color
                iconStyleData: IconStyleData(
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black87,
                  ),
                ),
            
                // ✨ Style for selected item
                menuItemStyleData: MenuItemStyleData(
                  overlayColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) {
                      if (states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)) {
                        return Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : Colors.black12;
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildMemberList('Teachers', _teachersInClass,
                      _teachersNotInClass, _addTeacher, _removeTeacher),
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
