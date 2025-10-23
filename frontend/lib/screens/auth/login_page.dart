import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/auth/approval_pending.dart';
import 'package:frontend/screens/auth/signup_page.dart';
import 'package:frontend/screens/auth/change_password.dart';
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
                              if (_email.text.trim() == '' ||
                                  _password.text.trim() == '') {
                                Fluttertoast.showToast(
                                  msg: 'Empty email/password fields',
                                  fontSize: 16.0,
                                );
                                return;
                              }
                              // 1️⃣ Attempt login first — validates user existence and password
                              final loginResponse = await AuthController.login(
                                _email.text.trim(),
                                _password.text.trim(),
                              );

                              if (loginResponse == null) {
                                Fluttertoast.showToast(
                                  msg: 'Invalid email or password',
                                  fontSize: 16.0,
                                );
                                return;
                              }

                              // 2️⃣ Now safely check if user is approved
                              bool isApproved =
                                  await AuthController.checkIfAproved(
                                      _email.text.trim());

                              if (!isApproved) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ApprovalPending()),
                                );
                                return;
                              }

                              // 3️⃣ Extract token, role, and other details
                              String? role = loginResponse.user.role;
                              String? token = loginResponse.token;

                              final storage = const FlutterSecureStorage();

                              // 4️⃣ Save token and email
                              Provider.of<AuthProvider>(context, listen: false)
                                  .setToken(token);
                              await storage.write(key: 'token', value: token);
                              await storage.write(
                                  key: 'email', value: _email.text.trim());

                              // 5️⃣ Fetch user details via provider
                              Provider.of<UserProvider>(context, listen: false)
                                  .fetchUserDetails(_email.text.trim(), token);

                              // 6️⃣ Navigate based on role
                              Widget targetPage;
                              switch (role) {
                                case 'admin':
                                  targetPage = AdminPage();
                                  break;
                                case 'teacher':
                                  targetPage = TeacherPage();
                                  break;
                                case 'student':
                                  targetPage = StudentPage();
                                  break;
                                default:
                                  Fluttertoast.showToast(
                                    msg: 'Unknown role: $role',
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    textColor: Colors.white,
                                    fontSize: 16.0,
                                  );
                                  return;
                              }

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => targetPage),
                              );
                            } catch (e) {
                              // 7️⃣ Handle all errors gracefully
                              print('Login error: $e');

                              Fluttertoast.showToast(
                                msg: e
                                    .toString()
                                    .replaceFirst('Exception: ', ''),
                                fontSize: 16.0,
                              );
                            }
                          },
                          child: Text('Login')),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => SignUpPage()),
                                );
                              },
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: const Text(
                                'Not registered? Sign up.',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
                            },
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: const Text(
                              'Forgot / Change Password',
                              style: TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
