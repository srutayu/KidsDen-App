import 'package:flutter/material.dart';
import 'package:frontend/screens/admin/attendance_views/students_attendance_view.dart';
import 'package:frontend/screens/admin/attendance_views/take_teacher_attendance.dart';
import 'package:frontend/screens/admin/attendance_views/view_teacher_attendance.dart';

class AdminAttendance extends StatefulWidget {
  const AdminAttendance({super.key});

  @override
  State<AdminAttendance> createState() => _AdminAttendanceState();
}

class _AdminAttendanceState extends State<AdminAttendance> {
  int selectedIndex=0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    _pages=[
      AttendanceView(),
      TakeTeacherAttendance(),
      ViewTeacherAttendance()
    
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Views'),
        centerTitle: true,
      ),
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              selectedIndex=index; 
            });
          },
          currentIndex: selectedIndex,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.child_care), label: 'Student'),
            BottomNavigationBarItem(icon: Icon(Icons.girl), label: 'Record for Teacher'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'View for Teacher'),
          ],
        ),
    );
  }
}