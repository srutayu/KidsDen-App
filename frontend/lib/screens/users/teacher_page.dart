import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/teacher/attendance_page.dart';
import 'package:frontend/screens/teacher/classroom_details.dart';
import 'package:provider/provider.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  late final token = Provider.of<AuthProvider>(context, listen: false).token!;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;
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
    ];
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    try {
      await storage.deleteAll();
      final value = await AuthController.logout(token);
      if (value) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingPage(),
          ),
        );
      } else {
        print("Logout Failed");
      }
    } catch (error) {
      print("Logout Error: $error");
    }
  }
  Future<void> _handleBackPressed(bool didPop, Object? result) async {
    if (selectedIndex == 1 || selectedIndex == 2 ) {
      setState(() {
        selectedIndex = 0;
      });
    }
    else if (selectedIndex==0){
      _handleLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackPressed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Teacher Dashboard"),
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 52, 161, 88),
          actions: [
            IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: _pages[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Class Chats'),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Students'),
            BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Attendance'),
          ],
        ),
      ),
    );
  }
}
