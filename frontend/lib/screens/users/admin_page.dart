import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/screens/admin/classroom_details.dart';
import 'package:frontend/screens/admin/member_request.dart';
import 'package:frontend/screens/admin/payment_records.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/widgets/drawer.dart';
import 'package:frontend/screens/widgets/exitDialog.dart';
import 'package:provider/provider.dart';


class AdminPage extends StatefulWidget {
  const AdminPage({ super.key });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final token = Provider.of<AuthProvider>(context, listen: false).token!;
  int selectedIndex=0;
  late List<Widget> _pages;
  final storage= FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    
    _pages=[
      ClassListScreen(authToken: token),
      ClassroomDetails(),
      MemberRequest(),
      CombinedFeesPaymentsPage(),
    ];
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
    if (selectedIndex == 1 || selectedIndex == 2 || selectedIndex == 3) {
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
          backgroundColor: const Color.fromARGB(255, 52, 161, 88),
          title: Text('Admin Dashboard'),
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ),
        drawer: const MyDrawer(),
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
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Classes'),
            BottomNavigationBarItem(icon: Icon(Icons.person_add), label: 'Requests'),
            BottomNavigationBarItem(icon: Icon(Icons.money), label: 'Fees'),
          ],
        ),
      ),
    );
  }
}
