import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
                        fillColor: Colors.grey[200],
                        prefixIcon: Icon(Icons.email),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
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

// // ✉️ Email Field
// TextField(
//   controller: _email,
//   keyboardType: TextInputType.emailAddress,
//   decoration: InputDecoration(
//     labelText: 'Email ID',
//     prefixIcon: const Icon(Icons.email),
//     filled: true,
//     fillColor: Colors.grey[200],
//     contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//     border: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: BorderSide.none, // removes default grey line
//     ),
//     enabledBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: const BorderSide(color: Colors.grey),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: const BorderSide(color: Colors.teal, width: 2),
//     ),
//   ),
// ),

// const SizedBox(height: 20),

// // 🔒 Password Field
// TextField(
//   controller: _password,
//   obscureText: _obscureText,
//   decoration: InputDecoration(
//     labelText: 'Password',
//     prefixIcon: const Icon(Icons.lock),
//     suffixIcon: IconButton(
//       icon: Icon(
//         _obscureText ? Icons.visibility : Icons.visibility_off,
//       ),
//       onPressed: () {
//         setState(() {
//           _obscureText = !_obscureText;
//         });
//       },
//     ),
//     filled: true,
//     fillColor: Colors.grey[200],
//     contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//     border: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: BorderSide.none,
//     ),
//     enabledBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: const BorderSide(color: Colors.grey),
//     ),
//     focusedBorder: OutlineInputBorder(
//       borderRadius: BorderRadius.circular(20),
//       borderSide: const BorderSide(color: Colors.teal, width: 2),
//     ),
//   ),
// ),

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

                          final storage= const FlutterSecureStorage();
                      
                          Provider.of<AuthProvider>(context, listen: false)
                              .setToken(token!);
                          await storage.write(key: 'token', value:  token);
                          Provider.of<UserProvider>(context, listen: false)
                              .fetchUserDetails(_email.text, token);
                          await storage.write(key: 'email', value: _email.text);
                      
                          if (role == 'admin') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => AdminPage()),
                            );
                          } else if (role == 'teacher') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => TeacherPage()),
                            );
                          } else if (role == 'student') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => StudentPage()),
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
