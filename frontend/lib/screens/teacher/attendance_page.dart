import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/controllers/attendance_controller.dart';
import 'package:frontend/controllers/teacher_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/widgets/toast_message.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String get token => Provider.of<AuthProvider>(context, listen: false).token!;
  final TeacherController _controller = TeacherController();
  List<ClassroomModel> _studentsInClass = [];
  bool _loading = true;
  List<ClassroomModel> _classes = [];
  ClassroomModel? _selectedClass;
  Map<String, String> _attendance = {}; 
  bool _attendanceTaken= false;

  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // token = Provider.of<AuthProvider>(context, listen: false).token!;
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final classes = await _controller.getAllClasses(token);
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load classes: $e');
    }
  }

  void _showError(String msg) {
    showToast(msg);
  }

  Future<void> _loadClassMembers(String classId) async {
    setState(() => _loading = true);
    _checkAttendanceStatus(classId);
    if (!_attendanceTaken) {
      try {
        final students = await _controller.getStudentsInClass(classId, token);
        setState(() {
          _studentsInClass = students;
          _loading = false;
        });
      } catch (e) {
        setState(() => _loading = false);
        _showError('Failed to load class members: $e');
      }
    }
    else{
      return;
    }
    
  }

  Future<void> _checkAttendanceStatus(String classId) async {
    setState(() => _loading = true);

    try {
      // Call your controller method
      final attendanceTaken = await AttendanceController.checkAttendance(
        token: token,
        classId: classId,
      );

      setState(() {
        _attendanceTaken = attendanceTaken; // store the result in your state
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to check attendance: $e');
    }
  }


  Future<void> _submitAttendance() async {
  // Optional: ensure all students marked
  final unmarked = _studentsInClass
      .where((s) => !_attendance.containsKey(s.id))
      .toList();
  if (unmarked.isNotEmpty) {
    _showError('Please mark all students before submitting.');
    return;
  }

  final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final attendanceList = _studentsInClass.map((student) {
    final status = _attendance[student.id] ?? 'absent';
    return {
      'userId': student.id,
      'status': status.toLowerCase(),
    };
  }).toList();

  setState(() => _loading = true);
  try {
    await _controller.submitAttendance(
      token: token,
      classId: _selectedClass!.id,
      date: formattedDate,
      attendance: attendanceList,
    );

    setState(() => _loading = false);
    showToast('Attendance for ${DateFormat('dd-MM-yyyy').format(DateTime.now())} submitted!');
  } catch (e) {
    setState(() => _loading = false);
    _showError('Error submitting attendance: $e');
  }
}



Widget _buildStudentList() {
  if (_attendanceTaken) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      child: SizedBox(
        height: 250,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cancel_rounded,
                color: Colors.redAccent,
                size: 64,
              ),
              SizedBox(height: 12),
              Text(
  'Attendance already taken for',
  textAlign: TextAlign.center,
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87,
  ),
)
            ],
          ),
        ),
      ),
    );
  }

  return Card(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance for ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
      
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Expanded(child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('Present', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 16),
                Text('Absent', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
      
            if (_studentsInClass.isEmpty)
              const Text('No students in this class')
            else
              ..._studentsInClass.map((student) {
                final status = _attendance[student.id];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(student.name)),
                      Row(
                        children: [
                            RadioGroup<String>(
                              groupValue: status,
                              onChanged: (val) {
                                setState(() {
                                  _attendance[student.id] = val!;
                                });
                              },
                              child: Row(
                                children: [
                                  Radio<String>(value: 'Present', activeColor: Colors.green,),
                                  Radio<String>(value: 'Absent', activeColor: Colors.red,),
                                ],
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              Center(
                child: ElevatedButton(
                    onPressed: _submitAttendance, child: Text('Submit')),
              )
            ],
          ),
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
            child: Column(children: [
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
              Expanded(child: _buildStudentList()),
            ])));
  }
}
