import 'package:flutter/material.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/models/classroom_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/onboarding_page.dart';
import 'package:frontend/screens/chat/classlist.dart';
import 'package:frontend/screens/teacher/classroom_details.dart';
import 'package:provider/provider.dart';

// import '../chat/classlist.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  late final token = Provider.of<AuthProvider>(context, listen:false).token;
  late final userId = Provider.of<UserProvider>(context, listen: false).user!.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Teachers Page"),),
        drawer: Drawer(
          child: Column(
            children: [
              Row(
                children: [
                  DrawerHeader(padding: EdgeInsets.only(top: 40),child: Text("Menu",style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),),),
                  SizedBox(width: 30,),
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
                    return ClassroomDetailsTeacher();
                  },));
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Text("Classroom Details", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),),
                      SizedBox(width: 10,),
                      Icon(Icons.school)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        body: ClassListScreen(authToken: token!),
    );
  }
}

