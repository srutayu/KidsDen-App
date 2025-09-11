// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/approval_pending.dart';
import 'package:frontend/screens/auth/signup_page.dart';
import 'package:frontend/screens/users/admin_page.dart';
import 'package:frontend/screens/users/student_page.dart';
import 'package:frontend/screens/users/teacher_page.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 195, 244, 205),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'app-logo',
                      child: Image.asset(
                        'assets/logo.png',
                        width: 300,
                        height: 300,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _email,
                      decoration: InputDecoration(
                        labelText: 'Email ID',
                        filled: true,
                        fillColor: Colors.grey[200],
                        prefixIcon: Icon(Icons.email),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.teal, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      obscureText: _obscureText,
                      controller: _password,
                      decoration: InputDecoration(
                        fillColor: Colors.grey[200],
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: () async {
                        try {
                          bool isApproved =
                              await AuthController.checkIfAproved(_email.text);
                      
                          if (!isApproved) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ApprovalPending()),
                            );
                            return;
                          }
                      
                          final loginResponse = await AuthController.login(
                            _email.text,
                            _password.text,
                          );
                      
                          String? role = loginResponse?.user.role;
                          String? token = loginResponse?.token;
                      
                          Provider.of<AuthProvider>(context, listen: false)
                              .setToken(token!);
                          Provider.of<UserProvider>(context, listen: false)
                              .fetchUserDetails(_email.text, token);

                          final String username = Provider.of<UserProvider>(context, listen: false).user!.name;
                      
                          if (role == 'admin') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => AdminPage(username: username, role: role!)),
                            );
                          } else if (role == 'teacher') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => TeacherPage(username: username, role: role!)),
                            );
                          } else if (role == 'student') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => StudentPage(username: username, role: role!)),
                            );
                          }
                        } catch (e) {
                          Fluttertoast.showToast(
                            msg: e.toString().replaceFirst("Exception: ", ""),
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            textColor: Colors.white,
                            fontSize: 16.0,
                          );
                        }
                      }, child: Text('Login')),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) {
                            return SignUpPage();
                          },)
                        );
                      },
                      child: Text(
                        'Not registered? Sign up.',
                        style: TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
