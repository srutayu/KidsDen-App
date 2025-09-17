import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/student/payment_page.dart';
import 'package:provider/provider.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key });

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  late final token = Provider.of<AuthProvider>(context, listen:false).token!;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  int selectedIndex=0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    _pages=[
      ClassListScreen(authToken: token),
      PaymentPage()
    ];
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 52, 161, 88),
        title: Text('Student Dashboard'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              onPressed: () async {
                try {
                  final value = await AuthController.logout(token);
                  if (value) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnboardingPage(),
                      ),
                    );
                  } else {
                    print("Logout Failed");
                  }
                } catch (error) {
                  print("Logout Error: $error");
                }
              },
              icon: Icon(Icons.logout))
        ],
      ),
      body:_pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            selectedIndex=index; 
          });
        },
        currentIndex: selectedIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Classes'),
        ],
      ),
    );
  }
}
