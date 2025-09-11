import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/student/payment_page.dart';
import 'package:provider/provider.dart';

class StudentPage extends StatefulWidget {
  final String username;
  final String role;
  const StudentPage({super.key, required this.username, required this.role});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  late final token = Provider.of<AuthProvider>(context, listen:false).token;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Student Page"),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 10,),
                DrawerHeader(padding: EdgeInsets.only(top: 40),child: Text("Menu",style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),),),
                IconButton(onPressed: (){
                  // print(token);
                  AuthController.logout(token!).then((value) {
                    if(value) {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
                        return OnboardingPage();
                      },));
                    }
                    else {
                      print("Logout Failed");
                    }
                  },).catchError((error){
                    print("Logout Error : $error");
                  });
                }, icon: Icon(Icons.logout))
              ],
            ),
            GestureDetector(
              onTap: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return PaymentPage();
                },));
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Text("Make Payment", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                    SizedBox(width: 10,),
                    Icon(Icons.payment_outlined)
                  ],
                ),
              ),
            )
          ],
        ),
      ),
        body: ClassListScreen(authToken: token!, username: widget.username, role: widget.role)
    );
  }
}
