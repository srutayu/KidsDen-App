import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/admin/update/broadcast/daily_update.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/admin/update/broadcast/broadcast_screen.dart';
import 'package:provider/provider.dart';

class TeacherDrawer extends StatefulWidget {
  const TeacherDrawer({super.key});

  @override
  State<TeacherDrawer> createState() => _TeacherDrawerState();
}

class _TeacherDrawerState extends State<TeacherDrawer> {
  final storage= FlutterSecureStorage();
  late String token = Provider.of<AuthProvider>(context, listen: false).token!;
  late String userId = Provider.of<UserProvider>(context, listen: false).user!.id;
  late String role = Provider.of<UserProvider>(context, listen: false).user!.role;

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // removes default top padding
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/drawerImage.png'),
                fit: BoxFit.cover, // makes it fill the entire header
              ),
            ),
            child: Container(), // empty child (optional)
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // closes the drawer
            },
          ),
         ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Daily Update'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyClassUpdatePage(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Broadcast'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BroadcastScreen(authToken: token,userId: userId, userRole: role),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              _handleLogout();
            },
          ),
        ],
      ),
    );
  }
}
