import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/controllers/razorpay_controller.dart';
import 'package:frontend/models/classroom_model.dart';

import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/admin/classroom_details.dart';
import 'package:frontend/screens/admin/member_request.dart';
import 'package:frontend/screens/admin/payment_records.dart';

import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/widgets/greetingWidget.dart';


class AdminPage extends StatefulWidget {
  final String username;
  final String role;
  const AdminPage({required this.username, super.key, required this.role});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {

  late final token = Provider.of<AuthProvider>(context, listen: false).token!;
  int selectedIndex=0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    _pages=[
      ClassListScreen(authToken: token, username: widget.username, role: widget.role),
      ClassroomDetails(),
      MemberRequest(),
      CombinedFeesPaymentsPage()
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 52, 161, 88),
        title: Text('Admin Dashboard'),
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
      // body: GreetingWidget(username: widget.username),
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
          BottomNavigationBarItem(icon: Icon(Icons.room), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Fees')
        ],
      ),
    );
  }
}
