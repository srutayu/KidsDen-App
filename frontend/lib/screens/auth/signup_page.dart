import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frontend/controllers/auth_controller.dart';
import 'package:frontend/screens/auth/approval_pending.dart';
import 'package:frontend/screens/auth/login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  bool _isLoading = false;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmPasswordController.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get isLengthValid => _password.text.length >= 6;
  bool get isMatch => _password.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty&&
      _password.text == _confirmPasswordController.text;
  final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  bool get isEmailValid => emailRegex.hasMatch(_email.text);
  bool isTeacher = true; // default switch = Student
  String _selectedRole = "teacher"; // same as default

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
                        width: 150,
                        height: 150,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Student"),
                                    Switch(
                                      value: isTeacher,
                                      activeColor: Colors.teal,
                                      onChanged: (value) {
                                        setState(() {
                                          isTeacher = value;
                                          _selectedRole = isTeacher
                                              ? "teacher"
                                              : "student"; // update your role
                                        });
                                      },
                                    ),
                                    Text("Teacher"),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _name,
                                  decoration: InputDecoration(
                                    labelText: 'Name',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.person),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email ID',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.email),
                                    suffixIcon: _email.text.isEmpty
                                        ? null
                                        : Icon(
                                            isEmailValid
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: isEmailValid
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Set a Password',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.password),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    fillColor: Colors.grey[200],
                                    prefixIcon: Icon(Icons.lock_outline),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide:
                                          BorderSide(color: Colors.grey),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide(
                                          color: Colors.teal, width: 2),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      isLengthValid
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isLengthValid
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text("At least 6 characters"),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      isMatch
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          isMatch ? Colors.green : Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text("Passwords match"),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                          SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            if (_name.text.isEmpty) {
                                              Fluttertoast.showToast(
                                                  msg: 'Name Required');
                                              return;
                                            } else if (_email.text.isEmpty) {
                                              Fluttertoast.showToast(
                                                  msg: 'Email Required');
                                              return;
                                            } else if (!isEmailValid) {
                                              Fluttertoast.showToast(
                                                  msg: 'Invalid Email');
                                              return;
                                            } else if (_password.text.isEmpty) {
                                              Fluttertoast.showToast(
                                                  msg: 'Password Required');
                                              return;
                                            } else if (!isMatch ||
                                                !isLengthValid) {
                                              Fluttertoast.showToast(
                                                  msg:
                                                      'Password Criteria not met');
                                              return;
                                            }

                                            setState(() => _isLoading = true);

                                            try {
                                              await AuthController.register(
                                                _name.text,
                                                _email.text,
                                                _password.text,
                                                _selectedRole,
                                              );

                                              if (!mounted) return;

                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        ApprovalPending()),
                                              );
                                            } catch (error) {
                                              Fluttertoast.showToast(
                                                msg: error
                                                    .toString()
                                                    .replaceFirst(
                                                        "Exception: ", ""),
                                                toastLength: Toast.LENGTH_SHORT,
                                                gravity: ToastGravity.BOTTOM,
                                                textColor: Colors.white,
                                                fontSize: 16.0,
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(
                                                    () => _isLoading = false);
                                              }
                                            }
                                          },
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text("Register"),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Already have an account? "),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LoginPage(), 
                                          ),
                                        );
                                      },
                                      child: Text(
                                        "Log In",
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )))))));
  }
}
