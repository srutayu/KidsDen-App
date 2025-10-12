import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:frontend/controllers/attendance_controller.dart';
import 'package:frontend/controllers/classroom_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  late final String token;
  ClassroomModel? _selectedClass;
  DateTime selectedDate= DateTime.now();
  final ClassroomController _controller = ClassroomController();
  List<ClassroomModel> _classes = [];
  bool _loading = true;
  List<Map<String, dynamic>> _attendanceList = [];


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
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

  Future<void> _getAttendanceData() async {
    final attendanceList = await AttendanceController.getAttendance(
      token: token,
      classId: _selectedClass!.id,
      date: selectedDate,
    );

    setState(() {
      _attendanceList = attendanceList;
    });
  }

  
  
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }


  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      if (_selectedClass?.id != null) {
        _getAttendanceData();
      }
  }
}

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildAdminAttendanceList() {
    // If either class or date is not selected, show placeholder
    if (_selectedClass?.id == null) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.info_outline, color: Colors.grey, size: 40),
                SizedBox(height: 8),
                Text(
                  'No data selected',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If both are selected, show attendance list
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Attendance for ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Expanded(
                    child: Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('Present',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 16),
                  Text('Absent', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(),

              // If no attendance data
              if (_attendanceList.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'No attendance data available',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._attendanceList.map((record) {
                  final name = record['name'];
                  final status = record['attendance']; // 'present' or 'absent'

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child:
                              Text(name, style: const TextStyle(fontSize: 16)),
                        ),
                        RadioGroup<String>(
                          groupValue: status,
                          onChanged: (value) {},
                          child: Row(
                            children: [
                              Radio<String>(
                                value: 'present',
                                activeColor: Colors.green,
                              ),
                              Radio<String>(
                                value: 'absent',
                                activeColor: Colors.red,
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }


  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Attendance'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 222, 219, 219),
                    spreadRadius: 1,
                    blurRadius: 2,
                    offset: const Offset(0, 2),
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
                        _getAttendanceData();
                      });
                    }
                  },
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            GestureDetector(
              onTap: () async {
                _pickDate();
                _getAttendanceData();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(255, 222, 219, 219),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.grey),
                    Text(
                      '${selectedDate.day.toString().padLeft(2, '0')} '
                      '${_monthName(selectedDate.month)} '
                      '${selectedDate.year}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        color: Color.fromARGB(255, 84, 83, 83)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ---- ATTENDANCE LIST ----
            Expanded(
              child: _buildAdminAttendanceList(),
            ),
          ],
        ),
      ),
    );
  }
}
