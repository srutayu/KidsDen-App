import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/themeProvider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/admin/attendance_views/view_student_attendance.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/teacher/attendance_page.dart';
import 'package:frontend/screens/teacher/classroom_details.dart';
import 'package:frontend/screens/widgets/exitDialog.dart';
import 'package:frontend/screens/widgets/teacher_drawer.dart';
import 'package:provider/provider.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  late final token = Provider.of<AuthProvider>(context, listen: false).token!;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  late final userRole =  Provider.of<UserProvider>(context, listen: false).user!.role;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final storage= FlutterSecureStorage();
  int selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ClassListScreen(authToken: token),
      ClassroomDetailsTeacher(),
      AttendancePage(),
      AttendanceView(),
    ];
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _handleBackPressed(bool didPop, Object? result) async {
    if (selectedIndex != 0) {
      setState(() {
        selectedIndex = 0;
      });
    }
    else if (selectedIndex==0){
      showLogoutConfirmation(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackPressed,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text("Teacher Dashboard"),
          centerTitle: true,
          automaticallyImplyLeading: false,
           leading: IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          backgroundColor:  Color.fromARGB(255, 52, 161, 88),
          actions: [
             Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
                onPressed: () => themeProvider.toggleTheme(),
                tooltip: 'Toggle Dark Mode',
              ),
            ),
          ],
        ),
        drawer: const TeacherDrawer(),
        body: _pages[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Class Chats'),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Students'),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'View Attendance'),
          ],
        ),
      ),
    );
  }
}
