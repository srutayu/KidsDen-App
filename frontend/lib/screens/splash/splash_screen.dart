import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/controllers/user_details_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/users/admin_page.dart';
import 'package:frontend/screens/users/student_page.dart';
import 'package:frontend/screens/users/teacher_page.dart';
import 'package:provider/provider.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    String? token = await storage.read(key: 'token');
    String? email = await storage.read(key: 'email');


    if (token == null) {
      // No token → send to Onboarding
      _goTo(const OnboardingPage());
      return;
    }

    try {
      // API call to fetch role from token
      Provider.of<AuthProvider>(context, listen: false).setToken(token);
      Provider.of<UserProvider>(context, listen: false).fetchUserDetails(email!, token);
      final roleResponse = await UserDetailController.getRoleFromToken(token);
      final role= roleResponse.role;

      if (role == "admin") {
        _goTo(const AdminPage());
      } else if (role == "teacher") {
        _goTo(const TeacherPage());
      } else if (role == "student") {
        _goTo(const StudentPage());
      } else {
        _goTo(const OnboardingPage()); // fallback
      }
    } catch (e) {
      await storage.deleteAll();
      _goTo(const OnboardingPage());
    }
  }

  void _goTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), 
      ),
    );
  }
}
