import 'package:flutter/material.dart';
import 'package:frontend/controllers/classroom_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TakeTeacherAttendance extends StatefulWidget {
  const TakeTeacherAttendance({super.key});

  @override
  State<TakeTeacherAttendance> createState() => _TakeTeacherAttendanceState();
}

class _TakeTeacherAttendanceState extends State<TakeTeacherAttendance> {
  late final String token;
  final ClassroomController _controller = ClassroomController();
  List<ClassroomModel> _teachers = [];
  Map<String, String> _attendance = {}; 
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final teachers = await _controller.getAllTeachers(token);
      setState(() {
        _teachers = teachers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load Teachers: $e');
    }
  }

   void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

   Future<void> _submitAttendance() async {
  // Optional: ensure all students marked
  final unmarked = _teachers
      .where((s) => !_attendance.containsKey(s.id))
      .toList();
  if (unmarked.isNotEmpty) {
    _showError('Please mark all students before submitting.');
    return;
  }

  final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final attendanceList = _teachers.map((teacher) {
    final status = _attendance[teacher.id] ?? 'absent';
    return {
      'userId': teacher.id,
      'status': status.toLowerCase(),
    };
  }).toList();

  setState(() => _loading = true);
  try {
    await _controller.submitAttendance(
      token: token,
      date: formattedDate,
      attendance: attendanceList,
    );

    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance submitted successfully!')),
    );
  } catch (e) {
    setState(() => _loading = false);
    _showError('Error submitting attendance: $e');
  }
}

  Widget _buildTeacherList() {
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
      
            if (_teachers.isEmpty)
              const Text('No teachers')
            else
              ..._teachers.map((teacher) {
                final status = _attendance[teacher.id];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(teacher.name)),
                      Row(
                        children: [
                            RadioGroup<String>(
                              groupValue: status,
                              onChanged: (val) {
                                setState(() {
                                  _attendance[teacher.id] = val!;
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
              const SizedBox(height: 10),
              Expanded(child: _buildTeacherList()),
              ElevatedButton(onPressed: _submitAttendance, child: Text('Submit'))
            ])));
  }
}