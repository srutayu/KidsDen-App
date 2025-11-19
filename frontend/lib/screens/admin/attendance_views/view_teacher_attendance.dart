import 'package:flutter/material.dart';
import 'package:frontend/controllers/attendance_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ViewTeacherAttendance extends StatefulWidget {
  const ViewTeacherAttendance({super.key});

  @override
  State<ViewTeacherAttendance> createState() => _ViewTeacherAttendanceState();
}

class _ViewTeacherAttendanceState extends State<ViewTeacherAttendance> {
  late final String token;
  DateTime selectedDate= DateTime.now();
  List<Map<String, dynamic>> _attendanceList = [];
  bool _loading = false;


  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    token = Provider.of<AuthProvider>(context, listen: false).token!;
    _getAttendanceData();
  }

   Future<void> _getAttendanceData() async {
    final attendanceList = await AttendanceController.getTeacherAttendance(
      token: token,
      date: selectedDate,
    );

    setState(() {
      _attendanceList = attendanceList;
    });
  }

  
  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      _getAttendanceData();
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [

            const SizedBox(height: 16),

            GestureDetector(
  onTap: () async {
    _pickDate();
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A) // dark mode background
          : Colors.white, // light mode background
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade300,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(
          Icons.calendar_today,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade400
              : Colors.grey.shade600,
        ),
        Text(
          '${selectedDate.day.toString().padLeft(2, '0')} '
          '${_monthName(selectedDate.month)} '
          '${selectedDate.year}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        Icon(
          Icons.arrow_drop_down_rounded,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.grey.shade800,
        ),
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
