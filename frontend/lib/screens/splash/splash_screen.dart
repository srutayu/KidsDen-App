import 'dart:async';
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
import 'package:shimmer/shimmer.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final storage = const FlutterSecureStorage();
  bool _apiDone = false;
  bool _minTimeDone = false;
  String? _pendingRole;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Minimum splash duration (3s)
    Future.delayed(const Duration(seconds: 3), () {
      _minTimeDone = true;
      _decideNextPage();
    });

    // Run API/auth check in background
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await storage.read(key: 'token');
    final email = await storage.read(key: 'email');

    if (token == null) {
      _apiDone = true;
      _decideNextPage();
      return;
    }

    try {
      Provider.of<AuthProvider>(context, listen: false).setToken(token);
      await Provider.of<UserProvider>(context, listen: false)
          .fetchUserDetails(email!, token);

      final roleResponse = await UserDetailController.getRoleFromToken(token);
      final role = roleResponse.role;
      _pendingRole = role;

      _apiDone = true;
      _decideNextPage();
    } catch (e) {
      await storage.deleteAll();
      _apiDone = true;
      _pendingRole = null;
      _decideNextPage();
    }
  }

  void _decideNextPage() {
    if (!_apiDone || !_minTimeDone) return; // Wait until both are done

    final role = _pendingRole;
    if (role == "admin") {
      _goTo(const AdminPage());
    } else if (role == "teacher") {
      _goTo(const TeacherPage());
    } else if (role == "student") {
      _goTo(const StudentPage());
    } else {
      _goTo(const OnboardingPage());
    }
  }

  void _goTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
    void dispose(){
      _animationController.dispose();
      super.dispose();
    }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Shimmering logo
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.05).animate(
                CurvedAnimation(
                    parent: _animationController, curve: Curves.easeInOut),
              ),
              child: Image.asset(
                "assets/logo_white.png",
                height: 120,
              ),
            ),
            const SizedBox(height: 20),

// Shimmering school name
            Shimmer.fromColors(
              baseColor: Colors.black87,
              highlightColor: Colors.grey.shade400,
              child: const Text(
                "Kids Den",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFPro',
                  letterSpacing: 1.2
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
