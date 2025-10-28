import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/themeProvider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/student/payment_page.dart';
import 'package:frontend/screens/widgets/exitDialog.dart';
import 'package:provider/provider.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  late final token = Provider.of<AuthProvider>(context, listen: false).token!;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  int selectedIndex = 0;
  final storage = FlutterSecureStorage();
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [ClassListScreen(authToken: token), PaymentPage()];
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
    if (selectedIndex == 1) {
      // If on second page, go back to first page
      setState(() {
        selectedIndex = 0;
      });
    }
    else if (selectedIndex==0){
      showLogoutConfirmation(context);
    }
    // Otherwise, let the system handle the back (e.g., exit app)
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleBackPressed,
      child: Scaffold(
        appBar: AppBar(
          leading: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
                onPressed: themeProvider.toggleTheme,
                tooltip: 'Toggle Dark Mode',
              ),
            ),
          backgroundColor: const Color.fromARGB(255, 52, 161, 88),
          title: Text('Student Dashboard'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                onPressed: _handleLogout, icon: Icon(Icons.logout)),
          ],
        ),
        body: _pages[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          currentIndex: selectedIndex,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Class Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Pay Fees'),
          ],
        ),
      ),
    );
  }
}
